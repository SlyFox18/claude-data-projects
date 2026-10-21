# tools/dp-migration/test_nonjd_reorder_check.py
"""Tests for the reference reorder rules (spec 2026-10-20 non-JD order tool, section 5.5) and compare()."""
from datetime import date

import duckdb
import pytest

import nonjd_reorder_check as chk

CUR = date(2026, 10, 1)      # current (partial) month of the run; full months end 2026-09
TODAY = date(2026, 10, 20)


# ---------------------------------------------------------------------------------------------------------
# fixtures
# ---------------------------------------------------------------------------------------------------------
def _con():
    con = duckdb.connect()
    con.execute("""CREATE TABLE parts (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   QuantityOnHand DECIMAL(12,2), OnOrder DECIMAL(12,2), Cost DECIMAL(12,2), DealerGroupCode VARCHAR)""")
    con.execute("CREATE TABLE rules (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MinimumQty DECIMAL(10,2))")
    con.execute("""CREATE TABLE hist (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MonthStart DATE,
                   SalesQty DECIMAL(12,2), RequestCount INTEGER)""")
    con.execute("""CREATE TABLE order_rules (Id BIGINT, RuleName VARCHAR, Priority DOUBLE, Active BOOLEAN,
                   Franchise VARCHAR, DealerGroupCode VARCHAR, Branch VARCHAR, StartMonth DOUBLE, EndMonth DOUBLE,
                   HistoryMonths DOUBLE, MinActiveMonths DOUBLE, WeeksOfCover DOUBLE, DemandBasis VARCHAR,
                   Modified TIMESTAMP)""")
    con.execute("""CREATE TABLE settings (Id INTEGER, Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   MinOverride DOUBLE, Masked BOOLEAN, MaskExpires DATE, Modified TIMESTAMP)""")
    con.execute("CREATE TABLE transfers (RequestingBranch VARCHAR, PartNumber VARCHAR, OpenQty DOUBLE)")
    return con


def _part(con, pn, oh=0, oo=0, cost=10, branch="1", franchise="MC", dgc=None):
    con.execute("INSERT INTO parts VALUES (?, ?, ?, ?, ?, ?, ?)", [branch, franchise, pn, oh, oo, cost, dgc])


def _hist(con, pn, months, branch="1", franchise="MC"):
    """months: {MonthStart (date or 'YYYY-MM-DD'): (SalesQty, RequestCount)}"""
    for m, (sales, reqs) in months.items():
        con.execute("INSERT INTO hist VALUES (?, ?, ?, ?, ?, ?)", [branch, franchise, pn, m, sales, reqs])


def _rule(con, rid, name=None, priority=0, active=True, franchise=None, dgc=None, branch=None, start=None,
          end=None, hm=12, mam=3, woc=6, basis="UnitsSold"):
    con.execute("INSERT INTO order_rules VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, TIMESTAMP '2026-10-01')",
                [rid, name or f"R{rid}", priority, active, franchise, dgc, branch, start, end, hm, mam, woc, basis])


def _minimum(con, pn, qty, branch="1", franchise="MC"):
    con.execute("INSERT INTO rules VALUES (?, ?, ?, ?)", [branch, franchise, pn, qty])


def _minimum_with_demand(con, pn, qty, branch="1", franchise="MC"):
    """Equip minimum plus one month with 1 unit sold, so the minimum applies (spec 5.5 step 6: only with demand).
    Under the built-in default (3 active months needed) CalcTarget stays 0, so the minimum decides the target."""
    _minimum(con, pn, qty, branch, franchise)
    _hist(con, pn, {"2026-09-01": (1, 0)}, branch, franchise)


def K(pn, branch="1", franchise="MC"):
    """Key of one output row."""
    return (branch, franchise, pn)


def _run(con, cur=CUR, today=TODAY):
    """Expected rows keyed by (Branch, Franchise, PartNumber); fails on a duplicate key."""
    cur_ = chk.expected_reorder(con, cur, today)
    cols = [d[0] for d in cur_.description]
    rows = [dict(zip(cols, r)) for r in cur_.fetchall()]
    out = {(r["Branch"], r["Franchise"], r["PartNumber"]): r for r in rows}
    assert len(out) == len(rows), "duplicate keys in the expected output"
    return out


def _simple_rule(con, **kw):
    """One catch-all rule that stocks on any activity: 12 months, 0 active months needed, 52 weeks of cover
    (so CalcTarget = ceil(WindowDemand))."""
    _rule(con, 1, "Simple", **{"mam": 0, "woc": 52, **kw})


