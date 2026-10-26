"""
Build the app's engine parity fixture (Plan B Task B6) from a publish output folder.

Reads reorder_<b>.json.gz, history_<b>.json.gz, rules.json.gz and _meta.json, samples ~400 parts across every
branch with stratification (every status, every rule, minimumNoDemand true/false, masked, min override, negative
on hand, fractional values, with and without history; round 1: the demand-count boundary, units sold with no
demands (D14), value capped, months of supply, manual order and a mask ended by a request) and writes
    {"month": "<months[0]>", "rules": [...], "parts": [{"branch", "gold": <reorder row>,
                                                          "history": {"sales", "requests"} | null}]}
to the app repo's src/engine/__fixtures__/gold-sample.json (or --dest). Deterministic: fixed seed, stable sort.
Expected strata with no part in the data at all (e.g. no Months rule or Manual Order row yet) are printed.

Usage: python make_engine_fixture.py [--output DIR] [--dest FILE] [--size N] [--seed N]
"""
import argparse
import gzip
import json
import os
import random

_HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUTPUT = os.path.join(_HERE, "output")
DEFAULT_DEST = os.path.join(os.path.expanduser("~"), "Documents", "Git-Projects", "nonjd-order-app", "src", "engine",
                            "__fixtures__", "gold-sample.json")
STATUSES = ("ManualOrder", "Masked", "NoRecentActivity", "NotStocked", "BelowMinValue", "AboveMaxValue",
            "OutOfStock", "Reorder", "OK")
FRACTION_FIELDS = ("onHand", "onOrder", "minimumQty", "minOverride", "windowDemand", "unitsSoldWindow",
                   "effectiveMin", "supply")
# Strata the fixture should cover; any with no part in the whole data is reported (it can't be sampled).
EXPECTED_STRATA = tuple(f"status={s}" for s in STATUSES) + (
    "minimumNoDemand=true", "minimumNoDemand=false", "unit=Weeks", "unit=Months", "demandsAtMin",
    "demandsOneBelowMin", "belowMinDemands", "unitsNoDemands", "valueCapped", "belowMinValue", "manualOrder",
    "maskedOn", "maskEnded", "masked", "minOverride", "minimumWins", "negativeOnHand", "fractional", "history",
    "noHistory")


def _load(path: str):
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def load_output(out_dir: str) -> dict:
    """{"month", "rules", "candidates": [{"branch", "gold", "history"}]} in a stable order (_meta branch order,
    then the reorder file's order, which is franchise, part number)."""
    meta = _load(os.path.join(out_dir, "_meta.json"))
    rules_path = os.path.join(out_dir, "rules.json.gz")
    if not os.path.exists(rules_path):
        raise FileNotFoundError(f"{rules_path} is missing: rebuild the output with the current publish code")
    rules = _load(rules_path)["rules"]
    months, candidates = None, []
    for b in meta["branches"]:
        key = b["branch"]
        reorder = _load(os.path.join(out_dir, f"reorder_{key}.json.gz"))
        history = _load(os.path.join(out_dir, f"history_{key}.json.gz"))
        if months is None:
            months = history["months"]
        elif history["months"] != months:
            raise ValueError(f"branch {key} has different month labels")
        hist = {(h["franchise"], h["partNumber"]): {"sales": h["sales"], "requests": h["requests"]}
                for h in history["parts"]}
        for p in reorder["parts"]:
            candidates.append({"branch": key, "gold": p, "history": hist.get((p["franchise"], p["partNumber"]))})
    if months is None:
        raise ValueError("no branches in _meta.json")
    return {"month": months[0], "rules": rules, "candidates": candidates}


def _fractional(v) -> bool:
    return isinstance(v, float) and not v.is_integer()


