"""Read-only: compare DP's PartsAvailability loads with LH_Master_Data's InMaster_PartsLookup_Raw loads.

Usage: python parts_availability_check.py <dev|prod> [YYYY-MM-DD]   (default: today)

Both tables are whole-table Replace loads of the same ODBC query (LH weekdays 07:50-16:50 hourly; DP Prod
06:50-16:50 via Pipeline_PartsAvailability; DP Dev by hand). Every Delta commit is one complete load, so
each LH load of the day is paired with the DP load committed within 10 minutes of it, and the two snapshots
are compared on the raw key Branch + Franchise + PartNumber. There is no trimming: trailing-space twin part
numbers are real, separate rows.
The date is matched against the UTC commit time (06:50-16:50 Central falls on one UTC calendar day).
Pass: no key is missing from one side or different in two consecutive pairs (one pair alone can differ by
a handful of rows, because the two queries run seconds apart); every pair has at most 10 one-sided keys
and at most 200 differing keys; no raw-key duplicates on either side; ExtractedAtUtc holds exactly one
non-null value per DP snapshot; and, for prod, every LH load of the day has a DP partner.
Exit 0 pass, 1 fail, 2 no pairs found, 3 usage.
Spec: docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md
"""
import json
import re
import sys
from datetime import date, datetime, timedelta, timezone

import duckdb

ONELAKE = "abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"
LH = ONELAKE.format(ws="b48cdb35-7ce3-46de-96df-d70db77649cb", lh="3e74497b-8c51-4a1a-91a1-888c59118f48",
                    table="InMaster_PartsLookup_Raw")
DP = {"dev": ONELAKE.format(ws="ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", lh="876255e0-d462-4697-adc1-4a655f5bb101",
                            table="PartsAvailability"),
      "prod": ONELAKE.format(ws="189e5c0a-548a-4feb-93d6-dda9ebbe96c1", lh="6713bd45-a4ad-47e6-8bff-1bb0415e9784",
                             table="PartsAvailability")}
KEY = ["Branch", "Franchise", "PartNumber"]
COLUMNS = ["Description", "Bin", "SuperFrom", "SuperTo", "VendorCode", "SellPrice1", "Comments",
           "OnHandQty", "PendingQty", "OnOrder", "BinQty"]
MAX_GAP_MINUTES = 10
MAX_ONE_SIDED_PER_PAIR = 10
MAX_DIFF_PER_PAIR = 200


def full_loads(entries):
    """entries: (version, commitInfo dict or None, add dict or None), one per _delta_log line.
    Returns [{"version", "ts" (aware UTC), "adds"}] for commits that replaced the whole table, oldest first."""
    by_version = {}
    for version, commit, add in entries:
        c = by_version.setdefault(version, {"version": version, "op": "", "ts": None, "adds": []})
        if commit:
            c["op"] = commit.get("operation") or c["op"]
            c["ts"] = commit.get("timestamp") or c["ts"]
        if add:
            c["adds"].append(add["path"])
            c["ts"] = c["ts"] or add.get("modificationTime")
    out = []
    for version in sorted(by_version):
        c = by_version[version]
        op = c["op"].upper()
        if c["adds"] and c["ts"] and ("REPLACE" in op or "CREATE" in op):
            out.append({"version": version, "ts": datetime.fromtimestamp(c["ts"] / 1000, timezone.utc),
                        "adds": c["adds"]})
    return out


def pair_loads(lh, dp, max_gap_minutes=MAX_GAP_MINUTES):
    """[(lh_load, dp_load)]: each LH load with the nearest unused DP load committed within the gap."""
    pairs, used = [], set()
    gap = timedelta(minutes=max_gap_minutes)
    for a in lh:
        candidates = [b for b in dp if b["version"] not in used and abs(b["ts"] - a["ts"]) <= gap]
        if candidates:
            best = min(candidates, key=lambda b: abs(b["ts"] - a["ts"]))
            pairs.append((a, best))
            used.add(best["version"])
    return pairs


def persistent_keys(results):
    """Keys that are bad (one-sided or different) in two consecutive pairs."""
    out = set()
    for a, b in zip(results, results[1:]):
        out |= a["bad_keys"] & b["bad_keys"]
    return out


def verdict(results, unpaired_lh=0, strict_unpaired=False):
    """(exit code, problems)."""
    if not results:
        return 2, ["no LH/DP load pairs found for that date"]
    problems = []
    stuck = persistent_keys(results)
    if stuck:
        problems.append(f"{len(stuck)} key(s) wrong in two consecutive pairs, e.g. {sorted(stuck)[:5]}")
    for i, r in enumerate(results, 1):
        one_sided = len(r["only_lh"]) + len(r["only_dp"])
        if one_sided > MAX_ONE_SIDED_PER_PAIR:
            problems.append(f"pair {i}: {one_sided} one-sided keys (limit {MAX_ONE_SIDED_PER_PAIR})")
        if len(r["diff"]) > MAX_DIFF_PER_PAIR:
            problems.append(f"pair {i}: {len(r['diff'])} differing keys (limit {MAX_DIFF_PER_PAIR})")
        if r["lh_dup_keys"] or r["dp_dup_keys"]:
            problems.append(f"pair {i}: duplicate raw keys (LH {r['lh_dup_keys']}, DP {r['dp_dup_keys']})")
        if len(r["extracted_at"]) != 1 or r["extracted_at"][0] is None:
            problems.append(f"pair {i}: ExtractedAtUtc must hold exactly one non-null value, got {r['extracted_at']}")
    if strict_unpaired and unpaired_lh > 0:
        problems.append(f"{unpaired_lh} LH load(s) had no DP load within {MAX_GAP_MINUTES} minutes")
    return (1 if problems else 0), problems