# ---------------------------------------------------------------------------------------------------------
# output shape and scope
# ---------------------------------------------------------------------------------------------------------
def test_output_columns():
    con = _con()
    cur_ = chk.expected_reorder(con, CUR, TODAY)
    assert [d[0] for d in cur_.description] == [
        "Branch", "Franchise", "PartNumber", "RuleId", "RuleName", "DemandBasis", "HistoryMonths",
        "MinActiveMonths", "WeeksOfCover", "WindowDemand", "ActiveMonths", "MonthlyRate", "CalcTarget",
        "EffectiveMin", "MinimumIgnored", "StockingTarget", "RecommendedOrderQty", "SurplusQty",
        "InboundTransferQty", "Status"]


def test_scope_excludes_jd_test_franchises_and_zero_cost():
    con = _con()
    for pn, fr, cost in [("JD1", "D", 5), ("T1", "TD", 5), ("U1", "UM", 5), ("Z1", "ZP", 5), ("S1", "S", 5),
                         ("N95", "95", 5), ("FREE", "MC", 0), ("OK1", "MC", 5), ("DA1", "DA", 5)]:
        _part(con, pn, franchise=fr, cost=cost)
    assert sorted(_run(con)) == [K("DA1", franchise="DA"), K("OK1")]


# ---------------------------------------------------------------------------------------------------------
# rule selection
# ---------------------------------------------------------------------------------------------------------
def test_builtin_default_when_no_rules():
    con = _con()
    _part(con, "P1")
    r = _run(con)[K("P1")]
    assert r["RuleId"] is None and r["RuleName"] == "Built-in default"
    assert (r["HistoryMonths"], r["MinActiveMonths"], r["WeeksOfCover"], r["DemandBasis"]) == (12, 3, 6, "UnitsSold")


def test_builtin_default_when_no_rule_matches():
    con = _con()
    _part(con, "P1", dgc="PEANUT")
    _rule(con, 1, franchise="XX")
    _rule(con, 2, dgc="COTTON")
    _rule(con, 3, branch="2")
    r = _run(con)[K("P1")]
    assert r["RuleId"] is None and r["RuleName"] == "Built-in default"


def test_highest_priority_wins():
    con = _con()
    _part(con, "P1", dgc="COTTON")
    _rule(con, 1, "Low", priority=0)
    _rule(con, 2, "High", priority=10, dgc="COTTON", woc=10)
    _rule(con, 3, "Mid", priority=5)
    r = _run(con)[K("P1")]
    assert (r["RuleId"], r["RuleName"], r["WeeksOfCover"]) == (2, "High", 10)


def test_negative_and_fractional_priority_order():
    con = _con()
    _part(con, "P1")
    _rule(con, 1, priority=-1)
    _rule(con, 2, priority=0.5)
    assert _run(con)[K("P1")]["RuleId"] == 2


def test_priority_tie_goes_to_more_criteria_then_lowest_id():
    con = _con()
    _part(con, "P1", dgc="COTTON")
    _part(con, "P2", dgc="PEANUT")
    _rule(con, 7, priority=5, franchise="MC")
    _rule(con, 3, priority=5, franchise="MC", dgc="COTTON")
    _rule(con, 9, priority=5)
    _rule(con, 4, priority=5, branch="1")
    r = _run(con)
    assert r[K("P1")]["RuleId"] == 3          # two criteria beats one
    assert r[K("P2")]["RuleId"] == 4          # rules 7 and 4 both have one criterion: lowest Id


def test_season_does_not_count_as_a_criterion():
    con = _con()
    _part(con, "P1")
    _rule(con, 2, priority=5, start=1, end=12)
    _rule(con, 5, priority=5, franchise="MC")
    assert _run(con)[K("P1")]["RuleId"] == 5


def test_blank_criteria_mean_any():
    con = _con()
    _part(con, "P1", dgc=None)
    _rule(con, 1, franchise="  ", dgc="", branch=" ")
    assert _run(con)[K("P1")]["RuleId"] == 1


def test_inactive_rule_ignored():
    con = _con()
    _part(con, "P1")
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, active=False)
    _rule(con, 3, priority=20, active=None)
    assert _run(con)[K("P1")]["RuleId"] == 1


def test_criteria_trimmed_and_case_insensitive():
    con = _con()
    _part(con, "P1", franchise="m", dgc="COTTON", branch="1 ")
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, franchise="M", dgc=" cotton ", branch=" 1")
    assert _run(con)[K("P1", branch="1 ", franchise="m")]["RuleId"] == 2