def tags(c: dict) -> list:
    """The strata a candidate belongs to."""
    g = c["gold"]
    t = [f"status={g['status']}", f"rule={g['ruleName']}", f"minimumNoDemand={str(g['minimumNoDemand']).lower()}",
         f"branch={c['branch']}", f"basis={g['demandBasis']}", f"unit={g['supplyUnit']}",
         "history" if c["history"] else "noHistory"]
    if g["isMasked"]:
        t.append("masked")
    if g.get("maskedOn") is not None:
        t.append("maskedOn")
        if not g["isMasked"]:
            t.append("maskEnded")   # masked, then requested after MaskedOn (or expired)
    if g.get("manualOrder"):
        t.append("manualOrder")
    if g["minOverride"] is not None:
        t.append("minOverride")
    if (g["minimumQty"] or 0) > 0:
        t.append("minimumQty")
    if g["onHand"] < 0:
        t.append("negativeOnHand")
    if any(_fractional(g.get(f)) for f in FRACTION_FIELDS):
        t.append("fractional")
    if g["partNumber"] != g["partNumber"].strip():
        t.append("edgeSpace")
    if g["activeMonths"] > 0 and g["windowDemand"] == 0:
        t.append("cancelledOut")
    # The MinDemands boundary (stocking uses demands, D1).
    if g["demandCount"] > 0 and g["demandCount"] == g["minDemands"]:
        t.append("demandsAtMin")
    if g["minDemands"] > 0 and g["demandCount"] == g["minDemands"] - 1:
        t.append("demandsOneBelowMin")
    if 0 < g["demandCount"] < g["minDemands"]:
        t.append("belowMinDemands")
    # D14: units sold with no recorded demands (activity, but not stocked on demands).
    if g["demandCount"] == 0 and g["unitsSoldWindow"] > 0:
        t.append("unitsNoDemands")
    if g.get("valueCapped"):
        t.append("valueCapped")
    if g.get("belowMinValue"):
        t.append("belowMinValue")
    if g["effectiveMin"] > g["calcTarget"]:
        t.append("minimumWins")
    return t


def absent_strata(candidates: list) -> list:
    """EXPECTED_STRATA with no part in the whole data (so the fixture can't cover them)."""
    seen = set()
    for c in candidates:
        seen.update(tags(c))
    return [t for t in EXPECTED_STRATA if t not in seen]


def sample(candidates: list, size: int = 400, per_tag: int = 12, seed: int = 20261021) -> list:
    """Up to per_tag parts from every stratum (all of a small stratum), then a random fill to `size`.
    The result keeps the candidates' order."""
    rng = random.Random(seed)
    by_tag = {}
    for i, c in enumerate(candidates):
        for t in tags(c):
            by_tag.setdefault(t, []).append(i)
    chosen = set()
    for t in sorted(by_tag):
        idx = by_tag[t]
        already = [i for i in idx if i in chosen]
        need = per_tag - len(already)
        if need <= 0:
            continue
        rest = [i for i in idx if i not in chosen]
        chosen.update(rest if len(rest) <= need else rng.sample(rest, need))
    if len(chosen) < size:
        rest = [i for i in range(len(candidates)) if i not in chosen]
        chosen.update(rng.sample(rest, min(size - len(chosen), len(rest))))
    return [candidates[i] for i in sorted(chosen)]


def render(month: str, rules: list, parts: list) -> str:
    """JSON with one part per line (diffable), keys sorted."""
    dump = lambda o: json.dumps(o, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    lines = [dump({"branch": p["branch"], "gold": p["gold"], "history": p["history"]}) for p in parts]
    return ('{"month":' + dump(month) + ',\n"rules":' + dump(rules) + ',\n"parts":[\n'
            + ",\n".join(lines) + "\n]}\n")


def stratum_counts(parts: list) -> dict:
    counts = {}
    for p in parts:
        for t in tags(p):
            counts[t] = counts.get(t, 0) + 1
    return dict(sorted(counts.items()))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default=DEFAULT_OUTPUT, help="publish output folder")
    ap.add_argument("--dest", default=DEFAULT_DEST, help="fixture file to write")
    ap.add_argument("--size", type=int, default=400)
    ap.add_argument("--seed", type=int, default=20261021)
    args = ap.parse_args(argv)
    data = load_output(args.output)
    parts = sample(data["candidates"], args.size, seed=args.seed)
    text = render(data["month"], data["rules"], parts)
    os.makedirs(os.path.dirname(args.dest), exist_ok=True)
    with open(args.dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"{len(parts)} of {len(data['candidates'])} parts, month {data['month']}, {len(data['rules'])} rules, "
          f"{len(text.encode('utf-8')) / 1024:.0f} KB -> {args.dest}")
    all_counts = stratum_counts(data["candidates"])
    for t, n in stratum_counts(parts).items():
        print(f"  {t}: {n} (of {all_counts[t]})")
    missing = sorted(set(all_counts) - set(stratum_counts(parts)))
    if missing:
        print("  strata with no sampled part:", missing)
    absent = absent_strata(data["candidates"])
    if absent:
        print("  expected strata with no part in the data (none in live data, so not covered):", absent)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
