# tools/dp-migration/nonjd_round1_impact.py
"""
Non-JD Parts Order Tool: what round 1 of Ben's answers does to the suggested order (Plan C Task C1).

Read-only, against the Dev lakehouses. Re-runs the suggested order over today's Dev data under six cumulative
scenarios and writes a short markdown report for Ben:
  1. today's logic, exactly as the current Gold, with today's rules (Default 12 months / 3 active months / 6 weeks;
     the cotton rules are inactive, so Default covers every part);
  2. + branches 12, 5, 97, 4B, 93C left out;
  3. + stocking needs 3 demands (transactions) instead of sales in 3 different months (still 6 weeks);
  4. + a target of 0 means order 0, whatever negative stock or on-order shows;
  5. + the Equip minimum always applies, even with no demand;
  6. + the Default rule at 12 weeks of supply.
The rule values are parameters here (SCENARIOS), not read from the list, so the report doesn't depend on the new
list columns (Task C0). Masks and Min overrides come from NonJD_PartSettings as Gold uses them.

Checks before writing:
  - scenario 1 is compared part by part with the current Fact_NonJD_Reorder (target and order quantity);
  - scenario 6 is compared with the round 1 reference (nonjd_reorder_check.EXPECTED_SQL) run with a single
    Default rule of 12 months / 3 demands / 12 weeks; totals must be identical.

Usage:
    python nonjd_round1_impact.py [--out <markdown path>]

Auth: Azure CLI (az login as Brian), read-only.
"""
import argparse
import sys
from datetime import date, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import nonjd_reorder_check as chk

TIER = "dev"
DEFAULT_OUT = (Path(__file__).resolve().parents[2] / "projects" / "part order tool - app" / "feedback"
               / "2026-10-26-round1-impact.md")
FOCUS_BRANCHES = ["1", "8", "92"]
HISTORY_MONTHS = 12
MIN_COUNT = 3          # 3 active months (today) or 3 demands (round 1)

# Cumulative: each scenario adds one change to the one before.
SCENARIOS = [
    dict(n=1, title="Today's logic", exclude=False, stock_on="active_months", target0_order0=False,
         equip_always=False, weeks=6,
         ben="What the tool suggests today: Default rule, 12 months of history, sales in at least 3 different "
             "months, 6 weeks of supply; an Equip minimum only counts if the part sold in the last 12 months."),
    dict(n=2, title="Leave out branches 12, 5, 97, 4B, 93C", exclude=True, stock_on="active_months",
         target0_order0=False, equip_always=False, weeks=6,
         ben="Same, without the five branches you asked to leave off."),
    dict(n=3, title="3 demands instead of 3 active months", exclude=True, stock_on="demands",
         target0_order0=False, equip_always=False, weeks=6,
         ben="A part is stocked when it had at least 3 demands (transactions) in the 12 months, however many "
             "months they fell in, instead of sales in 3 different months."),
    dict(n=4, title="Target 0 means order 0", exclude=True, stock_on="demands", target0_order0=True,
         equip_always=False, weeks=6,
         ben="A part the rules don't stock is never ordered, even when on hand or on order shows negative."),
    dict(n=5, title="Equip minimum always applies", exclude=True, stock_on="demands", target0_order0=True,
         equip_always=True, weeks=6,
         ben="The minimum in Equip sets the floor even when the part had no demand in the 12 months."),
    dict(n=6, title="Default at 12 weeks of supply", exclude=True, stock_on="demands", target0_order0=True,
         equip_always=True, weeks=12,
         ben="The Default rule holds 12 weeks of supply instead of 6. This is the round 1 Default."),
]