def test_part_without_dealer_group_does_not_match_dealer_group_rule():
    con = _con()
    _part(con, "P1", dgc=None)
    _part(con, "P2", dgc="  ")
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, dgc="COTTON")
    r = _run(con)
    assert r[K("P1")]["RuleId"] == 1 and r[K("P2")]["RuleId"] == 1


def test_dealer_group_is_per_branch():
    con = _con()
    _part(con, "P1", branch="1", dgc="COTTON")
    _part(con, "P1", branch="2", dgc="PEANUT")
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, dgc="COTTON")
    r = _run(con)
    assert r[K("P1", "1")]["RuleId"] == 2 and r[K("P1", "2")]["RuleId"] == 1


@pytest.mark.parametrize("start,end,cur,applies", [
    (6, 10, date(2026, 10, 1), True),     # inside, end edge
    (6, 10, date(2026, 6, 1), True),      # inside, start edge
    (6, 10, date(2026, 11, 1), False),    # outside
    (6, 10, date(2026, 5, 1), False),     # outside
    (11, 2, date(2027, 1, 1), True),      # wrapping range, January
    (11, 2, date(2026, 11, 1), True),     # wrapping range, start edge
    (11, 2, date(2027, 2, 1), True),      # wrapping range, end edge
    (11, 2, date(2026, 6, 1), False),     # wrapping range, June
    (11, 2, date(2027, 3, 1), False),
    (7, 7, date(2026, 7, 1), True),       # one-month season
    (7, 7, date(2026, 8, 1), False),
])
def test_season(start, end, cur, applies):
    con = _con()
    _part(con, "P1")
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, start=start, end=end)
    assert _run(con, cur=cur, today=cur)[K("P1")]["RuleId"] == (2 if applies else 1)


@pytest.mark.parametrize("cur,dgc,expected", [
    (date(2026, 7, 1), "COTTON", 2),      # in season and matching group
    (date(2026, 12, 1), "COTTON", 3),     # off season: the wrapping off-season rule applies
    (date(2026, 7, 1), "PEANUT", 1),      # in season but another group
])
def test_season_plus_criteria(cur, dgc, expected):
    con = _con()
    _part(con, "P1", dgc=dgc)
    _rule(con, 1, "Default", priority=0)
    _rule(con, 2, "Cotton - in season", priority=10, dgc="COTTON", start=6, end=10)
    _rule(con, 3, "Cotton - off season", priority=10, dgc="COTTON", start=11, end=5)
    assert _run(con, cur=cur, today=cur)[K("P1")]["RuleId"] == expected


# ---------------------------------------------------------------------------------------------------------
# invalid rules
# ---------------------------------------------------------------------------------------------------------
MONTHS_BOTH = "StartMonth and EndMonth must both be set or both blank"
START_1_12 = "StartMonth must be a whole number 1-12"
WOC = "WeeksOfCover must be 0-104"
HM = "HistoryMonths must be a whole number 1-59"
MAM = "MinActiveMonths must be a whole number 0-59"
BASIS = "DemandBasis must be UnitsSold or Requests"
INVALID = {
    "start month only": (dict(start=6), MONTHS_BOTH),
    "end month only": (dict(end=10), MONTHS_BOTH),
    "month 13": (dict(start=6, end=13), "EndMonth must be a whole number 1-12"),
    "month 0": (dict(start=0, end=5), START_1_12),
    "fractional month": (dict(start=2.5, end=5), START_1_12),
    "missing WeeksOfCover": (dict(woc=None), WOC),
    "negative WeeksOfCover": (dict(woc=-1), WOC),
    "WeeksOfCover 105": (dict(woc=105), WOC),
    "infinite WeeksOfCover": (dict(woc=float("inf")), WOC),
    "NaN WeeksOfCover": (dict(woc=float("nan")), WOC),
    "missing HistoryMonths": (dict(hm=None), "HistoryMonths is missing"),
    "HistoryMonths 0": (dict(hm=0), HM),
    "HistoryMonths 60": (dict(hm=60), HM),
    "fractional HistoryMonths": (dict(hm=6.5), HM),
    "NaN HistoryMonths": (dict(hm=float("nan")), HM),
    "missing MinActiveMonths": (dict(mam=None), "MinActiveMonths is missing"),
    "negative MinActiveMonths": (dict(mam=-1), MAM),
    "MinActiveMonths 60": (dict(mam=60), MAM),
    "fractional MinActiveMonths": (dict(mam=1.5), MAM),
    "missing Priority": (dict(priority=None), "Priority is missing"),
    "unknown basis": (dict(basis="Dollars"), BASIS),
    "missing basis": (dict(basis=None), BASIS),
}