def connect():
    con = duckdb.connect()
    con.sql("INSTALL azure; LOAD azure; INSTALL delta; LOAD delta;")
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli', ACCOUNT_NAME 'onelake');")
    con.sql("SET TimeZone = 'UTC'")
    return con


def log_entries(con, table):
    rows = con.execute(
        f"SELECT filename, commitInfo, add FROM read_json('{table}/_delta_log/*.json', filename=true, "
        f"format='newline_delimited', columns={{commitInfo: 'JSON', add: 'JSON'}})").fetchall()
    return [(int(fn.rsplit("/", 1)[1].split(".")[0]), json.loads(ci) if ci else None, json.loads(a) if a else None)
            for fn, ci, a in rows if re.match(r"^\d{20}\.json$", fn.rsplit("/", 1)[1])]


def compare_pair(con, lh_files, dp_files):
    con.execute("CREATE OR REPLACE TABLE l AS SELECT * FROM read_parquet(?)", [lh_files])
    con.execute("CREATE OR REPLACE TABLE d AS SELECT * FROM read_parquet(?)", [dp_files])
    on = " AND ".join(f"l.{k} IS NOT DISTINCT FROM d.{k}" for k in KEY)
    keys = ", ".join(f"l.{k}" for k in KEY)
    dkeys = ", ".join(f"d.{k}" for k in KEY)
    only_lh = set(con.execute(f"SELECT {keys} FROM l ANTI JOIN d ON {on}").fetchall())
    only_dp = set(con.execute(f"SELECT {dkeys} FROM d ANTI JOIN l ON {on}").fetchall())
    differs = " OR ".join(f"l.{c} IS DISTINCT FROM d.{c}" for c in COLUMNS)
    diff = set(con.execute(f"SELECT {keys} FROM l JOIN d ON {on} WHERE {differs}").fetchall())
    counts = con.execute("SELECT " + ", ".join(f"count(*) FILTER (WHERE l.{c} IS DISTINCT FROM d.{c})" for c in COLUMNS)
                         + f" FROM l JOIN d ON {on}").fetchone()
    extracted = con.execute("SELECT DISTINCT ExtractedAtUtc FROM d").fetchall()

    def dups(t):
        return con.execute(f"SELECT count(*) FROM (SELECT {', '.join(KEY)} FROM {t} GROUP BY ALL "
                           "HAVING count(*) > 1)").fetchone()[0]
    return {"lh_rows": con.execute("SELECT count(*) FROM l").fetchone()[0],
            "dp_rows": con.execute("SELECT count(*) FROM d").fetchone()[0],
            "lh_dup_keys": dups("l"), "dp_dup_keys": dups("d"),
            "extracted_at": [e[0] for e in extracted],
            "only_lh": only_lh, "only_dp": only_dp, "diff": diff,
            "col_counts": {c: n for c, n in zip(COLUMNS, counts) if n},
            "bad_keys": only_lh | only_dp | diff}


def main(tier, day):
    sys.stdout.reconfigure(encoding="utf-8")
    con = connect()
    lh = [x for x in full_loads(log_entries(con, LH)) if x["ts"].date() == day]
    dp = [x for x in full_loads(log_entries(con, DP[tier])) if x["ts"].date() == day]
    print(f"{day} (UTC): LH loads {len(lh)}, DP {tier} loads {len(dp)}")
    results = []
    pairs = pair_loads(lh, dp)
    paired = {a["version"] for a, _ in pairs}
    unpaired = [a for a in lh if a["version"] not in paired]
    times = [f"{a['ts']:%H:%M}" for a in unpaired]
    print(f"  LH loads without a DP partner: {len(unpaired)} {times}")
    for a, b in pairs:
        r = compare_pair(con, [f"{LH}/{p}" for p in a["adds"]], [f"{DP[tier]}/{p}" for p in b["adds"]])
        results.append(r)
        print(f"  LH {a['ts']:%H:%M} v{a['version']} vs DP {b['ts']:%H:%M} v{b['version']}: rows {r['lh_rows']:,} / "
              f"{r['dp_rows']:,}; only LH {len(r['only_lh'])}, only DP {len(r['only_dp'])}, differing {len(r['diff'])} "
              f"{r['col_counts'] or ''}; dup keys LH {r['lh_dup_keys']} / DP {r['dp_dup_keys']}; ExtractedAtUtc {r['extracted_at']}")
    code, problems = verdict(results, len(unpaired), strict_unpaired=(tier == "prod"))
    for p in problems:
        print("PROBLEM:", p)
    print("PASS" if code == 0 else "FAIL")
    return code


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in DP:
        print(__doc__, file=sys.stderr)
        sys.exit(3)
    d = date.fromisoformat(sys.argv[2]) if len(sys.argv) == 3 else date.today()
    sys.exit(main(sys.argv[1], d))
