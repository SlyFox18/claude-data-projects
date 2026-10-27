# tools/dp-migration/nonjd_transfer_fuzz.py
"""
Non-JD Parts Order Tool: differential fuzz cases for the transfer suggestions (plan docs/superpowers/plans/2026-10-27-
non-jd-parts-order-tool-round-2-phase-2.md, Task E3 Step 4 and decision X5).

Writes cases.json (random Franchise + PartNumber groups) and expected.json (what the reference,
nonjd_reorder_check.py, works out for them: transfer rule validation and pick, step 8b, step 9, Part 2 and the Part 3
allocation). The app's scripts/fuzz-transfers.ts (Task E9) runs its engine over cases.json and compares with
expected.json field by field. The same seed gives the same files byte for byte. It reads no lakehouse data.

Usage:
    python nonjd_transfer_fuzz.py --seed 1 --groups 5000 --out <dir>

cases.json = {"version": 1, "seed": N, "groups": [case, ...]}, two kinds of case:

- "full": a group's Part 1 results, transfer rules and committed app transfer lines.
    {"id", "kind": "full", "today": the build's Central date "YYYY-MM-DD" (its month is the season month),
     "franchise", "partNumber",
     "rows": [{"Branch", "oh", "oo" (trunc(QuantityOnHand), trunc(OnOrder)), "PendingQty" (raw, may be null,
               fractional or negative), "MonthlyRate" (WindowDemand / HistoryMonths, as Part 1 computes it),
               "StockingTarget", "ManualOrder", "IsMasked", "MinimumNoDemand", "PhaseInActive", "Cost", and the
               criteria values as
               stored: "DealerGroupCode", "SLC", "Source", "VendorCode" (integer), "ProductGroup", "CommodityCode"}],
     "transferRules": [NonJD_TransferRules rows: "Id", "RuleName", "Priority", "Active", "Archived", "Franchise",
               "DealerGroupCode", "Branch", "SLC", "Source", "VendorCode", "ProductGroup", "CommodityCode",
               "StartMonth", "EndMonth", "ExcessSupply", "ExcessUnit", "AllowSend", "AllowReceive", "RedistMax",
               "RedistUnit", "RedistMinValue"],
     "committed": [NonJD_Transfers rows: "TransferId", "LineId", "Status", "PlacedAt" (UTC "YYYY-MM-DDTHH:MM:SSZ" or
               null), "FromBranch", "ToBranch", "Franchise", "PartNumber", "Qty"]}
  Every transfer rule's Franchise criterion is the case's franchise (in random case and spacing), so a case's rules
  only ever match its own rows; the generator relies on it to evaluate all the cases of one date in one query.
  Lines may point at other franchises or part number spellings, excluded or blank branches, or have statuses that
  never count.

- "allocation": Part 3 alone. "rows" carry allocate_group's inputs directly: "Branch", "oh", "oo", "AppInboundQty",
  "pend" (max(0, trunc(PendingQty))), "AppOutboundQty", "MonthlyRate", "StockingTarget", "ExcessKeep", "FreeExcess",
  "ConvNeed", "RedistEligible", "RedistCap", "Cost", "RedistMinValue" (the row's own rule, used when it sends). They
  are drawn independently, so a branch can have both FreeExcess and a need, which Part 2 never produces: that is what
  exercises the never-send-to-itself guard. RedistEligible is only true with MonthlyRate > 0, as in Part 2. "mode"
  (random, sender_tie, receiver_tie, got) only says how the case was drawn.

Planted cases (review S1): some groups have senders or receivers whose covers are equal in exact arithmetic but not
in float64 (e.g. 30 / 0.5 and 35 / (7/12)), so round9 decides the tie; costs with three or more decimals give
half-cent Values (0.125 x 1 = 0.125); and "got" allocation cases have conventional receivers that are also
RedistEligible next to other redistribution receivers, so the redistribution order depends on got.

expected.json = {"version": 1, "seed": N, "groups": [{"id", "kind",
    "invalidTransferRules": [[Id, RuleName, reason], ...] (full only),
    "rows": [{"Branch", "AppInboundQty", "AppOutboundQty", "BaseQty" (step 9), "TransferRuleId", "TransferRuleName",
              "ExcessSupply", "ExcessUnit", "AllowSend", "AllowReceive", "RedistMax", "RedistUnit", "RedistMinValue",
              "ExcessKeep", "FreeExcess", "ConvNeed", "RedistCap", "RedistEligible", "SuggestedInQty",
              "SuggestedConvInQty", "SuggestedOutQty"}] (full only, in branch order),
    "lines": [the suggestion lines with nonjd_reorder_check.SUGGESTION_COLS, in Seq order]}]}
"""
import argparse
import json
import math
import os
import random
import sys
from datetime import date, datetime, timedelta