@pytest.mark.parametrize("kw,reason", INVALID.values(), ids=INVALID.keys())
def test_invalid_rule_skipped_and_reported(kw, reason):
    con = _con()
    _part(con, "P1")
    _rule(con, 1, "Good", priority=0)
    _rule(con, 2, "Bad", **{"priority": 10, **kw})
    assert _run(con)[K("P1")]["RuleId"] == 1
    assert chk.invalid_rules(con) == [(2, "Bad", reason)]


def test_weeks_of_cover_bounds_are_valid():
    con = _con()
    _rule(con, 1, woc=0)
    _rule(con, 2, woc=104)
    assert chk.invalid_rules(con) == []


@pytest.mark.parametrize("name", [None, "", "   "])
def test_missing_rule_name_falls_back_to_rule_id(name):
    con = _con()
    _part(con, "P1")
    _rule(con, 7)
    _rule(con, 8, active=True, basis="X")
    con.execute("UPDATE order_rules SET RuleName = ?", [name])
    assert _run(con)[K("P1")]["RuleName"] == "Rule 7"
    assert chk.invalid_rules(con) == [(8, "Rule 8", BASIS)]


def test_invalid_rules_lists_every_problem_and_ignores_valid_and_inactive_rules():
    con = _con()
    _rule(con, 1, "Good", start=11, end=2, hm=59, mam=0, woc=0, basis=" requests ")
    _rule(con, 2, "Off", active=False, start=13)
    _rule(con, 3, "Two problems", start=6, basis="X")
    bad = chk.invalid_rules(con)
    assert [(i, n) for i, n, _ in bad] == [(3, "Two problems")]
    reason = bad[0][2]
    assert "StartMonth" in reason and "DemandBasis" in reason


def test_demand_basis_trimmed_and_case_insensitive():
    con = _con()
    _part(con, "P1")
    _rule(con, 1, basis=" requests ")
    r = _run(con)[K("P1")]
    assert r["RuleId"] == 1 and r["DemandBasis"] == "Requests"


# ---------------------------------------------------------------------------------------------------------
# demand window and calculation
# ---------------------------------------------------------------------------------------------------------
def test_window_is_full_months_only():
    con = _con()
    _part(con, "W1")
    _hist(con, "W1", {"2026-10-01": (100, 0),     # current partial month: excluded
                      "2026-09-01": (1, 0),       # current - 1: included
                      "2025-10-01": (2, 0),       # current - 12: included
                      "2025-09-01": (400, 0),     # current - 13: excluded
                      "2026-11-01": (800, 0)})    # future: excluded
    _simple_rule(con)
    r = _run(con)[K("W1")]
    assert r["WindowDemand"] == pytest.approx(3.0) and r["ActiveMonths"] == 2


def test_window_follows_rule_history_months():
    con = _con()
    _part(con, "W3")
    _hist(con, "W3", {"2026-09-01": (1, 0), "2026-07-01": (2, 0), "2026-06-01": (4, 0)})
    _simple_rule(con, hm=3)
    r = _run(con)[K("W3")]
    assert r["HistoryMonths"] == 3
    assert r["WindowDemand"] == pytest.approx(3.0) and r["ActiveMonths"] == 2
    assert r["MonthlyRate"] == pytest.approx(1.0)


def test_negative_window_demand_is_zero_and_only_positive_months_are_active():
    con = _con()
    _part(con, "NEG")
    _hist(con, "NEG", {"2026-09-01": (2, 0), "2026-08-01": (-5, 0), "2026-07-01": (0, 3)})
    _simple_rule(con)
    r = _run(con)[K("NEG")]
    assert r["WindowDemand"] == 0 and r["ActiveMonths"] == 1
    assert r["MonthlyRate"] == 0 and r["CalcTarget"] == 0
    assert r["Status"] == "NotStocked"


def test_null_demand_counts_as_zero():
    con = _con()
    _part(con, "NUL")
    _hist(con, "NUL", {"2026-09-01": (None, None), "2026-08-01": (3, None)})
    _simple_rule(con)
    r = _run(con)[K("NUL")]
    assert r["WindowDemand"] == pytest.approx(3.0) and r["ActiveMonths"] == 1


def test_monthly_rate_uses_history_months_not_active_months():
    con = _con()
    _part(con, "ONE")
    _hist(con, "ONE", {"2026-05-01": (6, 1)})
    _rule(con, 1, mam=1, woc=6)
    r = _run(con)[K("ONE")]
    assert r["MonthlyRate"] == pytest.approx(0.5)          # 6 / 12, not 6 / 1
    assert r["CalcTarget"] == 1                             # ceil(0.5 * 6 * 12 / 52 = 0.69)


