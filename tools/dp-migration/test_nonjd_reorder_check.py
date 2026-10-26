# tools/dp-migration/test_nonjd_reorder_check.py
"""Tests for the reference reorder rules (Plan C round 1: docs/superpowers/plans/2026-10-26-non-jd-parts-order-tool-
round-1.md, "The calculation", "Validation" and decisions D13/D14) and compare()."""
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
                   QuantityOnHand DECIMAL(12,2), OnOrder DECIMAL(12,2), Cost DECIMAL(12,2), DealerGroupCode VARCHAR,
                   DateLastRequested TIMESTAMP)""")
    con.execute("CREATE TABLE rules (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MinimumQty DECIMAL(10,2))")
    con.execute("""CREATE TABLE hist (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MonthStart DATE,
                   SalesQty DECIMAL(12,2), RequestCount INTEGER)""")
    con.execute("""CREATE TABLE order_rules (Id BIGINT, RuleName VARCHAR, Priority DOUBLE, Active BOOLEAN,
                   Franchise VARCHAR, DealerGroupCode VARCHAR, Branch VARCHAR, StartMonth DOUBLE, EndMonth DOUBLE,
                   HistoryMonths DOUBLE, MinActiveMonths DOUBLE, WeeksOfCover DOUBLE, DemandBasis VARCHAR,
                   MinDemands DOUBLE, SupplyUnit VARCHAR, MinLineValue DOUBLE, MaxLineValue DOUBLE, Archived BOOLEAN,
                   Modified TIMESTAMP)""")
    con.execute("""CREATE TABLE settings (Id INTEGER, Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   MinOverride DOUBLE, Masked BOOLEAN, MaskExpires DATE, ManualOrder BOOLEAN, MaskedOn DATE,
                   Modified TIMESTAMP)""")
    con.execute("CREATE TABLE transfers (RequestingBranch VARCHAR, PartNumber VARCHAR, OpenQty DOUBLE)")
    return con


def _part(con, pn, oh=0, oo=0, cost=10, branch="1", franchise="MC", dgc=None, last_req=None):
    con.execute("INSERT INTO parts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [branch, franchise, pn, oh, oo, cost, dgc, last_req])


def _hist(con, pn, months, branch="1", franchise="MC"):
    """months: {MonthStart (date or 'YYYY-MM-DD'): (SalesQty, RequestCount)}"""
    for m, (sales, reqs) in months.items():
        con.execute("INSERT INTO hist VALUES (?, ?, ?, ?, ?, ?)", [branch, franchise, pn, m, sales, reqs])


def _rule(con, rid, name=None, priority=0, active=True, franchise=None, dgc=None, branch=None, start=None,
          end=None, hm=12, md=3, woc=6, basis="UnitsSold", unit=None, minlv=None, maxlv=None, archived=None,
          mam=None):
    con.execute("""INSERT INTO order_rules (Id, RuleName, Priority, Active, Franchise, DealerGroupCode, Branch,
                       StartMonth, EndMonth, HistoryMonths, MinActiveMonths, WeeksOfCover, DemandBasis, MinDemands,
                       SupplyUnit, MinLineValue, MaxLineValue, Archived, Modified)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, TIMESTAMP '2026-10-01')""",
                [rid, name or f"R{rid}", priority, active, franchise, dgc, branch, start, end, hm, mam, woc, basis,
                 md, unit, minlv, maxlv, archived])


def _setting(con, pn, sid=1, min_override=None, masked=False, expires=None, manual=None, masked_on=None,
             modified="2026-10-01 10:00", branch="1", franchise="MC"):
    con.execute("INSERT INTO settings VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [sid, branch, franchise, pn, min_override, masked, expires, manual, masked_on, modified])


def _minimum(con, pn, qty, branch="1", franchise="MC"):
    con.execute("INSERT INTO rules VALUES (?, ?, ?, ?)", [branch, franchise, pn, qty])


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
    """One catch-all rule that stocks on any demand: 12 months, 0 demands needed, 52 weeks of supply
    (so CalcTarget = ceil(WindowDemand))."""
    _rule(con, 1, "Simple", **{"md": 0, "woc": 52, **kw})


def _stocked(con, pn, target, oh=0, oo=0, cost=10, **rule_kw):
    """A part whose CalcTarget is `target` under _simple_rule (target units sold, 1 request, last month);
    rule_kw goes to _simple_rule."""
    _part(con, pn, oh=oh, oo=oo, cost=cost)
    _hist(con, pn, {"2026-09-01": (target, 1)})
    _simple_rule(con, **rule_kw)
    assert chk.invalid_rules(con) == []


# ---------------------------------------------------------------------------------------------------------
# output shape and scope
# ---------------------------------------------------------------------------------------------------------
def test_output_columns():
    con = _con()
    cur_ = chk.expected_reorder(con, CUR, TODAY)
    assert [d[0] for d in cur_.description] == [
        "Branch", "Franchise", "PartNumber", "RuleId", "RuleName", "DemandBasis", "HistoryMonths",
        "MinDemands", "SupplyUnit", "Supply", "SupplyMonths", "MinLineValue", "MaxLineValue",
        "WindowDemand", "UnitsSoldWindow", "DemandCount", "ActiveMonths", "MonthlyRate", "CalcTarget", "EffectiveMin",
        "MinimumNoDemand", "StockingTarget", "ValueCapped", "BelowMinValue", "ManualOrder", "MaskedOn",
        "IsMasked", "RecommendedOrderQty", "SurplusQty", "InboundTransferQty", "Status"]


def test_scope_excludes_jd_test_franchises_and_zero_cost():
    con = _con()
    for pn, fr, cost in [("JD1", "D", 5), ("T1", "TD", 5), ("U1", "UM", 5), ("Z1", "ZP", 5), ("S1", "S", 5),
                         ("N95", "95", 5), ("FREE", "MC", 0), ("OK1", "MC", 5), ("DA1", "DA", 5)]:
        _part(con, pn, franchise=fr, cost=cost)
    assert sorted(_run(con)) == [K("DA1", franchise="DA"), K("OK1")]


def test_excluded_branches_trimmed_and_case_insensitive():
    con = _con()
    for b in ["12", "5", "97", "4B", "93C", " 4b", "93c ", " 12 ",      # left out (D6)
              "1", "4", "93", "92", "120", "95"]:                     # kept
        _part(con, "P1", branch=b)
    assert sorted(k[0] for k in _run(con)) == sorted(["1", "4", "93", "92", "120", "95"])


def test_excluded_branch_list():
    assert chk.EXCLUDED_BRANCHES == ["12", "5", "97", "4B", "93C"]


# ---------------------------------------------------------------------------------------------------------
# rule selection
# ---------------------------------------------------------------------------------------------------------
def test_builtin_default_when_no_rules():
    con = _con()
    _part(con, "P1")
    r = _run(con)[K("P1")]
    assert r["RuleId"] is None and r["RuleName"] == "Built-in default"
    assert (r["HistoryMonths"], r["MinDemands"], r["Supply"], r["SupplyUnit"], r["DemandBasis"]) == \
        (12, 3, 12, "Weeks", "UnitsSold")
    assert r["SupplyMonths"] == pytest.approx(12 * 12 / 52)
    assert r["MinLineValue"] is None and r["MaxLineValue"] is None


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
    assert (r["RuleId"], r["RuleName"], r["Supply"]) == (2, "High", 10)


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


def test_archived_rule_ignored_and_not_reported():
    con = _con()
    _part(con, "P1")
    _rule(con, 1, priority=0, archived=None)                 # NULL = not archived
    _rule(con, 2, priority=5, archived=False)
    _rule(con, 3, priority=10, archived=True)                # valid but archived: never matched
    _rule(con, 4, priority=20, archived=True, basis="X", md=None)   # invalid and archived: not reported
    assert _run(con)[K("P1")]["RuleId"] == 2
    assert chk.invalid_rules(con) == []


def test_archived_rules_alone_give_builtin_default():
    con = _con()
    _part(con, "P1")
    _rule(con, 1, archived=True)
    assert _run(con)[K("P1")]["RuleName"] == "Built-in default"


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
    _rule(con, 2, "Cotton - in season", priority=10, dgc="COTTON", start=6, end=10, md=2)
    _rule(con, 3, "Cotton - off season", priority=10, dgc="COTTON", start=11, end=5)
    assert _run(con, cur=cur, today=cur)[K("P1")]["RuleId"] == expected


# ---------------------------------------------------------------------------------------------------------
# invalid rules
# ---------------------------------------------------------------------------------------------------------
MONTHS_BOTH = "StartMonth and EndMonth must both be set or both blank"
START_1_12 = "StartMonth must be a whole number 1-12"
HM = "HistoryMonths must be a whole number 1-59"
MD = "MinDemands must be a whole number 0-9999"
WEEKS = "Supply must be 0-104 weeks"
MONTHS = "Supply must be 0-24 months"
UNIT = "SupplyUnit must be Weeks or Months"
MINLV = "MinLineValue must be 0 or more"
MAXLV = "MaxLineValue must be 0 or more"
MIN_GT_MAX = "MinLineValue must not be more than MaxLineValue"
BASIS = "DemandBasis must be UnitsSold or Requests"
INVALID = {
    "start month only": (dict(start=6), MONTHS_BOTH),
    "end month only": (dict(end=10), MONTHS_BOTH),
    "month 13": (dict(start=6, end=13), "EndMonth must be a whole number 1-12"),
    "month 0": (dict(start=0, end=5), START_1_12),
    "fractional month": (dict(start=2.5, end=5), START_1_12),
    "missing Supply": (dict(woc=None), "Supply is missing"),
    "missing Supply, months": (dict(woc=None, unit="Months"), "Supply is missing"),
    "negative weeks": (dict(woc=-1), WEEKS),
    "105 weeks": (dict(woc=105), WEEKS),
    "105 weeks, unit Weeks": (dict(woc=105, unit="Weeks"), WEEKS),
    "105 weeks, unit blank": (dict(woc=105, unit="  "), WEEKS),
    "infinite weeks": (dict(woc=float("inf")), WEEKS),
    "NaN weeks": (dict(woc=float("nan")), WEEKS),
    "25 months": (dict(woc=25, unit="Months"), MONTHS),
    "negative months": (dict(woc=-0.5, unit="months"), MONTHS),
    "NaN months": (dict(woc=float("nan"), unit="Months"), MONTHS),
    "unknown unit": (dict(unit="Days"), UNIT),
    "unknown unit, supply out of range": (dict(unit="Days", woc=500), UNIT),
    "missing HistoryMonths": (dict(hm=None), "HistoryMonths is missing"),
    "HistoryMonths 0": (dict(hm=0), HM),
    "HistoryMonths 60": (dict(hm=60), HM),
    "fractional HistoryMonths": (dict(hm=6.5), HM),
    "NaN HistoryMonths": (dict(hm=float("nan")), HM),
    "missing MinDemands": (dict(md=None), "MinDemands is missing"),
    "negative MinDemands": (dict(md=-1), MD),
    "MinDemands 10000": (dict(md=10000), MD),
    "fractional MinDemands": (dict(md=1.5), MD),
    "NaN MinDemands": (dict(md=float("nan")), MD),
    "infinite MinDemands": (dict(md=float("inf")), MD),
    "negative MinLineValue": (dict(minlv=-0.01), MINLV),
    "NaN MinLineValue": (dict(minlv=float("nan")), MINLV),
    "infinite MinLineValue": (dict(minlv=float("inf")), MINLV),
    "negative MaxLineValue": (dict(maxlv=-5), MAXLV),
    "NaN MaxLineValue": (dict(maxlv=float("nan")), MAXLV),
    "MinLineValue above MaxLineValue": (dict(minlv=50, maxlv=49.99), MIN_GT_MAX),
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


VALID = {
    "0 weeks": dict(woc=0), "104 weeks": dict(woc=104), "104 weeks, unit Weeks": dict(woc=104, unit="Weeks"),
    "fractional weeks": dict(woc=5.2), "0 months": dict(woc=0, unit="Months"),
    "24 months": dict(woc=24, unit="Months"), "unit trimmed, any case": dict(woc=24, unit=" mONths "),
    "unit empty": dict(unit=""), "MinDemands 0": dict(md=0), "MinDemands 9999": dict(md=9999),
    "line values 0": dict(minlv=0, maxlv=0), "MinLineValue only": dict(minlv=25),
    "MaxLineValue only": dict(maxlv=500), "MinLineValue equals MaxLineValue": dict(minlv=100, maxlv=100),
    # MinActiveMonths is left in the list unused (D1): no longer validated
    "MinActiveMonths missing": dict(mam=None), "MinActiveMonths out of range": dict(mam=-3.5),
}


@pytest.mark.parametrize("kw", VALID.values(), ids=VALID.keys())
def test_valid_rule_settings(kw):
    con = _con()
    _rule(con, 1, **kw)
    assert chk.invalid_rules(con) == []


def test_null_min_demands_makes_every_rule_invalid_and_builtin_default_applies():
    # Today's Dev list has no MinDemands column yet, so every list rule reads NULL there
    con = _con()
    _part(con, "P1")
    _rule(con, 1, "Default", md=None)
    _rule(con, 2, "Cotton", md=None, dgc="COTTON")
    assert _run(con)[K("P1")]["RuleName"] == "Built-in default"
    assert chk.invalid_rules(con) == [(1, "Default", "MinDemands is missing"), (2, "Cotton", "MinDemands is missing")]


@pytest.mark.parametrize("name", [None, "", "   "])
def test_missing_rule_name_falls_back_to_rule_id(name):
    con = _con()
    _part(con, "P1")
    _rule(con, 7)
    _rule(con, 8, active=True, basis="X")
    con.execute("UPDATE order_rules SET RuleName = ?", [name])
    assert _run(con)[K("P1")]["RuleName"] == "Rule 7"
    assert chk.invalid_rules(con) == [(8, "Rule 8", BASIS)]


def test_invalid_rules_lists_every_problem_and_ignores_valid_inactive_and_archived_rules():
    con = _con()
    _rule(con, 1, "Good", start=11, end=2, hm=59, md=0, woc=0, basis=" requests ")
    _rule(con, 2, "Off", active=False, start=13)
    _rule(con, 3, "Two problems", start=6, basis="X")
    _rule(con, 4, "Many problems", md=None, woc=30, unit="Months", minlv=-1, maxlv=-2)
    _rule(con, 5, "Archived", archived=True, start=13)
    bad = chk.invalid_rules(con)
    assert [(i, n) for i, n, _ in bad] == [(3, "Two problems"), (4, "Many problems")]
    assert "StartMonth" in bad[0][2] and "DemandBasis" in bad[0][2]
    assert bad[1][2] == "; ".join(["MinDemands is missing", MONTHS, MINLV, MAXLV])


def test_min_above_max_only_checked_when_both_are_valid():
    con = _con()
    _rule(con, 1, "Bad", minlv=-1, maxlv=-5)
    assert chk.invalid_rules(con) == [(1, "Bad", f"{MINLV}; {MAXLV}")]


def test_demand_basis_trimmed_and_case_insensitive():
    con = _con()
    _part(con, "P1")
    _rule(con, 1, basis=" requests ")
    r = _run(con)[K("P1")]
    assert r["RuleId"] == 1 and r["DemandBasis"] == "Requests"


def test_rule_settings_are_output():
    con = _con()
    _part(con, "P1")
    _rule(con, 1, md=4, woc=2, unit=" months", minlv=25, maxlv=500)
    r = _run(con)[K("P1")]
    assert (r["MinDemands"], r["Supply"], r["SupplyUnit"], r["SupplyMonths"]) == (4, 2, "Months", 2)
    assert (r["MinLineValue"], r["MaxLineValue"]) == (25, 500)


# ---------------------------------------------------------------------------------------------------------
# demand window, demand count and calculation
# ---------------------------------------------------------------------------------------------------------
def test_window_is_full_months_only():
    con = _con()
    _part(con, "W1")
    _hist(con, "W1", {"2026-10-01": (100, 50),    # current partial month: excluded
                      "2026-09-01": (1, 1),       # current - 1: included
                      "2025-10-01": (2, 2),       # current - 12: included
                      "2025-09-01": (400, 70),    # current - 13: excluded
                      "2026-11-01": (800, 90)})   # future: excluded
    _simple_rule(con)
    r = _run(con)[K("W1")]
    assert r["WindowDemand"] == pytest.approx(3.0) and r["ActiveMonths"] == 2 and r["DemandCount"] == 3


def test_window_follows_rule_history_months():
    con = _con()
    _part(con, "W3")
    _hist(con, "W3", {"2026-09-01": (1, 1), "2026-07-01": (2, 4), "2026-06-01": (4, 8)})
    _simple_rule(con, hm=3)
    r = _run(con)[K("W3")]
    assert r["HistoryMonths"] == 3
    assert r["WindowDemand"] == pytest.approx(3.0) and r["ActiveMonths"] == 2 and r["DemandCount"] == 5
    assert r["MonthlyRate"] == pytest.approx(1.0)


def test_negative_window_demand_is_zero_and_only_positive_months_are_active():
    con = _con()
    _part(con, "NEG")
    _hist(con, "NEG", {"2026-09-01": (2, 1), "2026-08-01": (-5, 1), "2026-07-01": (0, 3)})
    _simple_rule(con)
    r = _run(con)[K("NEG")]
    assert r["WindowDemand"] == 0 and r["ActiveMonths"] == 1 and r["DemandCount"] == 5
    assert r["MonthlyRate"] == 0 and r["CalcTarget"] == 0
    assert r["Status"] == "NotStocked"


def test_window_demand_rounds_away_summation_noise():
    con = _con()
    _part(con, "RN")
    con.execute("ALTER TABLE hist ALTER SalesQty TYPE DOUBLE")
    _hist(con, "RN", {"2026-09-01": (0.1, 1), "2026-08-01": (0.2, 1), "2026-07-01": (-0.3, 1)})
    _simple_rule(con)
    r = _run(con)[K("RN")]
    assert r["WindowDemand"] == 0 and r["CalcTarget"] == 0


def test_null_demand_counts_as_zero():
    con = _con()
    _part(con, "NUL")
    _hist(con, "NUL", {"2026-09-01": (None, None), "2026-08-01": (3, None), "2026-07-01": (None, 2)})
    _simple_rule(con)
    r = _run(con)[K("NUL")]
    assert r["WindowDemand"] == pytest.approx(3.0) and r["ActiveMonths"] == 1 and r["DemandCount"] == 2


def test_demand_count_is_request_count_whatever_the_basis():
    con = _con()
    _part(con, "US")
    _part(con, "RQ", dgc="R")
    for pn in ("US", "RQ"):
        _hist(con, pn, {"2026-09-01": (1, 12), "2026-08-01": (0, 3)})
    _simple_rule(con)
    _rule(con, 2, "Requests", priority=5, dgc="R", md=0, woc=52, basis="Requests")
    r = _run(con)
    assert (r[K("US")]["WindowDemand"], r[K("US")]["ActiveMonths"], r[K("US")]["DemandCount"]) == (1, 1, 15)
    assert (r[K("RQ")]["WindowDemand"], r[K("RQ")]["ActiveMonths"], r[K("RQ")]["DemandCount"]) == (15, 2, 15)
    assert r[K("RQ")]["DemandBasis"] == "Requests"


def test_negative_request_sum_is_zero_demands():
    con = _con()
    _part(con, "NR")
    _hist(con, "NR", {"2026-09-01": (5, -4), "2026-08-01": (1, 1)})
    _simple_rule(con)
    r = _run(con)[K("NR")]
    assert r["DemandCount"] == 0 and r["WindowDemand"] == pytest.approx(6.0)
    # DemandCount 0 meets MinDemands 0, so the units still set the target
    assert (r["CalcTarget"], r["RecommendedOrderQty"], r["Status"]) == (6, 6, "OutOfStock")


def test_negative_request_sum_below_min_demands():
    con = _con()
    _part(con, "NR3")
    _hist(con, "NR3", {"2026-09-01": (5, -4), "2026-08-01": (5, 6)})
    r = _run(con)[K("NR3")]                                 # 2 demands < 3
    assert (r["DemandCount"], r["CalcTarget"], r["Status"]) == (2, 0, "NotStocked")


def test_monthly_rate_uses_history_months():
    con = _con()
    _part(con, "ONE")
    _hist(con, "ONE", {"2026-05-01": (6, 1)})
    _rule(con, 1, md=1, woc=6)
    r = _run(con)[K("ONE")]
    assert r["MonthlyRate"] == pytest.approx(0.5)          # 6 / 12, not 6 / 1
    assert r["CalcTarget"] == 1                             # ceil(0.5 * 6 * 12 / 52 = 0.69)


@pytest.mark.parametrize("requests,stocked", [(2, False), (3, True), (4, True)])
def test_min_demands_boundary(requests, stocked):
    # the built-in default: 3 demands in 12 months
    con = _con()
    _part(con, "MD")
    _hist(con, "MD", {"2026-09-01": (12, requests)})
    r = _run(con)[K("MD")]
    assert r["DemandCount"] == requests
    assert r["CalcTarget"] == (3 if stocked else 0)        # ceil(1 a month x 12 weeks x 12/52 = 2.77)
    assert r["Status"] == ("OutOfStock" if stocked else "NotStocked")


def test_demands_in_one_month_are_enough():
    # 3 transactions in a single month meets 3 demands; the old rule needed 3 active months
    con = _con()
    _part(con, "ONEMO")
    _hist(con, "ONEMO", {"2026-03-01": (6, 3)})
    r = _run(con)[K("ONEMO")]
    assert (r["ActiveMonths"], r["DemandCount"], r["CalcTarget"]) == (1, 3, 2)


def test_many_active_months_without_requests_not_stocked():
    con = _con()
    _part(con, "NOREQ")
    _hist(con, "NOREQ", {"2026-09-01": (5, 0), "2026-08-01": (5, 0), "2026-07-01": (5, 0), "2026-06-01": (5, 0)})
    r = _run(con)[K("NOREQ")]
    assert (r["ActiveMonths"], r["DemandCount"], r["CalcTarget"], r["StockingTarget"]) == (4, 0, 0, 0)
    assert r["UnitsSoldWindow"] == pytest.approx(20.0)
    assert r["Status"] == "NotStocked"                     # units sold count as activity (D14)


def test_min_demands_zero_with_no_demand_gives_zero():
    con = _con()
    _part(con, "Z")
    _simple_rule(con)
    r = _run(con)[K("Z")]
    assert (r["DemandCount"], r["CalcTarget"], r["Status"]) == (0, 0, "NoRecentActivity")


@pytest.mark.parametrize("unit,supply,months,target", [
    ("Weeks", 3, 3 * 12 / 52, 1),        # 1 a month x 0.69 months -> 1
    (None, 3, 3 * 12 / 52, 1),           # blank = Weeks
    ("  ", 3, 3 * 12 / 52, 1),
    ("weeks", 52, 12, 12),
    ("Months", 3, 3, 3),                  # 1 a month x 3 months
    (" MONTHS ", 2.5, 2.5, 3),
    ("Months", 0, 0, 0),
])
def test_supply_unit(unit, supply, months, target):
    con = _con()
    _part(con, "SU")
    _hist(con, "SU", {"2026-09-01": (12, 5)})
    _rule(con, 1, woc=supply, unit=unit)
    r = _run(con)[K("SU")]
    assert r["SupplyUnit"] == ("Months" if unit and unit.strip().lower() == "months" else "Weeks")
    assert r["Supply"] == supply and r["SupplyMonths"] == pytest.approx(months)
    assert r["CalcTarget"] == target


def test_calc_target_formula_and_order():
    # spec worked example: sold 18 in 12 months (1.5 a month) x 10 weeks of supply -> target 4; on hand 1 -> order 3
    con = _con()
    _part(con, "COT", oh=1, dgc="COTTON")
    _hist(con, "COT", {"2026-09-01": (6, 1), "2026-08-01": (6, 1), "2026-07-01": (6, 1)})
    _rule(con, 1, "Cotton - in season", dgc="COTTON", start=6, end=10, hm=12, md=2, woc=10)
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
    _hist(con, "FP", {"2026-09-01": (5, 1)})
    _rule(con, 1, hm=3, md=1, woc=5.2)
    assert _run(con)[K("FP")]["CalcTarget"] == 2


def test_default_rule_calculation():
    con = _con()
    _part(con, "D1")
    # 26 units, 3 demands over 12 months -> 26/12 a month x 12 weeks -> exactly 6
    _hist(con, "D1", {"2026-09-01": (10, 1), "2026-04-01": (10, 1), "2025-11-01": (6, 1)})
    r = _run(con)[K("D1")]
    assert r["DemandCount"] == 3 and r["CalcTarget"] == 6 and r["StockingTarget"] == 6
    assert r["Status"] == "OutOfStock"


def test_below_min_demands_calc_zero_but_minimum_sets_target():
    con = _con()
    _part(con, "BM", oh=1)
    _minimum(con, "BM", 4)
    _hist(con, "BM", {"2026-09-01": (50, 1), "2026-08-01": (50, 1)})
    r = _run(con)[K("BM")]                                     # built-in default needs 3 demands
    assert r["DemandCount"] == 2 and r["CalcTarget"] == 0
    assert r["EffectiveMin"] == pytest.approx(4.0) and r["StockingTarget"] == 4
    assert r["RecommendedOrderQty"] == 3 and r["Status"] == "Reorder"


def test_target_is_larger_of_calc_and_minimum():
    con = _con()
    _part(con, "BIG")
    _part(con, "SMALL")
    _minimum(con, "BIG", 2)
    _minimum(con, "SMALL", 9)
    for pn in ("BIG", "SMALL"):
        _hist(con, pn, {"2026-09-01": (5, 1)})
    _simple_rule(con)
    r = _run(con)
    assert (r[K("BIG")]["CalcTarget"], r[K("BIG")]["StockingTarget"]) == (5, 5)
    assert (r[K("SMALL")]["CalcTarget"], r[K("SMALL")]["StockingTarget"]) == (5, 9)


def test_fractional_minimum_rounds_up():
    con = _con()
    _part(con, "FM")
    _minimum(con, "FM", 2.5)
    r = _run(con)[K("FM")]
    assert r["EffectiveMin"] == pytest.approx(2.5) and r["StockingTarget"] == 3


def test_min_override_beats_equip_minimum_latest_settings_row_wins():
    con = _con()
    _part(con, "P3")
    _minimum(con, "P3", 4)
    _setting(con, "P3", sid=1, min_override=2, modified="2026-10-01 10:00")
    _setting(con, "P3", sid=2, min_override=7, modified="2026-10-05 10:00")
    r = _run(con)[K("P3")]
    assert r["EffectiveMin"] == pytest.approx(7.0) and r["StockingTarget"] == 7


# ---------------------------------------------------------------------------------------------------------
# Equip minimum always applies (D4) and MinimumNoDemand
# ---------------------------------------------------------------------------------------------------------
def test_equip_minimum_applies_without_demand():
    con = _con()
    _part(con, "STALE", oh=0)
    _minimum(con, "STALE", 4)
    r = _run(con)[K("STALE")]
    assert r["DemandCount"] == 0 and r["MinimumNoDemand"] is True
    assert (r["EffectiveMin"], r["StockingTarget"], r["RecommendedOrderQty"]) == (4, 4, 4)
    assert r["Status"] == "OutOfStock"


def test_equip_minimum_with_demand_below_min_demands_is_not_flagged():
    con = _con()
    _part(con, "LIVE", oh=0)
    _minimum(con, "LIVE", 4)
    _hist(con, "LIVE", {"2026-09-01": (1, 1)})            # 1 demand < 3: CalcTarget 0
    r = _run(con)[K("LIVE")]
    assert (r["DemandCount"], r["CalcTarget"], r["MinimumNoDemand"]) == (1, 0, False)
    assert r["EffectiveMin"] == pytest.approx(4.0) and r["StockingTarget"] == 4
    assert r["RecommendedOrderQty"] == 4 and r["Status"] == "OutOfStock"


def test_units_sold_without_requests_is_activity():
    # units sold but RequestCount 0: not "no activity", so the minimum is not flagged for cleanup (D14)
    con = _con()
    _part(con, "U", oh=5)
    _minimum(con, "U", 4)
    _hist(con, "U", {"2026-09-01": (3, 0)})
    r = _run(con)[K("U")]
    assert (r["ActiveMonths"], r["DemandCount"], r["UnitsSoldWindow"], r["MinimumNoDemand"]) == (1, 0, 3, False)
    assert r["StockingTarget"] == 4 and r["Status"] == "OK"


def test_units_sold_without_requests_and_no_minimum_is_not_stocked():
    con = _con()
    _part(con, "U2")
    _hist(con, "U2", {"2026-09-01": (3, 0)})
    r = _run(con)[K("U2")]
    assert (r["DemandCount"], r["UnitsSoldWindow"], r["CalcTarget"], r["Status"]) == (0, 3, 0, "NotStocked")


def test_requests_without_units_is_activity():
    con = _con()
    _part(con, "R0")
    _minimum(con, "R0", 2)
    _part(con, "R1")
    for pn in ("R0", "R1"):
        _hist(con, pn, {"2026-09-01": (0, 1)})
    r = _run(con)
    assert (r[K("R0")]["UnitsSoldWindow"], r[K("R0")]["DemandCount"], r[K("R0")]["MinimumNoDemand"]) == (0, 1, False)
    assert r[K("R1")]["Status"] == "NotStocked"


@pytest.mark.parametrize("units,no_activity", [
    ({"2026-09-01": (5, 0), "2026-08-01": (-5, 0)}, True),     # nets to 0 units, no requests: no activity
    ({"2026-09-01": (2, 0), "2026-08-01": (-5, 0)}, True),     # negative net counts as 0
    ({"2026-09-01": (0, 0)}, True),
    ({"2026-09-01": (0.5, 0)}, False),
])
def test_no_activity_uses_net_units_sold(units, no_activity):
    con = _con()
    _part(con, "NA")
    _minimum(con, "NA", 1)
    _hist(con, "NA", units)
    r = _run(con)[K("NA")]
    assert r["MinimumNoDemand"] is no_activity
    assert (r["UnitsSoldWindow"] == 0) is no_activity


def test_no_activity_status_with_target_zero():
    con = _con()
    _part(con, "NAS")
    _hist(con, "NAS", {"2026-09-01": (5, 0), "2026-08-01": (-5, 0)})
    assert _run(con)[K("NAS")]["Status"] == "NoRecentActivity"


def test_units_sold_window_ignores_basis_and_months_outside_the_window():
    con = _con()
    _part(con, "RQB")
    _hist(con, "RQB", {"2026-10-01": (100, 100),              # current partial month: excluded
                       "2026-09-01": (2, 7), "2026-08-01": (1.5, 1),
                       "2025-09-01": (400, 400)})             # outside 12 months
    _rule(con, 1, basis="Requests", md=0, woc=52)
    r = _run(con)[K("RQB")]
    assert (r["WindowDemand"], r["UnitsSoldWindow"], r["DemandCount"]) == (8, 3.5, 8)


def test_units_sold_window_follows_history_months():
    con = _con()
    _part(con, "HM3")
    _hist(con, "HM3", {"2026-09-01": (2, 0), "2026-05-01": (9, 0)})
    _rule(con, 1, hm=3)
    assert _run(con)[K("HM3")]["UnitsSoldWindow"] == 2


def test_demand_only_outside_the_rule_window_counts_as_no_demand():
    con = _con()
    _part(con, "OLD")
    _minimum(con, "OLD", 4)
    _hist(con, "OLD", {"2026-10-01": (5, 5),              # current partial month
                       "2025-09-01": (5, 5)})             # current - 13, outside the default 12 months
    r = _run(con)[K("OLD")]
    assert r["DemandCount"] == 0 and r["MinimumNoDemand"] is True
    assert r["EffectiveMin"] == 4 and r["StockingTarget"] == 4


def test_min_override_applies_without_demand_and_is_not_flagged():
    con = _con()
    _part(con, "OVR")
    _minimum(con, "OVR", 4)
    _setting(con, "OVR", min_override=2)
    r = _run(con)[K("OVR")]
    assert r["DemandCount"] == 0 and r["MinimumNoDemand"] is False
    assert r["EffectiveMin"] == pytest.approx(2.0) and r["StockingTarget"] == 2
    assert r["RecommendedOrderQty"] == 2 and r["Status"] == "OutOfStock"


def test_min_override_zero_beats_equip_minimum():
    con = _con()
    _part(con, "OV0")
    _minimum(con, "OV0", 4)
    _setting(con, "OV0", min_override=0)
    r = _run(con)[K("OV0")]
    assert (r["EffectiveMin"], r["StockingTarget"], r["MinimumNoDemand"]) == (0, 0, False)


@pytest.mark.parametrize("qty", [0, None])
def test_zero_or_missing_equip_minimum_is_not_flagged(qty):
    con = _con()
    _part(con, "Z")
    _part(con, "NOROW")
    _minimum(con, "Z", qty)
    r = _run(con)
    assert r[K("Z")]["MinimumNoDemand"] is False and r[K("NOROW")]["MinimumNoDemand"] is False
    assert r[K("Z")]["EffectiveMin"] == 0 and r[K("NOROW")]["EffectiveMin"] == 0


def test_settings_tie_on_modified_breaks_by_id_desc():
    con = _con()
    _part(con, "S1")
    _setting(con, "S1", sid=9, min_override=6, modified="2026-10-05 10:00")
    _setting(con, "S1", sid=3, min_override=2, modified="2026-10-05 10:00")
    assert _run(con)[K("S1")]["StockingTarget"] == 6


# ---------------------------------------------------------------------------------------------------------
# target 0 means order 0 (D5), quantities, surplus
# ---------------------------------------------------------------------------------------------------------
@pytest.mark.parametrize("oh,oo", [(-3, 0), (0, -1), (-2.5, -4), (0, 0)])
def test_target_zero_orders_nothing_whatever_the_stock(oh, oo):
    con = _con()
    _part(con, "T0", oh=oh, oo=oo)
    r = _run(con)[K("T0")]
    assert r["StockingTarget"] == 0 and r["RecommendedOrderQty"] == 0
    assert r["Status"] == "NoRecentActivity"


def test_target_zero_with_demand_and_negative_on_order_is_not_stocked():
    con = _con()
    _part(con, "T0D", oo=-1)
    _hist(con, "T0D", {"2026-09-01": (1, 1)})
    r = _run(con)[K("T0D")]
    assert (r["StockingTarget"], r["RecommendedOrderQty"], r["Status"]) == (0, 0, "NotStocked")


def test_negative_on_order_still_counts_when_target_is_positive():
    con = _con()
    _part(con, "NOO", oo=-1)
    _minimum(con, "NOO", 1)
    r = _run(con)[K("NOO")]
    assert r["RecommendedOrderQty"] == 2                   # 1 - 0 - (-1)


def test_zero_supply_with_demand_is_not_stocked():
    con = _con()
    _part(con, "Z0")
    _hist(con, "Z0", {"2026-09-01": (5, 1)})
    _simple_rule(con, woc=0)
    r = _run(con)[K("Z0")]
    assert (r["DemandCount"], r["CalcTarget"], r["StockingTarget"], r["Status"]) == (1, 0, 0, "NotStocked")


def test_ok_status_when_stock_covers_target():
    con = _con()
    _part(con, "OK", oh=3, oo=1)
    _minimum(con, "OK", 4)
    r = _run(con)[K("OK")]
    assert r["RecommendedOrderQty"] == 0 and r["Status"] == "OK"


def test_surplus_and_truncated_quantities():
    con = _con()
    _part(con, "P6", oh=10.7, branch="92")
    _part(con, "P7", oh=9.9, branch="92")
    _minimum(con, "P7", 4, branch="92")
    r = _run(con)
    assert r[K("P6", "92")]["Status"] == "NoRecentActivity"
    assert r[K("P6", "92")]["StockingTarget"] == 0 and r[K("P6", "92")]["SurplusQty"] == 10
    assert r[K("P7", "92")]["SurplusQty"] == 5                       # trunc(9.9) = 9 minus target 4
    assert r[K("P7", "92")]["Status"] == "OK"


def test_null_on_hand_counts_as_out_of_stock():
    con = _con()
    _part(con, "P8", oh=None)
    _minimum(con, "P8", 1)
    r = _run(con)[K("P8")]
    assert r["RecommendedOrderQty"] == 1 and r["Status"] == "OutOfStock"


def test_fractional_on_hand_is_in_stock_and_on_order_subtracted():
    con = _con()
    _part(con, "F1", oh=0.5)
    _part(con, "F2", oo=1.9)
    _minimum(con, "F1", 3)
    _minimum(con, "F2", 3)
    r = _run(con)
    assert r[K("F1")]["RecommendedOrderQty"] == 3 and r[K("F1")]["Status"] == "Reorder"
    assert r[K("F2")]["RecommendedOrderQty"] == 2 and r[K("F2")]["Status"] == "OutOfStock"


def test_negative_on_hand_truncates_toward_zero():
    con = _con()
    _part(con, "N1", oh=-1.5)
    _part(con, "N2", oh=-0.5)
    _minimum(con, "N1", 1)
    _minimum(con, "N2", 1)
    r = _run(con)
    assert r[K("N1")]["RecommendedOrderQty"] == 2
    assert r[K("N2")]["RecommendedOrderQty"] == 1
    assert r[K("N1")]["SurplusQty"] == 0


# ---------------------------------------------------------------------------------------------------------
# line value limits (D7)
# ---------------------------------------------------------------------------------------------------------
def _line(con, target=10, cost=10, oh=0, minlv=None, maxlv=None):
    _part(con, "LV", oh=oh, cost=cost)
    _hist(con, "LV", {"2026-09-01": (target, 1)})
    _simple_rule(con, minlv=minlv, maxlv=maxlv)
    assert chk.invalid_rules(con) == []
    return _run(con)[K("LV")]


def test_no_line_limits_leave_quantity_alone():
    r = _line(_con())
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (10, False, False)


def test_max_line_value_caps_quantity():
    r = _line(_con(), maxlv=55)                            # 10 x $10 = $100 > $55 -> floor(5.5) = 5
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (5, True, False)
    assert r["StockingTarget"] == 10 and r["Status"] == "OutOfStock"


def test_max_line_value_equal_is_not_capped():
    r = _line(_con(), maxlv=100)
    assert (r["RecommendedOrderQty"], r["ValueCapped"]) == (10, False)


def test_max_line_value_floor_rounds_away_noise():
    # 0.3 / 0.1 = 2.9999999999999996 in doubles; round9 first gives 3
    r = _line(_con(), target=5, cost=0.1, maxlv=0.3)
    assert (r["RecommendedOrderQty"], r["ValueCapped"]) == (3, True)


def test_max_line_value_product_compared_without_noise():
    # 3 x 0.1 must not read as more than 0.3
    r = _line(_con(), target=3, cost=0.1, maxlv=0.3)
    assert (r["RecommendedOrderQty"], r["ValueCapped"]) == (3, False)


def test_max_line_value_below_cost_cuts_to_zero():
    r = _line(_con(), maxlv=5)                             # one unit costs $10
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (0, True, False)
    assert r["Status"] == "AboveMaxValue"                  # D13


def test_min_line_value_zeroes_small_line():
    r = _line(_con(), target=2, minlv=25)                  # $20 < $25
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (0, False, True)
    assert r["Status"] == "BelowMinValue"


def test_min_line_value_equal_is_kept():
    r = _line(_con(), target=2, minlv=20)
    assert (r["RecommendedOrderQty"], r["BelowMinValue"]) == (2, False)


def test_cap_applies_before_minimum():
    # $100 is above the $52 minimum, but capped to 5 x $10 = $50 it falls below it
    r = _line(_con(), minlv=52, maxlv=55)
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (0, True, True)
    assert r["Status"] == "BelowMinValue"


def test_cap_then_minimum_both_satisfied():
    r = _line(_con(), minlv=50, maxlv=55)
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (5, True, False)


def test_cap_to_zero_then_minimum():
    # a cap to 0 is AboveMaxValue, not BelowMinValue (D13)
    r = _line(_con(), minlv=1, maxlv=5)
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (0, True, False)
    assert r["Status"] == "AboveMaxValue"


# D13: every combination of the two limits -> (order, ValueCapped, BelowMinValue, Status); 10 wanted at $10, on hand 0
LIMIT_COMBOS = {
    "none": (None, None, (10, False, False, "OutOfStock")),
    "max not hit": (None, 100, (10, False, False, "OutOfStock")),
    "max partial cap": (None, 55, (5, True, False, "OutOfStock")),
    "max cap to 0": (None, 9.99, (0, True, False, "AboveMaxValue")),
    "max 0": (None, 0, (0, True, False, "AboveMaxValue")),
    "min met": (100, None, (10, False, False, "OutOfStock")),
    "min not met": (100.01, None, (0, False, True, "BelowMinValue")),
    "min 0": (0, None, (10, False, False, "OutOfStock")),
    "both, neither hit": (50, 200, (10, False, False, "OutOfStock")),
    "both, partial cap, min met": (50, 55, (5, True, False, "OutOfStock")),
    "both, partial cap, min not met": (52, 55, (0, True, True, "BelowMinValue")),
    "both, cap to 0": (1, 5, (0, True, False, "AboveMaxValue")),
    "both 0": (0, 0, (0, True, False, "AboveMaxValue")),
    "both, uncapped, min not met": (150, 150, (0, False, True, "BelowMinValue")),
}


@pytest.mark.parametrize("minlv,maxlv,expected", LIMIT_COMBOS.values(), ids=LIMIT_COMBOS.keys())
def test_line_limit_combinations(minlv, maxlv, expected):
    r = _line(_con(), minlv=minlv, maxlv=maxlv)
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"], r["Status"]) == expected


def test_partial_cap_in_stock_is_reorder():
    r = _line(_con(), target=10, oh=2, maxlv=55)           # wants 8 = $80, capped to 5
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["Status"]) == (5, True, "Reorder")


def test_min_value_comparison_rounds_away_noise():
    # 3 x 0.7 = 2.0999999999999996 in doubles; rounded it equals the 2.10 minimum
    r = _line(_con(), target=3, cost=0.7, minlv=2.1)
    assert (r["RecommendedOrderQty"], r["BelowMinValue"]) == (3, False)


@pytest.mark.parametrize("setting,status", [(dict(manual=True), "ManualOrder"), (dict(masked=True), "Masked")])
def test_cap_to_zero_under_manual_order_or_mask(setting, status):
    con = _con()
    _stocked(con, "C0", 10, maxlv=5)
    _setting(con, "C0", **setting)
    r = _run(con)[K("C0")]
    assert (r["ValueCapped"], r["RecommendedOrderQty"], r["Status"]) == (True, 0, status)


def test_line_limits_skipped_when_nothing_to_order():
    r = _line(_con(), target=2, oh=5, minlv=25, maxlv=30)
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (0, False, False)
    assert r["Status"] == "OK"


def test_zero_cost_part_is_out_of_scope_even_with_limits():
    con = _con()
    _part(con, "FREE", cost=0)
    _hist(con, "FREE", {"2026-09-01": (5, 1)})
    _simple_rule(con, minlv=1, maxlv=1)
    assert K("FREE") not in _run(con)


def test_line_limits_with_small_cost():
    r = _line(_con(), target=300, cost=0.01, minlv=1, maxlv=2.5)   # $3 > $2.50 -> 250 units = $2.50 >= $1
    assert (r["RecommendedOrderQty"], r["ValueCapped"], r["BelowMinValue"]) == (250, True, False)


def test_line_limits_come_from_the_matched_rule_only():
    con = _con()
    _part(con, "A", dgc="X")
    _part(con, "B")
    for pn in ("A", "B"):
        _hist(con, pn, {"2026-09-01": (10, 1)})
    _simple_rule(con)
    _rule(con, 2, priority=5, dgc="X", md=0, woc=52, maxlv=30)
    r = _run(con)
    assert r[K("A")]["RecommendedOrderQty"] == 3 and r[K("B")]["RecommendedOrderQty"] == 10


# ---------------------------------------------------------------------------------------------------------
# masking (D8), Manual Order, status
# ---------------------------------------------------------------------------------------------------------
def test_masked_part_orders_nothing():
    con = _con()
    _part(con, "P4")
    _minimum(con, "P4", 3)
    _setting(con, "P4", masked=True, expires="2026-12-31")
    r = _run(con)[K("P4")]
    assert r["StockingTarget"] == 3 and r["IsMasked"] is True
    assert r["RecommendedOrderQty"] == 0 and r["Status"] == "Masked"


def test_masked_wins_over_no_recent_activity():
    con = _con()
    _part(con, "P4")
    _setting(con, "P4", masked=True)
    assert _run(con)[K("P4")]["Status"] == "Masked"


def test_expired_mask_is_ignored():
    con = _con()
    _part(con, "P5")
    _minimum(con, "P5", 1)
    _setting(con, "P5", masked=True, expires="2026-10-19")
    r = _run(con)[K("P5")]
    assert r["IsMasked"] is False and r["Status"] == "OutOfStock"


def test_mask_expiring_today_still_masks():
    con = _con()
    _part(con, "M1")
    _minimum(con, "M1", 1)
    _setting(con, "M1", masked=True, expires="2026-10-20")
    assert _run(con)[K("M1")]["Status"] == "Masked"


@pytest.mark.parametrize("last_req,masked_on,masked", [
    ("2026-10-10 00:00", "2026-10-05", False),     # requested after it was masked: the mask falls off
    ("2026-10-06 00:00", "2026-10-05", False),     # the next day
    ("2026-10-05 00:00", "2026-10-05", True),      # same day: still masked
    ("2026-10-05 17:30", "2026-10-05", True),      # same day with a time: compared as dates
    ("2026-10-01 00:00", "2026-10-05", True),      # requested before it was masked
    (None, "2026-10-05", True),                    # never requested
    ("2026-10-10 00:00", None, True),              # older row without MaskedOn never falls off on demand
])
def test_mask_falls_off_at_first_demand_after_masking(last_req, masked_on, masked):
    con = _con()
    _part(con, "MF", last_req=last_req)
    _minimum(con, "MF", 2)
    _setting(con, "MF", masked=True, masked_on=masked_on)
    r = _run(con)[K("MF")]
    assert r["IsMasked"] is masked
    assert r["RecommendedOrderQty"] == (0 if masked else 2)
    assert r["Status"] == ("Masked" if masked else "OutOfStock")
    assert r["MaskedOn"] == (date.fromisoformat(masked_on) if masked_on else None)


def test_mask_fall_off_needs_masked_flag():
    con = _con()
    _part(con, "NM", last_req="2026-10-01 00:00")
    _setting(con, "NM", masked=False, masked_on="2026-10-05")
    r = _run(con)[K("NM")]
    assert r["IsMasked"] is False and r["Status"] == "NoRecentActivity"


def test_null_masked_is_not_masked():
    con = _con()
    _part(con, "NULLM")
    _minimum(con, "NULLM", 1)
    _setting(con, "NULLM", masked=None)
    assert _run(con)[K("NULLM")]["IsMasked"] is False


def test_manual_order_orders_nothing():
    con = _con()
    _part(con, "MO")
    _minimum(con, "MO", 5)
    _setting(con, "MO", manual=True)
    r = _run(con)[K("MO")]
    assert (r["ManualOrder"], r["StockingTarget"], r["RecommendedOrderQty"], r["Status"]) == \
        (True, 5, 0, "ManualOrder")


def test_manual_order_wins_over_masked_and_target_zero():
    con = _con()
    _part(con, "MO1")
    _part(con, "MO2")
    _minimum(con, "MO1", 5)
    _setting(con, "MO1", manual=True, masked=True)
    _setting(con, "MO2", sid=2, manual=True)
    r = _run(con)
    assert r[K("MO1")]["Status"] == "ManualOrder" and r[K("MO1")]["IsMasked"] is True
    assert r[K("MO2")]["Status"] == "ManualOrder" and r[K("MO2")]["StockingTarget"] == 0


def test_manual_order_wins_over_below_min_value():
    con = _con()
    _stocked(con, "MO3", 2, minlv=25)
    _setting(con, "MO3", manual=True)
    r = _run(con)[K("MO3")]
    assert r["BelowMinValue"] is True and r["Status"] == "ManualOrder"


@pytest.mark.parametrize("manual", [None, False])
def test_manual_order_null_or_false_is_off(manual):
    con = _con()
    _part(con, "MOF")
    _minimum(con, "MOF", 1)
    _setting(con, "MOF", manual=manual)
    r = _run(con)[K("MOF")]
    assert r["ManualOrder"] is False and r["RecommendedOrderQty"] == 1


def test_no_settings_row_defaults():
    con = _con()
    _part(con, "NS")
    r = _run(con)[K("NS")]
    assert (r["ManualOrder"], r["MaskedOn"], r["IsMasked"]) == (False, None, False)


def test_manual_order_latest_settings_row_wins():
    con = _con()
    _part(con, "MOL")
    _minimum(con, "MOL", 1)
    _setting(con, "MOL", sid=1, manual=True, modified="2026-10-01 10:00")
    _setting(con, "MOL", sid=2, manual=False, modified="2026-10-02 10:00")
    assert _run(con)[K("MOL")]["Status"] == "OutOfStock"


def test_masked_part_still_reports_line_value_flags():
    con = _con()
    _stocked(con, "ML", 2, minlv=25)
    _setting(con, "ML", masked=True)
    r = _run(con)[K("ML")]
    assert (r["BelowMinValue"], r["RecommendedOrderQty"], r["Status"]) == (True, 0, "Masked")


def test_below_min_value_wins_over_out_of_stock():
    con = _con()
    _stocked(con, "BMV", 1, minlv=25)
    r = _run(con)[K("BMV")]
    assert r["Status"] == "BelowMinValue"


def test_not_stocked_vs_no_recent_activity():
    con = _con()
    _part(con, "NRA", oh=2)
    _part(con, "NS", oh=2)
    _hist(con, "NS", {"2026-09-01": (1, 1)})                # 1 demand < 3 needed by the default
    r = _run(con)
    nra, ns = r[K("NRA")], r[K("NS")]
    assert (nra["DemandCount"], nra["StockingTarget"], nra["Status"]) == (0, 0, "NoRecentActivity")
    assert (ns["DemandCount"], ns["StockingTarget"], ns["Status"]) == (1, 0, "NotStocked")
    assert nra["RecommendedOrderQty"] == 0 and ns["RecommendedOrderQty"] == 0


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
# reading staging tables that don't have the round 1 columns yet
# ---------------------------------------------------------------------------------------------------------
def test_select_list_fills_missing_optional_columns_with_typed_nulls():
    con = duckdb.connect()
    con.execute("CREATE TABLE src (Id BIGINT, RuleName VARCHAR, MinDemands DOUBLE)")
    con.execute("INSERT INTO src VALUES (1, 'Default', 3)")
    sel = chk.select_list(con, "src", ["Id", "RuleName"],
                          {"MinDemands": "DOUBLE", "SupplyUnit": "VARCHAR", "Archived": "BOOLEAN"})
    con.execute(f"CREATE TABLE out AS SELECT {sel} FROM src")
    assert con.execute("SELECT * FROM out").fetchall() == [(1, "Default", 3.0, None, None)]
    types = dict(con.execute("SELECT column_name, data_type FROM information_schema.columns "
                             "WHERE table_name = 'out'").fetchall())
    assert types["SupplyUnit"] == "VARCHAR" and types["Archived"] == "BOOLEAN"


def test_select_list_casts_present_optional_columns():
    con = duckdb.connect()
    con.execute("CREATE TABLE src (Id BIGINT, MaskedOn TIMESTAMP)")
    con.execute("INSERT INTO src VALUES (1, TIMESTAMP '2026-10-05 00:00')")
    sel = chk.select_list(con, "src", ["Id"], {"MaskedOn": "DATE"})
    assert con.execute(f"SELECT {sel} FROM src").fetchall() == [(1, date(2026, 10, 5))]


def test_select_list_missing_required_column_fails():
    con = duckdb.connect()
    con.execute("CREATE TABLE src (Id BIGINT)")
    with pytest.raises(ValueError, match="RuleName"):
        chk.select_list(con, "src", ["Id", "RuleName"], {})


def test_reference_runs_on_todays_columns():
    """The Dev list and settings without the round 1 columns: every rule invalid, built-in default used."""
    con = _con()
    con.execute("ALTER TABLE order_rules RENAME TO order_rules_src")
    con.execute("ALTER TABLE settings RENAME TO settings_src")
    con.execute("ALTER TABLE order_rules_src DROP COLUMN MinDemands")
    for col in ("SupplyUnit", "MinLineValue", "MaxLineValue", "Archived"):
        con.execute(f"ALTER TABLE order_rules_src DROP COLUMN {col}")
    con.execute("ALTER TABLE settings_src DROP COLUMN ManualOrder")
    con.execute("ALTER TABLE settings_src DROP COLUMN MaskedOn")
    con.execute("""INSERT INTO order_rules_src (Id, RuleName, Priority, Active, HistoryMonths, MinActiveMonths,
                   WeeksOfCover, DemandBasis) VALUES (1, 'Default', 0, true, 12, 3, 6, 'UnitsSold')""")
    con.execute("INSERT INTO settings_src (Id, Branch, Franchise, PartNumber, Masked) VALUES (1,'1','MC','P1',true)")
    con.execute(f"CREATE TABLE order_rules AS SELECT {chk.select_list(con, 'order_rules_src', *chk.RULE_COLS)} "
                "FROM order_rules_src")
    con.execute(f"CREATE TABLE settings AS SELECT {chk.select_list(con, 'settings_src', *chk.SETTINGS_COLS)} "
                "FROM settings_src")
    _part(con, "P1")
    _part(con, "P2")
    _hist(con, "P2", {"2026-09-01": (12, 3)})
    r = _run(con)
    assert r[K("P1")]["Status"] == "Masked"
    assert r[K("P2")]["RuleName"] == "Built-in default" and r[K("P2")]["CalcTarget"] == 3
    assert chk.invalid_rules(con) == [(1, "Default", "MinDemands is missing")]


# ---------------------------------------------------------------------------------------------------------
# compare()
# ---------------------------------------------------------------------------------------------------------
CMP_COLS = [("Branch", "VARCHAR"), ("Franchise", "VARCHAR"), ("PartNumber", "VARCHAR"), ("RuleId", "BIGINT"),
            ("RuleName", "VARCHAR"), ("DemandBasis", "VARCHAR"), ("HistoryMonths", "INTEGER"),
            ("MinDemands", "INTEGER"), ("SupplyUnit", "VARCHAR"), ("Supply", "DOUBLE"), ("SupplyMonths", "DOUBLE"),
            ("MinLineValue", "DOUBLE"), ("MaxLineValue", "DOUBLE"), ("WindowDemand", "DOUBLE"),
            ("UnitsSoldWindow", "DOUBLE"), ("DemandCount", "INTEGER"), ("ActiveMonths", "INTEGER"), ("MonthlyRate", "DOUBLE"),
            ("CalcTarget", "INTEGER"), ("EffectiveMin", "DOUBLE"), ("MinimumNoDemand", "BOOLEAN"),
            ("StockingTarget", "INTEGER"), ("ValueCapped", "BOOLEAN"), ("BelowMinValue", "BOOLEAN"),
            ("ManualOrder", "BOOLEAN"), ("MaskedOn", "DATE"), ("IsMasked", "BOOLEAN"),
            ("RecommendedOrderQty", "INTEGER"), ("SurplusQty", "INTEGER"), ("InboundTransferQty", "DOUBLE"),
            ("Status", "VARCHAR")]
BASE = dict(Branch="1", Franchise="MC", PartNumber="A", RuleId=1, RuleName="Default", DemandBasis="UnitsSold",
            HistoryMonths=12, MinDemands=3, SupplyUnit="Weeks", Supply=12.0, SupplyMonths=12 * 12 / 52,
            MinLineValue=10.0, MaxLineValue=500.0, WindowDemand=3.0, UnitsSoldWindow=3.0, DemandCount=4, ActiveMonths=2,
            MonthlyRate=0.25, CalcTarget=1, EffectiveMin=0.0, MinimumNoDemand=False, StockingTarget=2,
            ValueCapped=False, BelowMinValue=False, ManualOrder=False, MaskedOn=date(2026, 10, 5), IsMasked=False,
            RecommendedOrderQty=1, SurplusQty=0, InboundTransferQty=0.0, Status="Reorder")


def test_compare_covers_every_output_column():
    assert [c for c, _ in CMP_COLS] == chk.OUTPUT_COLS
    assert set(chk.COMPARE_COLS) | set(chk.TOLERANCE_COLS) == set(chk.OUTPUT_COLS) - {"Branch", "Franchise",
                                                                                       "PartNumber"}
    assert not set(chk.COMPARE_COLS) & set(chk.TOLERANCE_COLS)


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
    ("DemandBasis", "Requests"), ("HistoryMonths", 6), ("MinDemands", 0), ("MinDemands", None),
    ("SupplyUnit", "Months"), ("SupplyUnit", None),
    ("DemandCount", 5), ("ActiveMonths", 3), ("CalcTarget", 2), ("CalcTarget", None),
    ("MinimumNoDemand", True), ("MinimumNoDemand", None),
    ("StockingTarget", 3), ("StockingTarget", None),
    ("ValueCapped", True), ("BelowMinValue", True), ("ManualOrder", True), ("ManualOrder", None),
    ("MaskedOn", date(2026, 10, 6)), ("MaskedOn", None), ("IsMasked", True),
    ("RecommendedOrderQty", 0), ("SurplusQty", 1), ("Status", "OK"),
    ("Supply", 6.5), ("Supply", None), ("SupplyMonths", 2.0), ("SupplyMonths", None),
    ("MinLineValue", 10.5), ("MinLineValue", None), ("MaxLineValue", 499.0), ("MaxLineValue", None),
    ("WindowDemand", 3.01), ("WindowDemand", None), ("UnitsSoldWindow", 2.0), ("UnitsSoldWindow", None),
    ("MonthlyRate", 0.2501), ("MonthlyRate", None), ("EffectiveMin", 1.0), ("EffectiveMin", None),
    ("InboundTransferQty", 0.5), ("InboundTransferQty", None),
])
def test_compare_flags_each_compared_column(col, value):
    r = _cmp([{}], [{col: value}])
    assert (r["only_gold"], r["only_expected"], r["different"]) == (0, 0, 1)


@pytest.mark.parametrize("col", ["Supply", "SupplyMonths", "MinLineValue", "MaxLineValue", "WindowDemand",
                                 "UnitsSoldWindow", "MonthlyRate", "EffectiveMin", "InboundTransferQty"])
def test_compare_tolerates_tiny_float_differences(col):
    r = _cmp([{}], [{col: BASE[col] + 1e-9}])
    assert r["different"] == 0