# One row per in-scope part (all branches, excluded ones flagged) with what every scenario needs. Every scenario
# uses 12 months of history on UnitsSold, so the demand figures are computed once. Mirrors the reference
# (nonjd_reorder_check.EXPECTED_SQL) and Gold: full months only, NULL demand counts as 0, negative net demand is
# 0, stock truncated toward zero, the latest settings row per part, a mask live until its expiry date.
BASE_SQL = f"""
    CREATE TABLE base AS
    WITH sc AS (
        SELECT * FROM parts
        WHERE Cost > 0
          AND upper(trim(Franchise)) NOT IN ('D', 'ZP', 'S', '95')
          AND NOT starts_with(upper(trim(Franchise)), 'T')
          AND NOT starts_with(upper(trim(Franchise)), 'U')
    ),
    ps AS (
        SELECT * EXCLUDE (rn) FROM (
            SELECT *, row_number() OVER (PARTITION BY Branch, Franchise, PartNumber
                                         ORDER BY Modified DESC, Id DESC) AS rn
            FROM settings) WHERE rn = 1
    ),
    monthly AS (
        SELECT Branch, Franchise, PartNumber, MonthStart,
               sum(coalesce(SalesQty, 0)) AS units, sum(coalesce(RequestCount, 0)) AS requests
        FROM hist WHERE MonthStart < $cur AND MonthStart >= $win_start
        GROUP BY ALL
    ),
    w AS (
        SELECT Branch, Franchise, PartNumber, sum(units) AS units, sum(requests) AS requests,
               count(*) FILTER (WHERE units > 0) AS active
        FROM monthly GROUP BY ALL
    )
    SELECT sc.Branch, sc.Franchise, sc.PartNumber, CAST(sc.Cost AS DOUBLE) AS cost,
           upper(trim(sc.Branch)) IN ({chk._EXCLUDED_SQL}) AS excluded,
           CAST(trunc(coalesce(sc.QuantityOnHand, 0)) AS INTEGER) AS oh,
           CAST(trunc(coalesce(sc.OnOrder, 0)) AS INTEGER) AS oo,
           CAST(ps.MinOverride AS DOUBLE) AS min_override, CAST(r.MinimumQty AS DOUBLE) AS equip_min,
           coalesce(ps.Masked, false) AND (ps.MaskExpires IS NULL OR ps.MaskExpires >= $today) AS masked,
           greatest(0.0, round(CAST(coalesce(w.units, 0) AS DOUBLE), 9)) AS window_demand,
           CAST(coalesce(w.active, 0) AS INTEGER) AS active_months,
           CAST(greatest(0, coalesce(w.requests, 0)) AS INTEGER) AS demand_count
    FROM sc
    LEFT JOIN rules r USING (Branch, Franchise, PartNumber)
    LEFT JOIN ps USING (Branch, Franchise, PartNumber)
    LEFT JOIN w USING (Branch, Franchise, PartNumber)
"""


def scenario_sql(s: dict) -> str:
    """Per part: target, order quantity, $ and the MinimumNoDemand flag under scenario s. With every switch off
    this is the current Gold's arithmetic (CalcTarget = ceil(round9(rate x weeks x 12 / 52)))."""
    stock_test = "active_months" if s["stock_on"] == "active_months" else "demand_count"
    eff_min = ("coalesce(min_override, equip_min, 0.0)" if s["equip_always"]
               else "coalesce(min_override, CASE WHEN active_months > 0 THEN equip_min END, 0.0)")
    target0 = "WHEN target = 0 THEN 0" if s["target0_order0"] else ""
    where = "WHERE NOT excluded" if s["exclude"] else ""
    return f"""
        SELECT *, order_qty * cost AS order_value
        FROM (SELECT *, CASE WHEN masked THEN 0 {target0} ELSE greatest(0, target - oh - oo) END AS order_qty
              FROM (SELECT *, CAST(greatest(calc_target, ceil(eff_min)) AS INTEGER) AS target
                    FROM (SELECT *,
                                 CASE WHEN {stock_test} >= {MIN_COUNT}
                                      THEN CAST(ceil(round(window_demand / {HISTORY_MONTHS} * {s['weeks']} * 12 / 52, 9))
                                                AS INTEGER)
                                      ELSE 0 END AS calc_target,
                                 {eff_min} AS eff_min,
                                 min_override IS NULL AND coalesce(equip_min, 0) > 0 AND demand_count = 0
                                   AS minimum_no_demand
                          FROM base {where})))
    """


def _totals(con, sql: str, extra_where: str = "") -> tuple:
    return con.execute(f"""SELECT count(*) FILTER (WHERE order_qty > 0), coalesce(sum(order_value), 0),
                                  count(*) FILTER (WHERE target > 0)
                           FROM ({sql}) {extra_where}""").fetchone()


def _money(x: float) -> str:
    return f"${x:,.0f}"