def test_requests_basis_uses_request_count():
    con = _con()
    _part(con, "RQ")
    _hist(con, "RQ", {"2026-09-01": (1, 12), "2026-08-01": (0, 12)})
    _simple_rule(con, basis="Requests")
    r = _run(con)[K("RQ")]
    assert r["DemandBasis"] == "Requests"
    assert r["WindowDemand"] == pytest.approx(24.0) and r["ActiveMonths"] == 2


def test_units_sold_basis_ignores_requests():
    con = _con()
    _part(con, "US")
    _hist(con, "US", {"2026-09-01": (1, 12), "2026-08-01": (0, 12)})
    _simple_rule(con)
    r = _run(con)[K("US")]
    assert r["WindowDemand"] == pytest.approx(1.0) and r["ActiveMonths"] == 1


def test_calc_target_formula_and_order():
    # spec worked example: sold 18 in 12 months (1.5 a month) x 10 weeks of cover -> target 4; on hand 1 -> order 3
    con = _con()
    _part(con, "COT", oh=1, dgc="COTTON")
    _hist(con, "COT", {"2026-09-01": (6, 0), "2026-08-01": (6, 0), "2026-07-01": (6, 0)})
    _rule(con, 1, "Cotton - in season", dgc="COTTON", start=6, end=10, hm=12, mam=2, woc=10)
    r = _run(con)[K("COT")]
    assert r["RuleName"] == "Cotton - in season"
    assert r["MonthlyRate"] == pytest.approx(1.5)
    assert r["CalcTarget"] == 4                             # ceil(1.5 * 10 * 12 / 52 = 3.46)
    assert r["StockingTarget"] == 4
    assert r["RecommendedOrderQty"] == 3 and r["Status"] == "Reorder"


def test_calc_target_rounds_away_floating_point_noise():
    # (5 / 3) * 5.2 * 12 / 52 is exactly 2 but evaluates to 2.0000000000000004 in doubles
    con = _con()
    _part(con, "FP")
    _hist(con, "FP", {"2026-09-01": (5, 0)})
    _rule(con, 1, hm=3, mam=1, woc=5.2)
    assert _run(con)[K("FP")]["CalcTarget"] == 2


def test_default_rule_calculation():
    con = _con()
    _part(con, "D1")
    # 26 units in 3 active months over 12 -> 26/12 a month x 6 weeks -> exactly 3
    _hist(con, "D1", {"2026-09-01": (10, 0), "2026-04-01": (10, 0), "2025-11-01": (6, 0)})
    r = _run(con)[K("D1")]
    assert r["ActiveMonths"] == 3 and r["CalcTarget"] == 3 and r["StockingTarget"] == 3
    assert r["Status"] == "OutOfStock"


def test_below_min_active_months_calc_zero_but_minimum_sets_target():
    con = _con()
    _part(con, "BM", oh=1)
    _minimum(con, "BM", 4)
    _hist(con, "BM", {"2026-09-01": (50, 0), "2026-08-01": (50, 0)})
    r = _run(con)[K("BM")]                                     # built-in default needs 3 active months
    assert r["ActiveMonths"] == 2 and r["CalcTarget"] == 0
    assert r["EffectiveMin"] == pytest.approx(4.0) and r["StockingTarget"] == 4
    assert r["RecommendedOrderQty"] == 3 and r["Status"] == "Reorder"


def test_target_is_larger_of_calc_and_minimum():
    con = _con()
    _part(con, "BIG")
    _part(con, "SMALL")
    _minimum(con, "BIG", 2)
    _minimum(con, "SMALL", 9)
    for pn in ("BIG", "SMALL"):
        _hist(con, pn, {"2026-09-01": (5, 0)})
    _simple_rule(con)
    r = _run(con)
    assert (r[K("BIG")]["CalcTarget"], r[K("BIG")]["StockingTarget"]) == (5, 5)
    assert (r[K("SMALL")]["CalcTarget"], r[K("SMALL")]["StockingTarget"]) == (5, 9)


def test_fractional_minimum_rounds_up():
    con = _con()
    _part(con, "FM")
    _minimum_with_demand(con, "FM", 2.5)
    r = _run(con)[K("FM")]
    assert r["EffectiveMin"] == pytest.approx(2.5) and r["StockingTarget"] == 3