import duckdb
import pyarrow as pa

import nonjd_reorder_check as chk

VERSION = 1
# 21 included branch codes, unique when trimmed and upper-cased, none of them excluded (D6). "02" and "2" share a
# number, "b" is lower case, " 3" has a leading space (branch order ties and trimming; review S2).
BRANCH_POOL = ["1", "2", " 3", "4", "6", "7", "8", "9", "10", "11", "20", "92", "93", "95", "98", "120", "4A", "7X",
               "BR", "02", "b"]
# Costs whose Value can be a half cent (exact in binary: k/8), and two that are not exact
TIE_COSTS = [0.125, 0.375, 0.625, 1.875, 2.125, 4.375, 1.005, 2.675]
# Cover ties: for a cover C (a multiple of 12) and a rate a/b with b dividing C, stock = C * a / b is whole and
# stock / (a / b) is C in exact arithmetic, but for some (C, a, b) it is C +- 1 ulp in float64 ("noisy"). A planted
# tie group takes one noisy rate and the rest from every rate valid for C, so only round9 makes them equal.
TIE_FRACTIONS = {c: [(a, b) for b in range(1, 13) if c % b == 0 for a in range(1, 25) if math.gcd(a, b) == 1]
                 for c in range(12, 241, 12)}
NOISY = [(c, a, b) for c, fr in TIE_FRACTIONS.items() for a, b in fr if (c * a // b) / (a / b) != c]
# build dates: several months for the seasons, both sides of the DST change for the Placed rule
DATES = ["2026-01-15", "2026-03-08", "2026-06-30", "2026-10-20", "2026-11-01", "2026-12-15"]
ALLOCATION_SHARE = 0.2
EXPECTED_ROW_COLS = ["Branch", "AppInboundQty", "AppOutboundQty", "BaseQty", "TransferRuleId", "TransferRuleName",
                     "ExcessSupply", "ExcessUnit", "AllowSend", "AllowReceive", "RedistMax", "RedistUnit",
                     "RedistMinValue", "ExcessKeep", "FreeExcess", "ConvNeed", "RedistCap", "RedistEligible",
                     "SuggestedInQty", "SuggestedConvInQty", "SuggestedOutQty"]
ROW_TYPES = {"CaseId": "INTEGER", "Branch": "VARCHAR", "Franchise": "VARCHAR", "PartNumber": "VARCHAR",
             "oh": "INTEGER", "oo": "INTEGER", "PendingQty": "DOUBLE", "MonthlyRate": "DOUBLE",
             "StockingTarget": "INTEGER", "ManualOrder": "BOOLEAN", "IsMasked": "BOOLEAN",
             "MinimumNoDemand": "BOOLEAN", "PhaseInActive": "BOOLEAN", "cost": "DOUBLE", "DealerGroupCode": "VARCHAR", "SLC": "VARCHAR",
             "Source": "VARCHAR", "VendorCode": "INTEGER", "ProductGroup": "VARCHAR", "CommodityCode": "VARCHAR"}
CRITERIA_POOLS = {"DealerGroupCode": [None, "", "COTTON", "cotton ", "PEANUT"], "SLC": [None, "00", " 00", "50E"],
                  "Source": [None, "500", "AL"], "VendorCode": [0, 1234, 77], "ProductGroup": [None, "PG1", "pg1"],
                  "CommodityCode": [None, "CC"]}
RULE_CRITERIA_POOLS = {"DealerGroupCode": ["COTTON", " cotton", "PEANUT", "NONE"], "SLC": ["00", "50e", "ZZ"],
                       "Source": ["500", " al ", "X"], "VendorCode": ["1234", "77", "0", "01234"],
                       "ProductGroup": ["PG1", "pg2"], "CommodityCode": ["CC", "cc "]}


def _pick(rng, weighted):
    """weighted: [(value, weight), ...]"""
    values, weights = zip(*weighted)
    return rng.choices(values, weights=weights)[0]


def _variant(rng, text):
    """The same code in another case or spacing (it still matches after trim + upper)."""
    return _pick(rng, [(text, 3), (text.lower(), 1), (f" {text} ", 1), (f"{text} ", 1)])


def _rate(rng):
    hm = rng.choice([1, 3, 6, 12, 12, 12, 24])
    wd = _pick(rng, [(0, 4), (rng.randint(1, 40), 3), (rng.randint(41, 300), 1), (round(rng.uniform(0.5, 20), 1), 1)])
    return wd / hm


def _full_row(rng, branch, cost):
    rate = _rate(rng)
    target = _pick(rng, [(0, 3), (rng.randint(1, 12), 4), (rng.randint(13, 60), 1)])
    return {
        "Branch": branch,
        "oh": _pick(rng, [(0, 3), (rng.randint(1, 15), 4), (rng.randint(16, 120), 3), (rng.randint(-3, -1), 1)]),
        "oo": _pick(rng, [(0, 8), (rng.randint(1, 6), 2), (-1, 1)]),
        "PendingQty": _pick(rng, [(None, 2), (0, 4), (rng.randint(1, 6), 2), (1.5, 1), (-1, 1)]),
        "MonthlyRate": rate,
        "StockingTarget": target,
        "ManualOrder": rng.random() < 0.05,
        "IsMasked": rng.random() < 0.05,
        "MinimumNoDemand": rate == 0 and target > 0 and rng.random() < 0.2,
        "PhaseInActive": False,
        "Cost": cost if rng.random() < 0.85 else round(rng.uniform(0.01, 200), 2),
        **{c: rng.choice(pool) for c, pool in CRITERIA_POOLS.items()},
    }


def _rule(rng, rid, franchise, branches):
    season = _pick(rng, [((None, None), 7), ((rng.randint(1, 12), rng.randint(1, 12)), 3), ((6, None), 0.3),
                         ((13, 2), 0.3)])
    crit = {c: (rng.choice(pool) if rng.random() < 0.25 else None) for c, pool in RULE_CRITERIA_POOLS.items()}
    return {
        "Id": rid,
        "RuleName": _pick(rng, [(f"T{rid}", 8), (None, 1), ("  ", 1)]),
        "Priority": _pick(rng, [(0, 4), (1, 2), (5, 3), (-1, 1), (2.5, 1), (None, 0.5)]),
        "Active": _pick(rng, [(True, 8), (False, 1), (None, 1)]),
        "Archived": _pick(rng, [(None, 4), (False, 4), (True, 1)]),
        "Franchise": _variant(rng, franchise),
        "DealerGroupCode": crit["DealerGroupCode"],
        "Branch": _variant(rng, rng.choice(branches)) if rng.random() < 0.4 else None,
        "SLC": crit["SLC"], "Source": crit["Source"], "VendorCode": crit["VendorCode"],
        "ProductGroup": crit["ProductGroup"], "CommodityCode": crit["CommodityCode"],
        "StartMonth": season[0], "EndMonth": season[1],
        "ExcessSupply": _pick(rng, [(12, 4), (6, 2), (0, 1), (24, 1), (1.5, 1), (60, 0.5), (61, 0.3), (260, 0.3),
                                    (None, 0.3)]),
        "ExcessUnit": _pick(rng, [(None, 3), ("Months", 4), ("Weeks", 2), (" weeks", 1), ("Days", 0.2)]),
        "AllowSend": _pick(rng, [(True, 6), (False, 2), (None, 2)]),
        "AllowReceive": _pick(rng, [(True, 6), (False, 2), (None, 2)]),
        "RedistMax": _pick(rng, [(6, 4), (None, 2), (0, 1), (2, 1), (12, 1), (24, 1), (25, 0.2), (104, 0.3)]),
        "RedistUnit": _pick(rng, [(None, 3), ("Months", 4), ("Weeks", 2), ("Years", 0.2)]),
        "RedistMinValue": _pick(rng, [(0, 4), (None, 2), (25, 2), (5, 1), (100, 1), (-1, 0.2)]),
    }


def _placed_at(rng, today: date):
    if rng.random() < 0.1:
        return None
    noon_utc = datetime(today.year, today.month, today.day, 17, 0)
    return (noon_utc + timedelta(minutes=rng.randint(-72 * 60, 48 * 60))).strftime("%Y-%m-%dT%H:%M:%SZ")


def _line(rng, tid, lid, franchise, pn, branches, today):
    def branch():
        return _pick(rng, [(rng.choice(branches), 8), (_variant(rng, rng.choice(branches)), 2), ("12", 0.5),
                           (" 4b", 0.5), ("", 0.3), (None, 0.3), ("5X", 0.5)])
    status = _pick(rng, [("Draft", 4), ("Exported", 2), ("Placed", 3), ("Cancelled", 1), ("draft", 0.5), (None, 0.3)])
    return {"TransferId": tid, "LineId": lid, "Status": status,
            "PlacedAt": _placed_at(rng, today) if status == "Placed" or rng.random() < 0.1 else None,
            "FromBranch": branch(), "ToBranch": branch(),
            "Franchise": franchise if rng.random() < 0.9 else franchise.lower(),
            "PartNumber": pn if rng.random() < 0.9 else rng.choice([pn.lower(), pn + " ", " " + pn]),
            "Qty": _pick(rng, [(rng.randint(1, 8), 8), (2.9, 1), (0, 0.5), (-1, 0.5), (None, 0.5)])}


def _full_case(rng, cid):
    today = date.fromisoformat(rng.choice(DATES))
    franchise = f"F{cid}"
    pn = rng.choice([f"P{cid}", f"0{cid}", f"X{cid} ", f"p{cid}"])
    branches = rng.sample(BRANCH_POOL, rng.randint(2, 19))
    cost = rng.choice([round(rng.uniform(0.01, 5), 2), round(rng.uniform(5, 300), 2), 0.1, 3.35, 12.5,
                       rng.choice(TIE_COSTS)])
    rows = [_full_row(rng, b, cost) for b in branches]
    for r in rows:              # an active phase-in, often on a minimum with no demand (it lifts A5)
        r["PhaseInActive"] = rng.random() < (0.4 if r["MinimumNoDemand"] else 0.05)
    if rng.random() < 0.3:
        _plant_full_tie(rng, rows)
    n_rules = _pick(rng, [(0, 3), (1, 3), (2, 2), (3, 1), (4, 1)])
    rules = [_rule(rng, cid * 10 + k, franchise, branches) for k in sorted(rng.sample(range(1, 10), n_rules))]
    n_lines = _pick(rng, [(0, 4), (1, 3), (2, 2), (4, 1)])
    lines = [_line(rng, cid * 10 + k, cid * 10 + k, franchise, pn, branches, today) for k in range(n_lines)]
    return {"id": cid, "kind": "full", "today": today.isoformat(), "franchise": franchise, "partNumber": pn,
            "rows": rows, "transferRules": rules, "committed": lines}


def _tie_rates(rng, k):
    """k (rate, stock) pairs with stock / rate equal in exact arithmetic; the first is noisy in float64."""
    cover, a, b = rng.choice(NOISY)
    pairs = [(a, b)] + [rng.choice(TIE_FRACTIONS[cover]) for _ in range(k - 1)]
    rng.shuffle(pairs)
    return [(a / b, cover * a // b) for a, b in pairs]


def _plant_full_tie(rng, rows):
    """Turn 2-4 rows into senders (or receivers) with equal exact covers, plus a plain receiver (or sender), so that
    round9 decides who goes first."""
    if len(rows) < 3:
        return
    k = rng.randint(2, min(4, len(rows) - 1))
    picked = rng.sample(range(len(rows)), k + 1)
    tied, other = picked[:k], picked[k]
    plain = {"PendingQty": 0, "ManualOrder": False, "IsMasked": False, "MinimumNoDemand": False,
             "PhaseInActive": False}
    senders = rng.random() < 0.5
    for i, (rate, stock) in zip(tied, _tie_rates(rng, k)):
        if senders:              # free > 0: the 12-month default keeps ceil(rate x 12) <= stock / 2
            rows[i].update(plain, MonthlyRate=rate, oh=stock, oo=0, StockingTarget=rng.randint(0, 2))
        else:                    # a need above the stock: target = stock + 1..10
            oo = rng.randint(0, min(3, stock))
            rows[i].update(plain, MonthlyRate=rate, oh=stock - oo, oo=oo, StockingTarget=stock + rng.randint(1, 10))
    if senders:
        rows[other].update(plain, MonthlyRate=1.0, oh=0, oo=0, StockingTarget=rng.randint(3, 10))
    else:
        rows[other].update(plain, MonthlyRate=0.0, oh=rng.randint(1, 8), oo=0, StockingTarget=0)


def _alloc_row(rng, b, cost):
    rate = rng.choice([0.0, 0.0, 0.25, 1 / 3, 1.0, 2.5, 7 / 12])
    return {"Branch": b, "oh": rng.randint(-2, 40), "oo": _pick(rng, [(0, 6), (rng.randint(1, 5), 2), (-1, 1)]),
            "AppInboundQty": _pick(rng, [(0, 6), (rng.randint(1, 4), 2)]),
            "pend": _pick(rng, [(0, 6), (rng.randint(1, 5), 2)]),
            "AppOutboundQty": _pick(rng, [(0, 6), (rng.randint(1, 5), 2)]), "MonthlyRate": rate,
            "StockingTarget": rng.randint(0, 20), "ExcessKeep": rng.randint(0, 20),
            "FreeExcess": _pick(rng, [(0, 5), (rng.randint(1, 15), 4)]),
            "ConvNeed": _pick(rng, [(0, 5), (rng.randint(1, 15), 4)]),
            "RedistEligible": rate > 0 and rng.random() < 0.4, "RedistCap": rng.randint(0, 25),
            "Cost": cost(), "RedistMinValue": _pick(rng, [(0.0, 5), (25.0, 2), (5.0, 1)])}


def _allocation_case(rng, cid):
    def cost():
        return rng.choice([0.1, 1.0, 3.35, 12.5, round(rng.uniform(0.01, 100), 2), rng.choice(TIE_COSTS)])
    mode = _pick(rng, [("random", 4), ("sender_tie", 2), ("receiver_tie", 2), ("got", 2)])
    branches = rng.sample(BRANCH_POOL, rng.randint(2, 19) if mode == "random" else rng.randint(3, 8))
    rows = [_alloc_row(rng, b, cost) for b in branches]
    quiet = {"FreeExcess": 0, "ConvNeed": 0, "RedistEligible": False}
    if mode == "sender_tie":     # senders with equal exact covers (on oh - pend - out), one receiver
        for r, (rate, stock) in zip(rows[:-1], _tie_rates(rng, len(rows) - 1)):
            pend, out = rng.randint(0, 3), rng.randint(0, 3)
            r.update(quiet, MonthlyRate=rate, oh=stock + pend + out, pend=pend, AppOutboundQty=out,
                     FreeExcess=rng.randint(1, max(1, stock)))
        rows[-1].update(quiet, ConvNeed=rng.randint(1, 10), oh=0, oo=0, AppInboundQty=0, MonthlyRate=1.0)
    elif mode == "receiver_tie":     # receivers with equal exact covers, one sender with little free
        for r, (rate, stock) in zip(rows[:-1], _tie_rates(rng, len(rows) - 1)):
            oo = rng.randint(0, min(2, stock))
            inbound = rng.randint(0, min(2, stock - oo))
            r.update(quiet, MonthlyRate=rate, oh=stock - oo - inbound, oo=oo, AppInboundQty=inbound,
                     ConvNeed=rng.randint(1, 10), RedistEligible=rng.random() < 0.5,
                     RedistCap=stock + rng.randint(0, 20))
        rows[-1].update(quiet, MonthlyRate=0.0, oh=20, FreeExcess=rng.randint(1, 12))
    elif mode == "got":      # conventional receivers that are also RedistEligible, beside redistribution-only ones
        for r in rows[:-1]:
            rate = rng.choice([0.5, 1.0, 2.0, 7 / 12, 1 / 3])
            stock = rng.randint(0, 8)
            r.update(quiet, MonthlyRate=rate, oh=stock, oo=0, AppInboundQty=0, ConvNeed=rng.randint(0, 8),
                     RedistEligible=True, RedistCap=stock + rng.randint(1, 20))
        rows[-1].update(quiet, MonthlyRate=0.0, oh=60, FreeExcess=rng.randint(10, 60))
    return {"id": cid, "kind": "allocation", "mode": mode, "franchise": f"F{cid}", "partNumber": f"P{cid}",
            "rows": rows}


def generate(seed: int, groups: int) -> dict:
    """The cases (cases.json) for `seed`; deterministic."""
    rng = random.Random(seed)
    cases = [(_allocation_case if rng.random() < ALLOCATION_SHARE else _full_case)(rng, cid)
             for cid in range(1, groups + 1)]
    return {"version": VERSION, "seed": seed, "groups": cases}


# Step 8b (chk.COMMITTED_CTES) and step 9 over the case rows, part_crit as EXPECTED_SQL builds it (ProductGroup is a
# row value here), then Part 2 (chk.transfer_ctes).
FUZZ_SQL = f"""
    WITH {chk.COMMITTED_CTES},
    fuzz_p1 AS (
        SELECT r.*, CAST(coalesce(ai.q, 0) AS INTEGER) AS AppInboundQty,
               CAST(coalesce(ao.q, 0) AS INTEGER) AS AppOutboundQty
        FROM fuzz_rows r
        LEFT JOIN app_inbound ai
          ON ai.tb = upper(trim(r.Branch)) AND ai.Franchise = r.Franchise AND ai.PartNumber = r.PartNumber
        LEFT JOIN app_outbound ao
          ON ao.fb = upper(trim(r.Branch)) AND ao.Franchise = r.Franchise AND ao.PartNumber = r.PartNumber
    ),
    fuzz_final AS (
        SELECT *, CASE WHEN StockingTarget = 0 THEN 0
                       ELSE greatest(0, StockingTarget - oh - oo - AppInboundQty) END AS bq
        FROM fuzz_p1
    ),
    part_crit AS (
        SELECT Branch, Franchise, PartNumber,
               upper(trim(Franchise)) AS p_franchise, upper(trim(DealerGroupCode)) AS p_dgc,
               upper(trim(Branch)) AS p_branch, upper(trim(SLC)) AS p_slc, upper(trim(Source)) AS p_source,
               CAST(CAST(VendorCode AS BIGINT) AS VARCHAR) AS p_vendor, upper(trim(ProductGroup)) AS p_pg,
               upper(trim(CommodityCode)) AS p_cc
        FROM fuzz_rows
    ),
    {chk.transfer_ctes("fuzz_final")}
    SELECT * FROM part2
"""


def _tables(con):
    con.execute("CREATE OR REPLACE TABLE fuzz_rows (" + ", ".join(f"{c} {t}" for c, t in ROW_TYPES.items()) + ")")
    con.execute("CREATE OR REPLACE TABLE transfer_rules ("
                + ", ".join(f"{c} {t}" for c, t in chk.TRANSFER_RULE_COLS.items()) + ")")
    con.execute("CREATE OR REPLACE TABLE app_transfers ("
                + ", ".join(f"{c} {t}" for c, t in chk.APP_TRANSFER_COLS.items()) + ")")


_ARROW = {"INTEGER": pa.int64(), "BIGINT": pa.int64(), "DOUBLE": pa.float64(), "VARCHAR": pa.string(),
          "BOOLEAN": pa.bool_(), "TIMESTAMP WITH TIME ZONE": pa.string()}


def _insert(con, table, cols, records):
    """Bulk insert through Arrow (executemany takes about a millisecond a row); each column cast to the table's
    type (PlacedAt text -> TIMESTAMPTZ)."""
    if not records:
        return
    types = dict(con.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = ?",
                             [table]).fetchall())
    src = pa.Table.from_pylist([dict(zip(cols, r)) for r in records],
                               schema=pa.schema([(c, _ARROW[types[c]]) for c in cols]))
    con.register("fuzz_src", src)
    con.execute(f"INSERT INTO {table} ({', '.join(cols)}) "
                f"SELECT {', '.join(f'CAST({c} AS {types[c]})' for c in cols)} FROM fuzz_src")
    con.unregister("fuzz_src")


def _suggested(lines, branch):
    into = [l for l in lines if l["ToBranch"] == branch]
    return {"SuggestedInQty": sum(l["Qty"] for l in into),
            "SuggestedConvInQty": sum(l["Qty"] for l in into if l["Kind"] == "Conventional"),
            "SuggestedOutQty": sum(l["Qty"] for l in lines if l["FromBranch"] == branch)}


def _expected_full(cases: list) -> dict:
    """{case id: expected group} for full cases, one DuckDB query per build date."""
    out = {}
    con = duckdb.connect()
    con.execute("SET TimeZone='UTC'")
    by_date = {}
    for case in cases:
        by_date.setdefault(case["today"], []).append(case)
    for today_s in sorted(by_date):
        batch = by_date[today_s]
        today = date.fromisoformat(today_s)
        _tables(con)
        _insert(con, "fuzz_rows", list(ROW_TYPES),
                [[c["id"], r["Branch"], c["franchise"], c["partNumber"], r["oh"], r["oo"], r["PendingQty"],
                  r["MonthlyRate"], r["StockingTarget"], r["ManualOrder"], r["IsMasked"], r["MinimumNoDemand"],
                  r["PhaseInActive"], r["Cost"]] + [r[k] for k in CRITERIA_POOLS] for c in batch for r in c["rows"]])
        _insert(con, "transfer_rules", list(chk.TRANSFER_RULE_COLS),
                [[t[k] for k in chk.TRANSFER_RULE_COLS] for c in batch for t in c["transferRules"]])
        line_cols = ["TransferId", "LineId", "Status", "PlacedAt", "FromBranch", "ToBranch", "Franchise",
                     "PartNumber", "Qty"]
        _insert(con, "app_transfers", line_cols, [[l[k] for k in line_cols] for c in batch for l in c["committed"]])
        rule_case = {t["Id"]: c["id"] for c in batch for t in c["transferRules"]}
        invalid = {}
        for rid, name, reason in chk.invalid_transfer_rules(con):
            invalid.setdefault(rule_case[rid], []).append([rid, name, reason])
        cur_ = con.execute(FUZZ_SQL, {"cur": date(today.year, today.month, 1), "today": today})
        cols = [d[0] for d in cur_.description]
        rows_by_case = {}
        for row in cur_.fetchall():
            r = dict(zip(cols, row))
            rows_by_case.setdefault(r["CaseId"], []).append(r)
        for case in batch:
            rows = sorted(rows_by_case[case["id"]], key=lambda r: chk.branch_order_key(r["Branch"]))
            lines = chk.allocate_group(rows, chk.branch_order_key)
            exp_rows = []
            for r in rows:
                e = {c: r[c] for c in EXPECTED_ROW_COLS if c in r}
                e["BaseQty"] = r["bq"]
                e.update(_suggested(lines, r["Branch"]))
                exp_rows.append({c: e[c] for c in EXPECTED_ROW_COLS})
            out[case["id"]] = {"id": case["id"], "kind": "full", "invalidTransferRules": invalid.get(case["id"], []),
                               "rows": exp_rows, "lines": lines}
    con.close()
    return out


def _expected_allocation(case: dict) -> dict:
    rows = [{**r, "Franchise": case["franchise"], "PartNumber": case["partNumber"], "cost": r["Cost"]}
            for r in case["rows"]]
    return {"id": case["id"], "kind": "allocation", "lines": chk.allocate_group(rows, chk.branch_order_key)}


def expected_for(cases: dict) -> dict:
    """expected.json for `cases` (the generate() output), from the reference's functions."""
    groups = cases["groups"]
    full = _expected_full([c for c in groups if c["kind"] == "full"])
    return {"version": VERSION, "seed": cases["seed"],
            "groups": [full[c["id"]] if c["kind"] == "full" else _expected_allocation(c) for c in groups]}


def dumps(obj) -> str:
    return json.dumps(obj, separators=(",", ":"), allow_nan=False) + "\n"


def write(seed: int, groups: int, out_dir: str) -> tuple:
    """Write cases.json and expected.json into out_dir; returns their paths."""
    cases = generate(seed, groups)
    expected = expected_for(cases)
    os.makedirs(out_dir, exist_ok=True)
    paths = (os.path.join(out_dir, "cases.json"), os.path.join(out_dir, "expected.json"))
    for path, obj in zip(paths, (cases, expected)):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(dumps(obj))
    return paths


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--groups", type=int, default=5000)
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    cases_p, expected_p = write(a.seed, a.groups, a.out)
    expected = json.load(open(expected_p, encoding="utf-8"))["groups"]
    lines = [l for g in expected for l in g["lines"]]
    print(f"{a.groups} groups (seed {a.seed}): {sum(1 for l in lines if l['Kind'] == 'Conventional')} conventional "
          f"and {sum(1 for l in lines if l['Kind'] == 'Redistribution')} redistribution lines, "
          f"{sum(len(g.get('invalidTransferRules', [])) for g in expected)} invalid transfer rules")
    print(f"wrote {cases_p} and {expected_p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