def _delta(cur, prev, money=False) -> str:
    if prev is None:
        return ""
    d = cur - prev
    if abs(d) < 0.5:
        return " (no change)"
    return f" ({'+' if d > 0 else '-'}{_money(abs(d)) if money else f'{abs(d):,}'})"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    a = ap.parse_args()

    con = chk._connect()
    gold_p = chk._path(TIER, "presentation", "Fact_NonJD_Reorder")
    built = con.execute(f"SELECT max(BuiltAtUtc) FROM delta_scan('{gold_p}')").fetchone()[0]
    if built.tzinfo is None:
        built = built.replace(tzinfo=timezone.utc)
    # The date the current Dev Gold was built on, so scenario 1 can be checked against it.
    today = built.astimezone(ZoneInfo("America/Chicago")).date()
    cur = date(today.year, today.month, 1)
    win_start = chk.add_months(cur, -HISTORY_MONTHS)
    print(f"Dev Gold built {built:%Y-%m-%d %H:%M} UTC; as of {today}; window {win_start} to before {cur}")

    chk.load_inputs(con, TIER, cur)
    last_req = con.execute("SELECT max(DateLastRequested) FROM parts").fetchone()[0]
    con.execute(BASE_SQL, {"cur": cur, "win_start": win_start, "today": today})
    print(f"base: {con.execute('SELECT count(*) FROM base').fetchone()[0]:,} in-scope parts")

    # ---- check 1: scenario 1 against the current Gold, part by part ----
    con.execute(f"CREATE TABLE s1 AS {scenario_sql(SCENARIOS[0])}")
    con.execute(f"""CREATE TABLE gold AS SELECT Branch, Franchise, PartNumber, StockingTarget, RecommendedOrderQty,
                    CAST(Cost AS DOUBLE) AS Cost FROM delta_scan('{gold_p}')""")
    g_only, s_only, diff = con.execute("""
        SELECT (SELECT count(*) FROM (SELECT Branch, Franchise, PartNumber FROM gold
                                      EXCEPT SELECT Branch, Franchise, PartNumber FROM s1)),
               (SELECT count(*) FROM (SELECT Branch, Franchise, PartNumber FROM s1
                                      EXCEPT SELECT Branch, Franchise, PartNumber FROM gold)),
               (SELECT count(*) FROM gold g JOIN s1 s USING (Branch, Franchise, PartNumber)
                WHERE g.StockingTarget IS DISTINCT FROM s.target OR g.RecommendedOrderQty IS DISTINCT FROM s.order_qty
                   OR g.Cost IS DISTINCT FROM s.cost)""").fetchone()
    gold_tot = con.execute("""SELECT count(*) FILTER (WHERE RecommendedOrderQty > 0),
                                     coalesce(sum(RecommendedOrderQty * Cost), 0), count(*) FILTER (WHERE StockingTarget > 0)
                              FROM gold""").fetchone()
    gold_b1 = con.execute("""SELECT count(*) FILTER (WHERE RecommendedOrderQty > 0),
                                    coalesce(sum(RecommendedOrderQty * Cost), 0) FROM gold WHERE trim(Branch) = '1'""").fetchone()
    print(f"scenario 1 vs Gold: only in Gold {g_only}, only in scenario 1 {s_only}, different {diff}")
    if diff or g_only or s_only:
        for row in con.execute("""SELECT g.*, s.target, s.order_qty, s.cost FROM gold g
                                  FULL JOIN s1 s USING (Branch, Franchise, PartNumber)
                                  WHERE g.StockingTarget IS DISTINCT FROM s.target
                                     OR g.RecommendedOrderQty IS DISTINCT FROM s.order_qty
                                     OR g.Cost IS DISTINCT FROM s.cost LIMIT 10""").fetchall():
            print("  ", row)

    # ---- the scenarios ----
    results = []
    for s in SCENARIOS:
        sql = scenario_sql(s)
        allb = _totals(con, sql)
        by_branch = {b: _totals(con, sql, f"WHERE trim(Branch) = '{b}'") for b in FOCUS_BRANCHES}
        mnd = None
        if s["equip_always"]:
            mnd = _totals(con, sql, "WHERE minimum_no_demand")
        results.append((s, allb, by_branch, mnd))
        print(f"scenario {s['n']}: lines {allb[0]:,}, {_money(allb[1])}, stocked {allb[2]:,}; "
              + "; ".join(f"B{b} {v[0]} / {_money(v[1])}" for b, v in by_branch.items())
              + (f"; MinimumNoDemand {mnd[0]:,} lines {_money(mnd[1])}" if mnd else ""))

    # the excluded branches at step 1 (to explain step 2)
    excl = con.execute(f"""SELECT count(*), count(*) FILTER (WHERE target > 0), count(*) FILTER (WHERE order_qty > 0),
                                  count(*) FILTER (WHERE minimum_no_demand)
                           FROM ({scenario_sql(SCENARIOS[0])}) WHERE excluded""").fetchone()

    s6_sql = scenario_sql(SCENARIOS[-1])
    top = con.execute(f"""SELECT Branch, Franchise, PartNumber, equip_min, oh, oo, order_qty, cost, order_value
                          FROM ({s6_sql}) WHERE minimum_no_demand AND order_qty > 0
                          ORDER BY order_value DESC, Branch, Franchise, PartNumber LIMIT 10""").fetchall()
    mnd_by_branch = con.execute(f"""SELECT trim(Branch) b, count(*), sum(order_value) FROM ({s6_sql})
                                    WHERE minimum_no_demand AND order_qty > 0 GROUP BY 1 ORDER BY 3 DESC""").fetchall()
    desc = {}
    if top:
        con.execute("CREATE TABLE top_keys (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR)")
        con.executemany("INSERT INTO top_keys VALUES (?, ?, ?)", [list(r[:3]) for r in top])
        info = chk._path(TIER, "staging", "Silver_PartInformation")
        desc = {(b, f, p): d for b, f, p, d in con.execute(
            f"""SELECT Branch, Franchise, PartNumber, i.Description FROM delta_scan('{info}') i
                JOIN top_keys USING (Branch, Franchise, PartNumber)""").fetchall()}

    # ---- check 2: scenario 6 against the round 1 reference with a single Default rule ----
    con.execute("DROP TABLE order_rules")
    con.execute("""CREATE TABLE order_rules AS SELECT 1::BIGINT AS Id, 'Default' AS RuleName, 0.0 AS Priority,
                   true AS Active, '' AS Franchise, '' AS DealerGroupCode, '' AS Branch, NULL::DOUBLE AS StartMonth,
                   NULL::DOUBLE AS EndMonth, 12.0 AS HistoryMonths, 12.0 AS WeeksOfCover, 'UnitsSold' AS DemandBasis,
                   3.0 AS MinDemands, 'Weeks' AS SupplyUnit, NULL::DOUBLE AS MinLineValue,
                   NULL::DOUBLE AS MaxLineValue, false AS Archived""")
    con.execute("CREATE TABLE ref AS " + chk.EXPECTED_SQL, {"cur": cur, "today": today})
    ref = con.execute("""SELECT count(*) FILTER (WHERE r.RecommendedOrderQty > 0),
                                coalesce(sum(r.RecommendedOrderQty * CAST(p.Cost AS DOUBLE)), 0),
                                count(*) FILTER (WHERE r.StockingTarget > 0)
                         FROM ref r JOIN parts p USING (Branch, Franchise, PartNumber)""").fetchone()
    s6 = results[-1][1]
    ref_ok = ref[0] == s6[0] and ref[2] == s6[2] and abs(ref[1] - s6[1]) < 0.005
    print(f"scenario 6 vs round 1 reference: {'match' if ref_ok else 'MISMATCH'} {ref} vs {s6}")

    md = render(results, top, desc, mnd_by_branch, excl, today, built, last_req, cur, win_start,
                (g_only, s_only, diff), gold_tot, gold_b1, ref_ok)
    Path(a.out).write_text(md, encoding="utf-8", newline="\n")
    print(f"wrote {a.out}")
    return 0 if ref_ok and not (g_only or s_only or diff) else 1