def test_min_override_beats_equip_minimum_latest_settings_row_wins():
    con = _con()
    _part(con, "P3")
    _minimum(con, "P3", 4)
    con.execute("""INSERT INTO settings VALUES
        (1,'1','MC','P3',2,false,NULL,'2026-10-01 10:00'), (2,'1','MC','P3',7,false,NULL,'2026-10-05 10:00')""")
    r = _run(con)[K("P3")]
    assert r["EffectiveMin"] == pytest.approx(7.0) and r["StockingTarget"] == 7


def test_equip_minimum_ignored_without_demand():
    con = _con()
    _part(con, "STALE", oh=0)
    _minimum(con, "STALE", 4)
    r = _run(con)[K("STALE")]
    assert r["ActiveMonths"] == 0 and r["MinimumIgnored"] is True
    assert (r["EffectiveMin"], r["StockingTarget"], r["RecommendedOrderQty"]) == (0, 0, 0)
    assert r["Status"] == "NoRecentActivity"


def test_equip_minimum_applies_with_demand_below_min_active_months():
    con = _con()
    _part(con, "LIVE", oh=0)
    _minimum(con, "LIVE", 4)
    _hist(con, "LIVE", {"2026-09-01": (1, 0)})            # 1 active month < 3: CalcTarget 0
    r = _run(con)[K("LIVE")]
    assert (r["ActiveMonths"], r["CalcTarget"], r["MinimumIgnored"]) == (1, 0, False)
    assert r["EffectiveMin"] == pytest.approx(4.0) and r["StockingTarget"] == 4
    assert r["RecommendedOrderQty"] == 4 and r["Status"] == "OutOfStock"


def test_demand_only_outside_the_rule_window_counts_as_no_demand():
    con = _con()
    _part(con, "OLD")
    _minimum(con, "OLD", 4)
    _hist(con, "OLD", {"2026-10-01": (5, 0),              # current partial month
                       "2025-09-01": (5, 0)})             # current - 13, outside the default 12 months
    r = _run(con)[K("OLD")]
    assert r["ActiveMonths"] == 0 and r["MinimumIgnored"] is True
    assert r["EffectiveMin"] == 0 and r["StockingTarget"] == 0


def test_min_override_applies_without_demand():
    con = _con()
    _part(con, "OVR")
    _minimum(con, "OVR", 4)
    con.execute("INSERT INTO settings VALUES (1,'1','MC','OVR',2,false,NULL,'2026-10-01 10:00')")
    r = _run(con)[K("OVR")]
    assert r["ActiveMonths"] == 0 and r["MinimumIgnored"] is False
    assert r["EffectiveMin"] == pytest.approx(2.0) and r["StockingTarget"] == 2
    assert r["RecommendedOrderQty"] == 2 and r["Status"] == "OutOfStock"


@pytest.mark.parametrize("qty", [0, None])
def test_zero_or_missing_equip_minimum_is_not_flagged(qty):
    con = _con()
    _part(con, "Z")
    _part(con, "NOROW")
    _minimum(con, "Z", qty)
    r = _run(con)
    assert r[K("Z")]["MinimumIgnored"] is False and r[K("NOROW")]["MinimumIgnored"] is False


def test_settings_tie_on_modified_breaks_by_id_desc():
    con = _con()
    _part(con, "S1")
    con.execute("""INSERT INTO settings VALUES (9,'1','MC','S1',6,false,NULL,'2026-10-05 10:00'),
                   (3,'1','MC','S1',2,false,NULL,'2026-10-05 10:00')""")
    assert _run(con)[K("S1")]["StockingTarget"] == 6


# ---------------------------------------------------------------------------------------------------------
# masking, status, quantities
# ---------------------------------------------------------------------------------------------------------
def test_masked_part_orders_nothing():
    con = _con()
    _part(con, "P4")
    _minimum_with_demand(con, "P4", 3)
    con.execute("INSERT INTO settings VALUES (3,'1','MC','P4',NULL,true,'2026-12-31','2026-10-01 10:00')")
    r = _run(con)[K("P4")]
    assert r["StockingTarget"] == 3
    assert r["RecommendedOrderQty"] == 0 and r["Status"] == "Masked"


def test_masked_wins_over_no_recent_activity():
    con = _con()
    _part(con, "P4")
    con.execute("INSERT INTO settings VALUES (3,'1','MC','P4',NULL,true,NULL,'2026-10-01 10:00')")
    assert _run(con)[K("P4")]["Status"] == "Masked"


def test_expired_mask_is_ignored():
    con = _con()
    _part(con, "P5")
    _minimum_with_demand(con, "P5", 1)
    con.execute("INSERT INTO settings VALUES (1,'1','MC','P5',NULL,true,'2026-10-19','2026-10-01 10:00')")
    assert _run(con)[K("P5")]["Status"] == "OutOfStock"


