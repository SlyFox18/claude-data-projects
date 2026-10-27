"""
Build the app's engine parity fixture (Plan B Task B6) from a publish output folder.

Reads reorder_<b>.json.gz, history_<b>.json.gz, rules.json.gz, transfer_rules.json.gz,
transfer_suggestions.json.gz and _meta.json (contract v3), samples ~400 parts across every branch with
stratification (every status, every rule, minimumNoDemand true/false, masked, min override, negative on hand,
fractional values, with and without history; round 1: the demand-count boundary, units sold with no demands (D14),
value capped, months of supply, manual order and a mask ended by a request; round 2: an active phase-in, Expired,
MetCriteria, committed inbound and outbound, AllowSend false, a conventional line from two senders, a redistribution
group and a sender skipped under RedistMinValue) and writes
    {"month": "<months[0]>", "dataAsOf": "<_meta dataAsOf>", "rules": [...], "transferRules": [...],
     "parts": [{"branch", "gold": <reorder row>, "history": {"sales", "requests"} | null}],
     "suggestions": [<transfer_suggestions lines of the sampled groups>],
     "committed": [<committed lines of the sampled groups>]}
to the app repo's src/engine/__fixtures__/gold-sample.json (or --dest). Deterministic: fixed seed, stable sort.
Whole Franchise + PartNumber groups are sampled, with every branch row (plan E decision X9): the allocation (Part 3)
needs every branch of a group, so a row sample would fail parity for the wrong reason.
Expected strata with no part in the data at all (e.g. no Months rule or Manual Order row yet) are printed.
The live-mask logic (expiry, a mask ending at a request, today's date) is covered by the app engine's unit tests
(Plan C5), not by this fixture: the fixture only checks the app against Gold's own isMasked.

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
    "minimumNoDemand=true", "minimumNoDemand=false", "unit=Weeks", "unit=Months", "basis=UnitsSold",
    "basis=Requests", "minDemands=0", "bothCaps", "demandsAtMin",
    "demandsOneBelowMin", "belowMinDemands", "unitsNoDemands", "valueCapped", "belowMinValue", "manualOrder",
    "maskedOn", "maskEnded", "masked", "minOverride", "minimumWins", "negativeOnHand", "fractional", "history",
    "noHistory",
    # round 2
    "phaseInActive", "phaseIn=Expired", "phaseIn=MetCriteria", "committedIn", "committedOut", "allowSendFalse",
    "group=conventionalTwoSenders", "group=redistribution", "group=redistMinSkip")


def _load(path: str):
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _load_required(out_dir: str, name: str):
    path = os.path.join(out_dir, name)
    if not os.path.exists(path):
        raise FileNotFoundError(f"{path} is missing: rebuild the output with the current publish code")
    return _load(path)


def load_output(out_dir: str) -> dict:
    """{"month", "dataAsOf", "rules", "transferRules", "suggestions", "committed",
    "candidates": [{"branch", "gold", "history"}]}, candidates in a stable order (_meta branch order, then the
    reorder file's order, which is franchise, part number)."""
    meta = _load(os.path.join(out_dir, "_meta.json"))
    rules = _load_required(out_dir, "rules.json.gz")["rules"]
    transfer_rules = _load_required(out_dir, "transfer_rules.json.gz")["rules"]
    sugg = _load_required(out_dir, "transfer_suggestions.json.gz")
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
    return {"month": months[0], "dataAsOf": meta.get("dataAsOf"), "rules": rules, "transferRules": transfer_rules,
            "suggestions": sugg["lines"], "committed": sugg["committed"], "candidates": candidates}


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
        if (g.get("lastRequested") or "")[:10] > g["maskedOn"]:
            t.append("maskEnded")   # requested after the day it was masked (the mask ends at that request)
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
    if g["minDemands"] == 0:
        t.append("minDemands=0")
    if g.get("minLineValue") is not None and g.get("maxLineValue") is not None:
        t.append("bothCaps")
    if g.get("valueCapped"):
        t.append("valueCapped")
    if g.get("belowMinValue"):
        t.append("belowMinValue")
    if g["effectiveMin"] > g["calcTarget"]:
        t.append("minimumWins")
    # Round 2 (Part 1 phase-in and committed app transfers, Part 2 transfer rule).
    if g["phaseInActive"]:
        t.append("phaseInActive")
    if g["phaseInEndReason"]:
        t.append(f"phaseIn={g['phaseInEndReason']}")
    if g["appInboundQty"] > 0:
        t.append("committedIn")
    if g["appOutboundQty"] > 0:
        t.append("committedOut")
    if g["allowSend"] is False:
        t.append("allowSendFalse")
    return t


def _group_key(c: dict) -> tuple:
    return c["gold"]["franchise"], c["gold"]["partNumber"]


def _trim(b) -> str:
    return "" if b is None else str(b).strip()


def group_tags(candidates: list, suggestions: list) -> dict:
    """{(franchise, partNumber): {group strata}} for the allocation (Part 3):
    - group=conventionalTwoSenders: a receiver with conventional lines from two or more senders;
    - group=redistribution: a redistribution line;
    - group=redistMinSkip: a sender with free excess under a RedistMinValue > 0 and a RedistEligible branch that got
      no redistribution line from it (the minimum skipped it, or the receiver's room was filled first)."""
    out, senders = {}, {}
    for l in suggestions:
        key = (l["franchise"], l["partNumber"])
        tags = out.setdefault(key, set())
        if l["kind"] == "Redistribution":
            tags.add("group=redistribution")
        else:
            senders.setdefault((key, _trim(l["toBranch"])), set()).add(_trim(l["fromBranch"]))
    for (key, _), s in senders.items():
        if len(s) >= 2:
            out[key].add("group=conventionalTwoSenders")
    redist = {(l["franchise"], l["partNumber"], _trim(l["fromBranch"]), _trim(l["toBranch"]))
              for l in suggestions if l["kind"] == "Redistribution"}
    rows = {}
    for c in candidates:
        rows.setdefault(_group_key(c), []).append(c)
    for key, members in rows.items():
        for s in members:
            g = s["gold"]
            if not (g["freeExcess"] > 0 and (g["redistMinValue"] or 0) > 0):
                continue
            if any(r is not s and r["gold"]["redistEligible"] and (*key, s["branch"], r["branch"]) not in redist
                   for r in members):
                out.setdefault(key, set()).add("group=redistMinSkip")
                break
    return out


def absent_strata(candidates: list, suggestions: list = ()) -> list:
    """EXPECTED_STRATA with no part in the whole data (so the fixture can't cover them)."""
    seen = set()
    for c in candidates:
        seen.update(tags(c))
    for g in group_tags(candidates, list(suggestions)).values():
        seen.update(g)
    return [t for t in EXPECTED_STRATA if t not in seen]


def sample(candidates: list, size: int = 400, per_tag: int = 12, seed: int = 20261021, suggestions=()) -> list:
    """Whole Franchise + PartNumber groups (X9): up to per_tag groups from every stratum (all of a small stratum;
    a group is in a stratum when any of its rows is, or by group_tags), then random groups until there are `size`
    rows. The result keeps the candidates' order."""
    rng = random.Random(seed)
    members, order = {}, []
    for i, c in enumerate(candidates):
        key = _group_key(c)
        if key not in members:
            members[key] = []
            order.append(key)
        members[key].append(i)
    gtags = group_tags(candidates, list(suggestions))
    by_tag = {}
    for gi, key in enumerate(order):
        tg = set(gtags.get(key, ()))
        for i in members[key]:
            tg.update(tags(candidates[i]))
        for t in tg:
            by_tag.setdefault(t, []).append(gi)
    chosen = set()
    for t in sorted(by_tag):
        idx = by_tag[t]
        need = per_tag - sum(1 for g in idx if g in chosen)
        if need <= 0:
            continue
        rest = [g for g in idx if g not in chosen]
        chosen.update(rest if len(rest) <= need else rng.sample(rest, need))
    rows = sum(len(members[order[g]]) for g in chosen)
    rest = [g for g in range(len(order)) if g not in chosen]
    rng.shuffle(rest)
    for g in rest:
        if rows >= size:
            break
        chosen.add(g)
        rows += len(members[order[g]])
    return [candidates[i] for i in sorted(i for g in chosen for i in members[order[g]])]


def _rows_text(rows: list, dump) -> str:
    return "[\n" + ",\n".join(dump(r) for r in rows) + "\n]" if rows else "[]"


def render(month: str, rules: list, parts: list, data_as_of: str = None, transfer_rules: list = (),
           suggestions: list = (), committed: list = ()) -> str:
    """JSON with one part / suggestion / committed line per line (diffable), keys sorted. suggestions and committed
    are cut down to the lines of the parts' groups."""
    dump = lambda o: json.dumps(o, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    keys = {(p["gold"]["franchise"], p["gold"]["partNumber"]) for p in parts}
    mine = lambda rows: [r for r in rows if (r["franchise"], r["partNumber"]) in keys]
    parts_text = _rows_text([{"branch": p["branch"], "gold": p["gold"], "history": p["history"]} for p in parts], dump)
    return ('{"month":' + dump(month) + ',\n"dataAsOf":' + dump(data_as_of) + ',\n"rules":' + dump(rules)
            + ',\n"transferRules":' + dump(list(transfer_rules)) + ',\n"parts":' + parts_text
            + ',\n"suggestions":' + _rows_text(mine(suggestions), dump)
            + ',\n"committed":' + _rows_text(mine(committed), dump) + "}\n")


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
    parts = sample(data["candidates"], args.size, seed=args.seed, suggestions=data["suggestions"])
    text = render(data["month"], data["rules"], parts, data["dataAsOf"], data["transferRules"], data["suggestions"],
                  data["committed"])
    os.makedirs(os.path.dirname(args.dest), exist_ok=True)
    with open(args.dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    fixture = json.loads(text)
    n_groups = len({(p["gold"]["franchise"], p["gold"]["partNumber"]) for p in parts})
    print(f"{len(parts)} of {len(data['candidates'])} parts ({n_groups} groups), month {data['month']}, "
          f"{len(data['rules'])} rules, {len(data['transferRules'])} transfer rules, "
          f"{len(fixture['suggestions'])} of {len(data['suggestions'])} suggestion lines, "
          f"{len(fixture['committed'])} of {len(data['committed'])} committed lines, "
          f"{len(text.encode('utf-8')) / 1024:.0f} KB -> {args.dest}")
    all_counts = stratum_counts(data["candidates"])
    for t, n in stratum_counts(parts).items():
        print(f"  {t}: {n} (of {all_counts[t]})")
    gt_all = group_tags(data["candidates"], data["suggestions"])
    mine = {(p["gold"]["franchise"], p["gold"]["partNumber"]) for p in parts}
    gt_mine = {k: v for k, v in group_tags(parts, data["suggestions"]).items() if k in mine}
    for t in sorted({t for g in gt_all.values() for t in g}):
        print(f"  {t}: {sum(t in g for g in gt_mine.values())} groups (of {sum(t in g for g in gt_all.values())})")
    missing = sorted(set(all_counts) - set(stratum_counts(parts)))
    if missing:
        print("  strata with no sampled part:", missing)
    absent = absent_strata(data["candidates"], data["suggestions"])
    if absent:
        print("  expected strata with no part in the data (none in live data, so not covered):", absent)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