def render(results, top, desc, mnd_by_branch, excl, today, built, last_req, cur, win_start, gold_cmp, gold_tot,
           gold_b1, ref_ok) -> str:
    last_full = chk.add_months(cur, -1)
    L = []
    L.append("# Round 1 changes: what they do to the suggested order")
    L.append("")
    L.append(f"*Dev data as of {today:%B} {today.day}, {today.year}* (Dev refresh of {built:%Y-%m-%d %H:%M} UTC; latest part request "
             f"in the data {last_req:%Y-%m-%d}). Demand window: {win_start:%b %Y} to {last_full:%b %Y}, the 12 full "
             "months before the run. Produced by `tools/dp-migration/nonjd_round1_impact.py` (Plan C, Task C1).")
    L.append("")
    L.append("## What this shows")
    L.append("")
    L.append("Ben, this is the suggested order for every branch, recalculated on the same day's data with your "
             "round 1 answers switched on one at a time. Each step keeps the changes before it, so the last row is "
             "the tool as it will work after round 1 (with the Default rule only: no cotton rule, no line value "
             "limits, no masks beyond the ones already set). **Lines** are parts with a suggested order, **$** is "
             "suggested quantity x cost, and **Stocked** is how many parts have a target above 0.")
    L.append("")
    for s, *_ in results:
        L.append(f"{s['n']}. **{s['title']}.** {s['ben']}")
    L.append("")
    L.append("## All branches")
    L.append("")
    L.append("| Step | Lines | $ | Stocked |")
    L.append("|---|---:|---:|---:|")
    prev = None
    for s, allb, _, _ in results:
        L.append(f"| {s['n']}. {s['title']} | {allb[0]:,}{_delta(allb[0], prev and prev[0])} | "
                 f"{_money(allb[1])}{_delta(allb[1], prev and prev[1], True)} | "
                 f"{allb[2]:,}{_delta(allb[2], prev and prev[2])} |")
        prev = allb
    L.append("")
    L.append(f"Step 1 includes the five branches that step 2 leaves out. They hold {excl[0]:,} in-scope parts but "
             f"none is stocked ({excl[1]:,}) or suggested ({excl[2]:,}) today, so step 2 changes nothing now; it "
             f"keeps the {excl[3]:,} Equip minimums there on parts with no demand out of step 5.")
    L.append("")
    L.append("## Branches 1, 8 and 92")
    L.append("")
    L.append("| Step | " + " | ".join(f"Branch {b} lines | Branch {b} $" for b in FOCUS_BRANCHES) + " |")
    L.append("|---|" + "---:|---:|" * len(FOCUS_BRANCHES))
    for s, _, by_branch, _ in results:
        L.append(f"| {s['n']}. {s['title']} | "
                 + " | ".join(f"{by_branch[b][0]:,} | {_money(by_branch[b][1])}" for b in FOCUS_BRANCHES) + " |")
    L.append("")
    L.append("Stocked parts: " + "; ".join(
        f"Branch {b} {results[0][2][b][2]:,} at step 1, {results[-1][2][b][2]:,} at step 6" for b in FOCUS_BRANCHES)
        + ".")
    L.append("")
    L.append("## Equip minimums on parts with no demand")
    L.append("")
    L.append("From step 5 the Equip minimum counts even when the part had no demand in the 12 months. These are "
             "the parts the Cleanup list will show (minimum set, no demand, no Min override in the app). What they "
             "add to the order:")
    L.append("")
    L.append("| Step | Lines | $ |")
    L.append("|---|---:|---:|")
    for s, _, _, mnd in results:
        if mnd:
            L.append(f"| {s['n']}. {s['title']} | {mnd[0]:,} | {_money(mnd[1])} |")
    L.append("")
    if mnd_by_branch:
        L.append("By branch at step 6 (largest first): " + "; ".join(
            f"{b} {n:,} lines / {_money(v)}" for b, n, v in mnd_by_branch[:8])
            + ("; others smaller." if len(mnd_by_branch) > 8 else "."))
        L.append("")
    mnd6 = results[-1][3]
    top3 = sum(r[8] for r in top[:3])
    if mnd6 and mnd6[1]:
        L.append(f"The three largest lines below are {_money(top3)} of the {_money(mnd6[1])} "
                 f"({top3 / mnd6[1]:.0%}); without them these minimums add {_money(mnd6[1] - top3)}. Several of "
                 "the largest minimums look like data-entry errors in Equip (a minimum far above anything the "
                 "branch sells, or the price typed into the minimum field), which is what Cleanup is for. A Min "
                 "override of 0 in the app, or fixing the minimum in Equip, takes a line off.")
        L.append("")
    L.append("Top 10 of these lines by $ at step 6:")
    L.append("")
    L.append("| Branch | Franchise | Part | Description | Equip min | On hand | On order | Order | Cost | $ |")
    L.append("|---|---|---|---|---:|---:|---:|---:|---:|---:|")
    for b, f, p, emin, oh, oo, q, cost, val in top:
        d = (desc.get((b, f, p)) or "").replace("|", "/").strip()
        L.append(f"| {b} | {f} | {p.strip()} | {d} | {emin:g} | {oh} | {oo} | {q} | ${cost:,.2f} | {_money(val)} |")
    L.append("")
    L.append("## Checks")
    L.append("")
    g_only, s_only, diff = gold_cmp
    L.append(f"- Step 1 against the current Dev Gold table, part by part: {g_only} parts only in Gold, {s_only} only "
             f"in step 1, {diff} with a different target, order or cost. Gold totals: {gold_tot[0]:,} lines, "
             f"{_money(gold_tot[1])}, {gold_tot[2]:,} stocked; Branch 1 {gold_b1[0]:,} lines / {_money(gold_b1[1])}.")
    L.append(f"- Step 6 against the round 1 reference rules (`nonjd_reorder_check.py`) with one Default rule of "
             f"12 months / 3 demands / 12 weeks: {'identical totals' if ref_ok else 'MISMATCH, see the script output'}.")
    L.append("")
    return "\n".join(L)


if __name__ == "__main__":
    sys.exit(main())