def test_mask_expiring_today_still_masks():
    con = _con()
    _part(con, "M1")
    _minimum_with_demand(con, "M1", 1)
    con.execute("INSERT INTO settings VALUES (1,'1','MC','M1',NULL,true,'2026-10-20','2026-10-01 10:00')")
    assert _run(con)[K("M1")]["Status"] == "Masked"


def test_not_stocked_vs_no_recent_activity():
    con = _con()
    _part(con, "NRA", oh=2)
    _part(con, "NS", oh=2)
    _hist(con, "NS", {"2026-09-01": (1, 0)})                # 1 active month < 3 needed by the default
    r = _run(con)
    nra, ns = r[K("NRA")], r[K("NS")]
    assert (nra["ActiveMonths"], nra["StockingTarget"], nra["Status"]) == (0, 0, "NoRecentActivity")
    assert (ns["ActiveMonths"], ns["StockingTarget"], ns["Status"]) == (1, 0, "NotStocked")
    assert nra["RecommendedOrderQty"] == 0 and ns["RecommendedOrderQty"] == 0


def test_zero_weeks_of_cover_with_activity_is_not_stocked():
    con = _con()
    _part(con, "Z0")
    _hist(con, "Z0", {"2026-09-01": (5, 0)})
    _simple_rule(con, woc=0)
    r = _run(con)[K("Z0")]
    assert (r["ActiveMonths"], r["CalcTarget"], r["StockingTarget"], r["Status"]) == (1, 0, 0, "NotStocked")


def test_ok_status_when_stock_covers_target():
    con = _con()
    _part(con, "OK", oh=3, oo=1)
    _minimum_with_demand(con, "OK", 4)
    r = _run(con)[K("OK")]
    assert r["RecommendedOrderQty"] == 0 and r["Status"] == "OK"


def test_surplus_and_truncated_quantities():
    con = _con()
    _part(con, "P6", oh=10.7, branch="92")
    _part(con, "P7", oh=9.9, branch="92")
    _minimum_with_demand(con, "P7", 4, branch="92")
    r = _run(con)
    assert r[K("P6", "92")]["Status"] == "NoRecentActivity"
    assert r[K("P6", "92")]["StockingTarget"] == 0 and r[K("P6", "92")]["SurplusQty"] == 10
    assert r[K("P7", "92")]["SurplusQty"] == 5                       # trunc(9.9) = 9 minus target 4
    assert r[K("P7", "92")]["Status"] == "OK"


def test_null_on_hand_counts_as_out_of_stock():
    con = _con()
    _part(con, "P8", oh=None)
    _minimum_with_demand(con, "P8", 1)
    r = _run(con)[K("P8")]
    assert r["RecommendedOrderQty"] == 1 and r["Status"] == "OutOfStock"


def test_fractional_on_hand_is_in_stock_and_on_order_subtracted():
    con = _con()
    _part(con, "F1", oh=0.5)
    _part(con, "F2", oo=1.9)
    _minimum_with_demand(con, "F1", 3)
    _minimum_with_demand(con, "F2", 3)
    r = _run(con)
    assert r[K("F1")]["RecommendedOrderQty"] == 3 and r[K("F1")]["Status"] == "Reorder"
    assert r[K("F2")]["RecommendedOrderQty"] == 2 and r[K("F2")]["Status"] == "OutOfStock"


def test_negative_on_hand_truncates_toward_zero():
    con = _con()
    _part(con, "N1", oh=-1.5)
    _part(con, "N2", oh=-0.5)
    _minimum_with_demand(con, "N1", 1)
    _minimum_with_demand(con, "N2", 1)
    r = _run(con)
    assert r[K("N1")]["RecommendedOrderQty"] == 2
    assert r[K("N2")]["RecommendedOrderQty"] == 1
    assert r[K("N1")]["SurplusQty"] == 0


def test_inbound_transfers_match_trimmed_upper_part_number():
    con = _con()
    _part(con, "ab-1 ")
    con.execute("""INSERT INTO transfers VALUES ('1','AB-1',4), ('1 ','AB-1',2), ('1',' ab-1 ',1),
                   ('5','AB-1',9)""")
    r = _run(con)
    assert r[K("ab-1 ")]["InboundTransferQty"] == pytest.approx(7.0)    # both sides trimmed and upper-cased


def test_no_transfers_is_zero_inbound():
    con = _con()
    _part(con, "X1")
    assert _run(con)[K("X1")]["InboundTransferQty"] == 0


# ---------------------------------------------------------------------------------------------------------
# compare()
# ---------------------------------------------------------------------------------------------------------
CMP_COLS = [("Branch", "VARCHAR"), ("Franchise", "VARCHAR"), ("PartNumber", "VARCHAR"), ("RuleId", "BIGINT"),
            ("RuleName", "VARCHAR"), ("DemandBasis", "VARCHAR"), ("HistoryMonths", "INTEGER"),
            ("MinActiveMonths", "INTEGER"), ("WeeksOfCover", "DOUBLE"), ("WindowDemand", "DOUBLE"),
            ("ActiveMonths", "INTEGER"), ("MonthlyRate", "DOUBLE"), ("CalcTarget", "INTEGER"),
            ("EffectiveMin", "DOUBLE"), ("MinimumIgnored", "BOOLEAN"), ("StockingTarget", "INTEGER"), ("RecommendedOrderQty", "INTEGER"),
            ("SurplusQty", "INTEGER"), ("InboundTransferQty", "DOUBLE"), ("Status", "VARCHAR")]
BASE = dict(Branch="1", Franchise="MC", PartNumber="A", RuleId=1, RuleName="Default", DemandBasis="UnitsSold",
            HistoryMonths=12, MinActiveMonths=3, WeeksOfCover=6.0, WindowDemand=3.0, ActiveMonths=2,
            MonthlyRate=0.25, CalcTarget=1, EffectiveMin=0.0, MinimumIgnored=False, StockingTarget=2, RecommendedOrderQty=1, SurplusQty=0,
            InboundTransferQty=0.0, Status="Reorder")


def test_compare_covers_every_output_column():
    assert {c for c, _ in CMP_COLS} == set(chk.OUTPUT_COLS)
    assert set(chk.COMPARE_COLS) | set(chk.TOLERANCE_COLS) == set(chk.OUTPUT_COLS) - {"Branch", "Franchise",
                                                                                       "PartNumber"}


def _cmp(gold_rows, exp_rows):
    con = duckdb.connect()
    ddl = ", ".join(f"{c} {t}" for c, t in CMP_COLS)
    marks = ", ".join("?" for _ in CMP_COLS)
    for name, rows in (("gold", gold_rows), ("expected", exp_rows)):
        con.execute(f"CREATE TABLE {name} ({ddl})")
        for row in rows:
            con.execute(f"INSERT INTO {name} VALUES ({marks})", [{**BASE, **row}[c] for c, _ in CMP_COLS])
    return chk.compare(con, "gold", "expected")


def test_compare_identical():
    assert _cmp([{}], [{}]) == {"only_gold": 0, "only_expected": 0, "different": 0, "dup_gold": 0, "dup_expected": 0}


def test_compare_counts_missing_keys():
    r = _cmp([{}, {"PartNumber": "B"}], [{}, {"PartNumber": "C"}])
    assert r == {"only_gold": 1, "only_expected": 1, "different": 0, "dup_gold": 0, "dup_expected": 0}


def test_compare_flags_duplicate_keys():
    r = _cmp([{}, {}], [{}])
    assert r["dup_gold"] == 1 and r["dup_expected"] == 0


@pytest.mark.parametrize("col,value", [
    ("RuleId", 2), ("RuleId", None), ("RuleName", "Cotton"), ("RuleName", None),
    ("DemandBasis", "Requests"), ("HistoryMonths", 6), ("MinActiveMonths", 0),
    ("ActiveMonths", 3), ("CalcTarget", 2), ("CalcTarget", None),
    ("StockingTarget", 3), ("StockingTarget", None), ("RecommendedOrderQty", 0), ("SurplusQty", 1),
    ("Status", "OK"),
    ("WeeksOfCover", 6.5), ("WeeksOfCover", None), ("WindowDemand", 3.01), ("WindowDemand", None),
    ("MonthlyRate", 0.2501), ("MonthlyRate", None), ("EffectiveMin", 1.0), ("EffectiveMin", None),
    ("MinimumIgnored", True), ("MinimumIgnored", None),
    ("InboundTransferQty", 0.5), ("InboundTransferQty", None),
])
def test_compare_flags_each_compared_column(col, value):
    r = _cmp([{}], [{col: value}])
    assert (r["only_gold"], r["only_expected"], r["different"]) == (0, 0, 1)


@pytest.mark.parametrize("col", ["WeeksOfCover", "WindowDemand", "MonthlyRate", "EffectiveMin",
                                 "InboundTransferQty"])
def test_compare_tolerates_tiny_float_differences(col):
    r = _cmp([{}], [{col: BASE[col] + 1e-9}])
    assert r["different"] == 0
