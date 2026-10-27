# tools/dp-migration/test_nonjd_reorder_check.py
"""Tests for the reference reorder rules (Plan C round 1: docs/superpowers/plans/2026-10-26-non-jd-parts-order-tool-
round-1.md, "The calculation", "Validation" and decisions D13/D14), round 2 Parts 1-3 (spec 2026-10-27-non-jd-parts-
order-tool-round-2-design.md) and the compares."""
import random
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
                   DateLastRequested TIMESTAMP, PendingQty DECIMAL(12,2), SLC VARCHAR, Source VARCHAR,
                   CommodityCode VARCHAR, VendorCode INTEGER)""")
    con.execute("CREATE TABLE inmaster (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, ProductGroup VARCHAR)")
    con.execute("CREATE TABLE rules (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MinimumQty DECIMAL(10,2))")
    con.execute("""CREATE TABLE hist (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MonthStart DATE,
                   SalesQty DECIMAL(12,2), RequestCount INTEGER)""")
    con.execute("""CREATE TABLE order_rules (Id BIGINT, RuleName VARCHAR, Priority DOUBLE, Active BOOLEAN,
                   Franchise VARCHAR, DealerGroupCode VARCHAR, Branch VARCHAR, StartMonth DOUBLE, EndMonth DOUBLE,
                   HistoryMonths DOUBLE, MinActiveMonths DOUBLE, WeeksOfCover DOUBLE, DemandBasis VARCHAR,
                   MinDemands DOUBLE, SupplyUnit VARCHAR, MinLineValue DOUBLE, MaxLineValue DOUBLE, Archived BOOLEAN,
                   SLC VARCHAR, Source VARCHAR, VendorCode VARCHAR, ProductGroup VARCHAR, CommodityCode VARCHAR,
                   Modified TIMESTAMP)""")
    con.execute("""CREATE TABLE settings (Id INTEGER, Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   MinOverride DOUBLE, Masked BOOLEAN, MaskExpires DATE, ManualOrder BOOLEAN, MaskedOn DATE,
                   PhaseInQty DOUBLE, PhaseInEnds DATE, PhaseInOn DATE, Modified TIMESTAMP)""")
    con.execute("CREATE TABLE transfers (RequestingBranch VARCHAR, PartNumber VARCHAR, OpenQty DOUBLE)")
    con.execute("""CREATE TABLE app_transfers (TransferId BIGINT, Status VARCHAR, PlacedAt TIMESTAMPTZ,
                   FromBranch VARCHAR, ToBranch VARCHAR, LineId BIGINT, Franchise VARCHAR, PartNumber VARCHAR,
                   Qty DOUBLE, Kind VARCHAR, Created TIMESTAMPTZ)""")
    con.execute("""CREATE TABLE transfer_rules (Id BIGINT, RuleName VARCHAR, Priority DOUBLE, Active BOOLEAN,
                   Archived BOOLEAN, Franchise VARCHAR, DealerGroupCode VARCHAR, Branch VARCHAR, SLC VARCHAR,
                   Source VARCHAR, VendorCode VARCHAR, ProductGroup VARCHAR, CommodityCode VARCHAR,
                   StartMonth DOUBLE, EndMonth DOUBLE, ExcessSupply DOUBLE, ExcessUnit VARCHAR, AllowSend BOOLEAN,
                   AllowReceive BOOLEAN, RedistMax DOUBLE, RedistUnit VARCHAR, RedistMinValue DOUBLE,
                   Modified TIMESTAMPTZ)""")
    return con


def _part(con, pn, oh=0, oo=0, cost=10, branch="1", franchise="MC", dgc=None, last_req=None, pending=None,
          slc=None, source=None, commodity=None, vendor=None, product_group=None):
    con.execute("""INSERT INTO parts (Branch, Franchise, PartNumber, QuantityOnHand, OnOrder, Cost, DealerGroupCode,
                       DateLastRequested, PendingQty, SLC, Source, CommodityCode, VendorCode)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                [branch, franchise, pn, oh, oo, cost, dgc, last_req, pending, slc, source, commodity, vendor])
    if product_group is not None:
        con.execute("INSERT INTO inmaster VALUES (?, ?, ?, ?)", [branch, franchise, pn, product_group])


def _hist(con, pn, months, branch="1", franchise="MC"):
    """months: {MonthStart (date or 'YYYY-MM-DD'): (SalesQty, RequestCount)}"""
    for m, (sales, reqs) in months.items():
        con.execute("INSERT INTO hist VALUES (?, ?, ?, ?, ?, ?)", [branch, franchise, pn, m, sales, reqs])


def _rule(con, rid, name=None, priority=0, active=True, franchise=None, dgc=None, branch=None, start=None,
          end=None, hm=12, md=3, woc=6, basis="UnitsSold", unit=None, minlv=None, maxlv=None, archived=None,
          mam=None, slc=None, source=None, vendor=None, product_group=None, commodity=None):
    con.execute("""INSERT INTO order_rules (Id, RuleName, Priority, Active, Franchise, DealerGroupCode, Branch,
                       StartMonth, EndMonth, HistoryMonths, MinActiveMonths, WeeksOfCover, DemandBasis, MinDemands,
                       SupplyUnit, MinLineValue, MaxLineValue, Archived, SLC, Source, VendorCode, ProductGroup,
                       CommodityCode, Modified)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                           TIMESTAMP '2026-10-01')""",
                [rid, name or f"R{rid}", priority, active, franchise, dgc, branch, start, end, hm, mam, woc, basis,
                 md, unit, minlv, maxlv, archived, slc, source, vendor, product_group, commodity])


def _setting(con, pn, sid=1, min_override=None, masked=False, expires=None, manual=None, masked_on=None,
             modified="2026-10-01 10:00", branch="1", franchise="MC", phase_qty=None, phase_ends=None,
             phase_on=None):
    con.execute("""INSERT INTO settings (Id, Branch, Franchise, PartNumber, MinOverride, Masked, MaskExpires,
                       ManualOrder, MaskedOn, PhaseInQty, PhaseInEnds, PhaseInOn, Modified)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                [sid, branch, franchise, pn, min_override, masked, expires, manual, masked_on, phase_qty,
                 phase_ends, phase_on, modified])


def _app_line(con, status, qty, from_b="92", to_b="1", pn="P1", franchise="MC", placed_at=None, tid=1, lid=None,
              kind="Conventional"):
    """One NonJD_Transfers row (a transfer line joined to its header). placed_at is a UTC timestamp text."""
    lid = lid if lid is not None else con.execute("SELECT count(*) + 1 FROM app_transfers").fetchone()[0]
    con.execute("""INSERT INTO app_transfers VALUES (?, ?, CAST(? AS TIMESTAMPTZ), ?, ?, ?, ?, ?, ?, ?,
                   TIMESTAMPTZ '2026-10-19 15:00:00+00')""",
                [tid, status, placed_at + ":00+00" if placed_at else None, from_b, to_b, lid, franchise, pn, qty,
                 kind])


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
        "IsMasked", "RecommendedOrderQty", "SurplusQty", "InboundTransferQty", "Status",
        "PendingQty", "SLC", "Source", "CommodityCode", "PhaseInQty", "PhaseInEnds", "PhaseInOn", "PhaseInActive",
        "PhaseInEndReason", "AppInboundQty", "AppOutboundQty",
        "TransferRuleId", "TransferRuleName", "ExcessSupply", "ExcessUnit", "AllowSend", "AllowReceive",
        "RedistMax", "RedistUnit", "RedistMinValue", "ExcessKeep", "FreeExcess", "ConvNeed", "RedistCap",
        "RedistEligible", "SuggestedInQty", "SuggestedConvInQty", "SuggestedOutQty"]


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
# round 2 (spec 2026-10-27): A11 rule criteria SLC, Source, VendorCode, ProductGroup, CommodityCode
# ---------------------------------------------------------------------------------------------------------
def test_slc_criterion_matches_trimmed_upper_part_value():
    con = _con()
    _part(con, "P1", slc=" 00 ")
    _part(con, "P2", slc="50e")
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, slc="00")
    _rule(con, 3, priority=10, slc=" 50E ")
    r = _run(con)
    assert r[K("P1")]["RuleId"] == 2 and r[K("P2")]["RuleId"] == 3


@pytest.mark.parametrize("criterion", [None, "", "   "])
def test_blank_slc_criterion_matches_null_slc(criterion):
    con = _con()
    _part(con, "P1", slc=None)
    _rule(con, 1, priority=10, slc=criterion)
    assert _run(con)[K("P1")]["RuleId"] == 1


@pytest.mark.parametrize("part_slc", [None, "", "  "])
def test_slc_criterion_does_not_match_blank_slc(part_slc):
    con = _con()
    _part(con, "P1", slc=part_slc)
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, slc="00")
    assert _run(con)[K("P1")]["RuleId"] == 1


@pytest.mark.parametrize("crit,part_kw", [
    (dict(source="al"), dict(source=" AL")),
    (dict(product_group=" pg1 "), dict(product_group="PG1")),
    (dict(commodity="ab"), dict(commodity="AB ")),
])
def test_other_text_criteria_match_trimmed_upper(crit, part_kw):
    con = _con()
    _part(con, "P1", **part_kw)
    _part(con, "P2")                                   # no value: only blank criteria match
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, **crit)
    r = _run(con)
    assert r[K("P1")]["RuleId"] == 2 and r[K("P2")]["RuleId"] == 1


def test_product_group_comes_from_inmaster_per_branch():
    con = _con()
    _part(con, "P1", branch="1", product_group="PG1")
    _part(con, "P1", branch="2", product_group="PG2")
    _part(con, "P1", branch="3")                       # no InMaster row
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, product_group="PG1")
    r = _run(con)
    assert [r[K("P1", b)]["RuleId"] for b in ("1", "2", "3")] == [2, 1, 1]


@pytest.mark.parametrize("criterion,matches", [("1234", True), (" 1234 ", True), ("01234", False),
                                               ("1234.0", False), ("123", False)])
def test_vendor_code_criterion_compared_as_the_integers_text(criterion, matches):
    con = _con()
    _part(con, "P1", vendor=1234)
    _rule(con, 1, priority=0)
    _rule(con, 2, priority=10, vendor=criterion)
    assert _run(con)[K("P1")]["RuleId"] == (2 if matches else 1)


def test_vendor_code_zero_matches_criterion_zero():
    con = _con()
    _part(con, "P1", vendor=0)
    _rule(con, 2, priority=10, vendor="0")
    assert _run(con)[K("P1")]["RuleId"] == 2


def test_four_criteria_beat_three_at_equal_priority():
    con = _con()
    _part(con, "P1", dgc="COTTON", slc="00", source="500", vendor=77, product_group="PG", commodity="CC")
    _rule(con, 3, priority=5, franchise="MC", dgc="COTTON", branch="1")
    _rule(con, 8, priority=5, slc="00", source="500", vendor="77", commodity="CC")
    _rule(con, 9, priority=5, slc="00", source="500", vendor="77", product_group="PG", commodity="CC")
    assert _run(con)[K("P1")]["RuleId"] == 9                # 5 criteria beats 4 beats 3


def test_eight_criteria_counted():
    con = _con()
    _part(con, "P1", dgc="G", slc="S", source="O", vendor=1, product_group="P", commodity="C")
    _rule(con, 1, priority=5, franchise="MC", dgc="G", branch="1", slc="S", source="O", vendor="1",
          product_group="P")                                                    # 7
    _rule(con, 2, priority=5, franchise="MC", dgc="G", branch="1", slc="S", source="O", vendor="1",
          product_group="P", commodity="C")                                     # 8
    assert _run(con)[K("P1")]["RuleId"] == 2


def test_new_criteria_values_are_output_raw():
    con = _con()
    _part(con, "P1", pending=2.5, slc=" 00 ", source="al", commodity=None)
    r = _run(con)[K("P1")]
    assert (r["PendingQty"], r["SLC"], r["Source"], r["CommodityCode"]) == (2.5, " 00 ", "al", None)


# ---------------------------------------------------------------------------------------------------------
# round 2: step 7b (phase-in) and step 8 (target with phase-in); A18, A19
# ---------------------------------------------------------------------------------------------------------
def _phase(con, pn="P1", qty=5, ends="2026-10-21", on="2026-10-01", md=None, demands=0, **setting_kw):
    """A part with `demands` requests last month (0 = no history) and a phase-in setting; md = a catch-all rule's
    MinDemands (None = the built-in default, MinDemands 3)."""
    _part(con, pn)
    if demands:
        _hist(con, pn, {"2026-09-01": (demands, demands)})
    if md is not None:
        _rule(con, 1, md=md, woc=52)
    _setting(con, pn, phase_qty=qty, phase_ends=ends, phase_on=on, **setting_kw)
    return _run(con)[K(pn)]


def test_phase_in_active_sets_target():
    r = _phase(_con(), qty=5, ends="2026-10-21")          # ends tomorrow, 0 demands, MinDemands 3
    assert (r["PhaseInActive"], r["PhaseInEndReason"]) == (True, None)
    assert (r["PhaseInQty"], r["PhaseInEnds"], r["PhaseInOn"]) == (5, date(2026, 10, 21), date(2026, 10, 1))
    assert (r["CalcTarget"], r["StockingTarget"], r["RecommendedOrderQty"], r["Status"]) == (0, 5, 5, "OutOfStock")


@pytest.mark.parametrize("ends", ["2026-10-20", None])
def test_phase_in_ending_today_or_open_ended_is_active(ends):
    r = _phase(_con(), ends=ends)
    assert r["PhaseInActive"] is True and r["StockingTarget"] == 5


def test_phase_in_expired_yesterday():
    r = _phase(_con(), ends="2026-10-19")
    assert (r["PhaseInActive"], r["PhaseInEndReason"], r["StockingTarget"]) == (False, "Expired", 0)
    assert r["PhaseInQty"] == 5                            # still shown


def test_phase_in_met_criteria():
    r = _phase(_con(), md=3, demands=3)
    assert (r["PhaseInActive"], r["PhaseInEndReason"]) == (False, "MetCriteria")
    assert r["StockingTarget"] == r["CalcTarget"] == 3


def test_phase_in_below_min_demands_stays_active():
    r = _phase(_con(), qty=8, md=3, demands=2)
    assert (r["PhaseInActive"], r["CalcTarget"], r["StockingTarget"]) == (True, 0, 8)


def test_phase_in_expired_wins_over_met_criteria():
    r = _phase(_con(), ends="2026-10-01", md=3, demands=3)
    assert (r["PhaseInActive"], r["PhaseInEndReason"]) == (False, "Expired")


def test_phase_in_min_demands_zero_needs_one_demand():
    r = _phase(_con(), md=0)                               # max(MinDemands, 1) = 1; 0 demands -> still active
    assert (r["PhaseInActive"], r["PhaseInEndReason"], r["StockingTarget"]) == (True, None, 5)
    r = _phase(_con(), md=0, demands=1)
    assert (r["PhaseInActive"], r["PhaseInEndReason"]) == (False, "MetCriteria")


@pytest.mark.parametrize("qty", [None, 0])
def test_phase_in_qty_blank_or_zero_has_no_reason(qty):
    r = _phase(_con(), qty=qty, ends="2026-10-01", md=3, demands=3)
    assert (r["PhaseInActive"], r["PhaseInEndReason"], r["PhaseInQty"]) == (False, None, None)


def test_phase_in_without_settings_row():
    con = _con()
    _part(con, "P1")
    r = _run(con)[K("P1")]
    assert (r["PhaseInQty"], r["PhaseInEnds"], r["PhaseInOn"], r["PhaseInActive"], r["PhaseInEndReason"]) == \
        (None, None, None, False, None)


@pytest.mark.parametrize("kw,status", [(dict(masked=True), "Masked"), (dict(manual=True), "ManualOrder")])
def test_mask_and_manual_order_beat_phase_in(kw, status):
    r = _phase(_con(), **kw)
    assert (r["PhaseInActive"], r["StockingTarget"], r["RecommendedOrderQty"], r["Status"]) == (True, 5, 0, status)


def test_phase_in_uses_latest_settings_row():
    con = _con()
    _part(con, "P1")
    _setting(con, "P1", sid=1, phase_qty=5, modified="2026-10-01 10:00")
    _setting(con, "P1", sid=2, phase_qty=None, modified="2026-10-02 10:00")      # cleared
    r = _run(con)[K("P1")]
    assert (r["PhaseInQty"], r["PhaseInActive"], r["StockingTarget"]) == (None, False, 0)


@pytest.mark.parametrize("qty,cal_units,minimum,target", [
    (4, 10, None, 10),       # CalcTarget above the phase-in
    (15, 10, None, 15),      # phase-in above CalcTarget
    (4, 0, 6.5, 7),          # minimum (rounded up) above the phase-in
    (9, 0, 6.5, 9),          # phase-in above the minimum
])
def test_target_is_largest_of_calc_minimum_and_phase_in(qty, cal_units, minimum, target):
    # MinDemands 0 with units sold but no requests: CalcTarget > 0 while DemandCount 0 < 1 keeps the phase-in on
    con = _con()
    _part(con, "P1")
    if cal_units:
        _hist(con, "P1", {"2026-09-01": (cal_units, 0)})
    if minimum is not None:
        _minimum(con, "P1", minimum)
    _rule(con, 1, md=0, woc=52)
    _setting(con, "P1", phase_qty=qty)
    r = _run(con)[K("P1")]
    assert r["PhaseInActive"] is True and r["CalcTarget"] == cal_units and r["StockingTarget"] == target


def test_phase_in_changes_surplus():
    con = _con()
    _part(con, "P1", oh=7)
    _setting(con, "P1", phase_qty=5)
    r = _run(con)[K("P1")]
    assert (r["StockingTarget"], r["SurplusQty"], r["Status"]) == (5, 2, "OK")


# ---------------------------------------------------------------------------------------------------------
# round 2: validation of part settings (PhaseInQty)
# ---------------------------------------------------------------------------------------------------------
PHASE_QTY = "PhaseInQty must be a whole number 1-99999"


@pytest.mark.parametrize("qty", [0, 1.5, 100000, -1, float("nan"), float("inf")])
def test_invalid_phase_in_qty_is_ignored_and_reported(qty):
    con = _con()
    _part(con, "P1")
    _setting(con, "P1", sid=7, phase_qty=qty)
    r = _run(con)[K("P1")]
    assert (r["PhaseInQty"], r["PhaseInActive"], r["PhaseInEndReason"], r["StockingTarget"]) == (None, False, None, 0)
    assert chk.invalid_settings(con) == [(7, "1", "MC", "P1", PHASE_QTY)]


@pytest.mark.parametrize("qty", [None, 1, 99999])
def test_valid_phase_in_qty_not_reported(qty):
    con = _con()
    _setting(con, "P1", phase_qty=qty)
    assert chk.invalid_settings(con) == []


def test_invalid_settings_checks_only_the_latest_row_per_part():
    con = _con()
    _setting(con, "P1", sid=1, phase_qty=1.5, modified="2026-10-01 10:00")      # superseded
    _setting(con, "P1", sid=2, phase_qty=3, modified="2026-10-02 10:00")
    _setting(con, "P2", sid=3, phase_qty=0, modified="2026-10-01 10:00")
    _setting(con, "P2", sid=4, phase_qty=0, branch="2")
    assert chk.invalid_settings(con) == [(3, "1", "MC", "P2", PHASE_QTY), (4, "2", "MC", "P2", PHASE_QTY)]


# ---------------------------------------------------------------------------------------------------------
# round 2: step 8b (committed app transfers, A14) and step 9
# ---------------------------------------------------------------------------------------------------------
def _committed(con, oh=0, oo=0):
    """Part P1 at branch 1 with target 10 under _simple_rule; returns a function giving its output row, to call
    once the lines are added."""
    _stocked(con, "P1", 10, oh=oh, oo=oo)
    return lambda: _run(con)[K("P1")]


def test_draft_and_exported_lines_count_and_sum():
    con = _con()
    row = _committed(con)
    _app_line(con, "Draft", 2)
    _app_line(con, "Exported", 3, tid=2)
    _app_line(con, "Draft", 1, kind="Redistribution", tid=3)
    r = row()
    assert (r["AppInboundQty"], r["AppOutboundQty"]) == (6, 0)
    assert (r["StockingTarget"], r["RecommendedOrderQty"]) == (10, 4)


@pytest.mark.parametrize("placed_at,counts", [
    ("2026-10-20 06:00", True),     # 01:00 CDT on the build's Central date
    ("2026-10-20 05:00", True),     # 00:00 CDT: the first moment of the Central day
    ("2026-10-20 04:59", False),    # 23:59 CDT the day before, although the UTC date is the build date
    ("2026-10-21 03:00", True),     # 22:00 CDT on the build date, although the UTC date is the next day
    ("2026-10-19 12:00", False),    # the day before
    (None, False),                  # Placed without a PlacedAt
])
def test_placed_counts_only_from_the_builds_central_date(placed_at, counts):
    con = _con()
    row = _committed(con)
    _app_line(con, "Placed", 4, placed_at=placed_at)
    assert row()["AppInboundQty"] == (4 if counts else 0)


def test_placed_central_date_in_winter_time():
    con = _con()
    row = _committed(con)
    _app_line(con, "Placed", 4, placed_at="2026-12-15 05:30")         # 23:30 CST on 12-14
    _app_line(con, "Placed", 2, placed_at="2026-12-15 06:30", tid=2)  # 00:30 CST on 12-15
    assert _run(con, cur=date(2026, 12, 1), today=date(2026, 12, 15))[K("P1")]["AppInboundQty"] == 2


@pytest.mark.parametrize("status", ["Cancelled", "draft", "", None, "Entered in Equip"])
def test_other_statuses_never_count(status):
    con = _con()
    row = _committed(con)
    _app_line(con, status, 4, placed_at="2026-10-20 12:00")
    assert row()["AppInboundQty"] == 0


def test_branch_compared_trimmed_and_case_insensitive():
    con = _con()
    _part(con, "P1", branch="7X")
    _part(con, "P1", branch="2")
    _app_line(con, "Draft", 3, from_b=" 2 ", to_b="7x ")
    _app_line(con, "Draft", 1, from_b="7x", to_b="2", tid=2)
    r = _run(con)
    assert (r[K("P1", "7X")]["AppInboundQty"], r[K("P1", "7X")]["AppOutboundQty"]) == (3, 1)
    assert (r[K("P1", "2")]["AppInboundQty"], r[K("P1", "2")]["AppOutboundQty"]) == (1, 3)


def test_franchise_and_part_number_compared_exactly():
    con = _con()
    _part(con, "X")
    _part(con, "X ")
    _app_line(con, "Draft", 1, pn="X")
    _app_line(con, "Draft", 2, pn="X ", tid=2)
    _app_line(con, "Draft", 4, pn="x", tid=3)
    _app_line(con, "Draft", 8, pn="X", franchise="mc", tid=4)
    _app_line(con, "Draft", 16, pn=" X", tid=5)
    r = _run(con)
    assert r[K("X")]["AppInboundQty"] == 1 and r[K("X ")]["AppInboundQty"] == 2


@pytest.mark.parametrize("other", ["12", " 4b ", "93C", "5", "97"])
def test_lines_to_or_from_excluded_branches_are_ignored(other):
    con = _con()
    _part(con, "P1")
    _app_line(con, "Draft", 3, from_b=other, to_b="1")
    _app_line(con, "Draft", 2, from_b="1", to_b=other, tid=2)
    r = _run(con)[K("P1")]
    assert (r["AppInboundQty"], r["AppOutboundQty"]) == (0, 0)


def test_outbound_sums_lines_to_several_branches():
    con = _con()
    _part(con, "P1", oh=20)
    _app_line(con, "Draft", 3, from_b="1", to_b="2")
    _app_line(con, "Exported", 4, from_b="1", to_b="3", tid=2)
    _app_line(con, "Placed", 5, from_b="1", to_b="2", placed_at="2026-10-20 15:00", tid=3)
    _app_line(con, "Placed", 6, from_b="1", to_b="2", placed_at="2026-10-18 15:00", tid=4)
    r = _run(con)[K("P1")]
    assert (r["AppInboundQty"], r["AppOutboundQty"]) == (0, 12)


def test_null_qty_line_counts_zero():
    con = _con()
    row = _committed(con)
    _app_line(con, "Draft", None)
    _app_line(con, "Draft", 2, tid=2)
    assert row()["AppInboundQty"] == 2


@pytest.mark.parametrize("bad_qty", [-3, -0.5, float("nan"), float("inf"), float("-inf")])
def test_negative_nan_and_infinite_qty_count_zero(bad_qty):
    con = _con()
    row = _committed(con)
    _app_line(con, "Draft", bad_qty)                          # into P1 at branch 1
    _app_line(con, "Draft", bad_qty, from_b="1", to_b="2", tid=2)  # out of P1 at branch 1
    _app_line(con, "Draft", 2, tid=3)
    _app_line(con, "Draft", 2.9, from_b="1", to_b="3", tid=4)  # truncated to 2
    r = row()
    assert (r["AppInboundQty"], r["AppOutboundQty"], r["RecommendedOrderQty"]) == (2, 2, 8)


@pytest.mark.parametrize("from_b,to_b", [(None, "1"), ("1", None), ("", "1"), ("1", "  ")])
def test_line_with_blank_or_null_branch_is_dropped(from_b, to_b):
    con = _con()
    row = _committed(con)
    _app_line(con, "Draft", 4, from_b=from_b, to_b=to_b)
    r = row()
    assert (r["AppInboundQty"], r["AppOutboundQty"]) == (0, 0)


def test_placed_in_the_future_counts():
    con = _con()
    row = _committed(con)
    _app_line(con, "Placed", 3, placed_at="2026-11-05 15:00")
    assert row()["AppInboundQty"] == 3


def test_no_lines_is_zero():
    con = _con()
    r = _committed(con)()
    assert (r["AppInboundQty"], r["AppOutboundQty"]) == (0, 0)


@pytest.mark.parametrize("oh,oo,inbound,qty,status", [
    (2, 1, 3, 4, "Reorder"),       # 10 - 2 - 1 - 3
    (0, 0, 3, 7, "OutOfStock"),
    (2, 1, 7, 0, "OK"),            # exactly covered
    (2, 1, 20, 0, "OK"),           # never negative
])
def test_base_qty_subtracts_app_inbound(oh, oo, inbound, qty, status):
    con = _con()
    row = _committed(con, oh=oh, oo=oo)
    _app_line(con, "Draft", inbound)
    r = row()
    assert (r["RecommendedOrderQty"], r["Status"]) == (qty, status)
    assert r["SurplusQty"] == max(0, oh - 10)                 # unchanged by transfers


def test_target_zero_ignores_app_inbound():
    con = _con()
    _part(con, "P1")
    _app_line(con, "Draft", 3)
    r = _run(con)[K("P1")]
    assert (r["AppInboundQty"], r["StockingTarget"], r["RecommendedOrderQty"], r["Status"]) == \
        (3, 0, 0, "NoRecentActivity")


def test_app_inbound_applies_before_line_value_limits():
    con = _con()
    _stocked(con, "P1", 10, minlv=50)                  # 10 x $10 = $100 alone; 4 x $10 = $40 < $50 after inbound
    _app_line(con, "Draft", 6)
    r = _run(con)[K("P1")]
    assert (r["RecommendedOrderQty"], r["BelowMinValue"], r["Status"]) == (0, True, "BelowMinValue")


def test_phase_in_with_app_inbound():
    con = _con()
    _part(con, "P1", oh=1)
    _setting(con, "P1", phase_qty=5)
    _app_line(con, "Draft", 2)
    r = _run(con)[K("P1")]
    assert (r["StockingTarget"], r["RecommendedOrderQty"], r["Status"]) == (5, 2, "Reorder")


# ---------------------------------------------------------------------------------------------------------
# round 2 Part 2: transfer rule pick (spec "Part 2" item 1; A10, A11)
# ---------------------------------------------------------------------------------------------------------
def _trule(con, rid, name=None, priority=0, active=True, archived=None, franchise=None, dgc=None, branch=None,
           slc=None, source=None, vendor=None, product_group=None, commodity=None, start=None, end=None,
           excess=12, excess_unit="Months", send=True, receive=True, redist=6, redist_unit="Months", minval=0):
    con.execute("""INSERT INTO transfer_rules VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                       ?, TIMESTAMPTZ '2026-10-01 00:00:00+00')""",
                [rid, name or f"T{rid}", priority, active, archived, franchise, dgc, branch, slc, source, vendor,
                 product_group, commodity, start, end, excess, excess_unit, send, receive, redist, redist_unit,
                 minval])


def _br(con, branch, oh=0, oo=0, units=0, cost=10, pending=None, pn="P1", franchise="MC", **part_kw):
    """Part `pn` at `branch` with `units` sold last month in one request. Under _simple_rule (52 weeks, MinDemands
    0) and the built-in transfer default (12 months): StockingTarget = units, MonthlyRate = units / 12,
    ExcessKeep = units, FreeExcess = max(0, oh - pending - units), ConvNeed = max(0, units - oh - oo) when units
    > 0, RedistCap = ceil(units / 2)."""
    _part(con, pn, oh=oh, oo=oo, cost=cost, branch=branch, franchise=franchise, pending=pending, **part_kw)
    if units:
        _hist(con, pn, {"2026-09-01": (units, 1)}, branch=branch, franchise=franchise)


def _lines(con, cur=CUR, today=TODAY):
    """The expected suggestion lines as (Kind initial, FromBranch, ToBranch, Qty, Seq), in Franchise, PartNumber,
    Seq order."""
    chk.build_expected(con, cur, today)
    return [(k[0], f, t, q, s) for k, f, t, q, s in con.execute(
        "SELECT Kind, FromBranch, ToBranch, Qty, Seq FROM expected_suggestion ORDER BY Franchise, PartNumber, Seq"
    ).fetchall()]


def _line_rows(con, cur=CUR, today=TODAY):
    chk.build_expected(con, cur, today)
    cur_ = con.execute("SELECT * FROM expected_suggestion ORDER BY Franchise, PartNumber, Seq")
    cols = [d[0] for d in cur_.description]
    return [dict(zip(cols, r)) for r in cur_.fetchall()]


TRULE_FIELDS = ("TransferRuleId", "TransferRuleName", "ExcessSupply", "ExcessUnit", "AllowSend", "AllowReceive",
                "RedistMax", "RedistUnit", "RedistMinValue")


def test_transfer_builtin_default_when_no_rules():
    con = _con()
    _part(con, "P1")
    r = _run(con)[K("P1")]
    assert tuple(r[c] for c in TRULE_FIELDS) == (None, "Built-in default", 12, "Months", True, True, 6, "Months", 0)


def test_transfer_builtin_default_constant():
    assert chk.TRANSFER_DEFAULT == {"RuleName": "Built-in default", "ExcessSupply": 12.0, "ExcessUnit": "Months",
                                    "AllowSend": True, "AllowReceive": True, "RedistMax": 6.0,
                                    "RedistUnit": "Months", "RedistMinValue": 0.0}


def test_transfer_rule_priority_then_criteria_then_lowest_id():
    con = _con()
    _part(con, "P1", dgc="COTTON")
    _part(con, "P2", dgc="PEANUT")
    _part(con, "P3", dgc="PEANUT", slc="00")
    _trule(con, 1, "Low", priority=0)
    _trule(con, 2, "High", priority=10, dgc="COTTON", excess=24)
    _trule(con, 7, priority=5, franchise="MC")
    _trule(con, 4, priority=5, branch="1")
    _trule(con, 9, priority=5, franchise="MC", slc="00")
    r = _run(con)
    assert (r[K("P1")]["TransferRuleId"], r[K("P1")]["TransferRuleName"], r[K("P1")]["ExcessSupply"]) == \
        (2, "High", 24)
    assert r[K("P2")]["TransferRuleId"] == 4          # 7 and 4 have one criterion each: lowest Id
    assert r[K("P3")]["TransferRuleId"] == 9          # two criteria (one of them SLC) beat one


def test_transfer_rule_eight_criteria_counted():
    con = _con()
    _part(con, "P1", dgc="G", slc="S", source="SO", vendor=12, commodity="CC", product_group="PG")
    _trule(con, 1, priority=1, franchise="MC", dgc="G", branch="1", slc="S", source="SO", vendor="12",
           product_group="PG")                                   # 7 criteria
    _trule(con, 2, priority=1, franchise="MC", dgc="G", branch="1", slc="S", source="SO", vendor="12",
           product_group="PG", commodity="CC")                   # 8 criteria
    assert _run(con)[K("P1")]["TransferRuleId"] == 2


def test_transfer_rule_criteria_trimmed_upper_and_blank_part_value():
    con = _con()
    _part(con, "P1", slc=" 00 ", vendor=1234)
    _part(con, "P2", slc=None, vendor=1234)
    _trule(con, 1, priority=5, slc=" 00", vendor=" 1234 ")
    _trule(con, 2, priority=0, slc="  ")                         # blank criterion = any
    r = _run(con)
    assert r[K("P1")]["TransferRuleId"] == 1
    assert r[K("P2")]["TransferRuleId"] == 2                     # a NULL SLC never matches "00"


@pytest.mark.parametrize("criterion,matches", [("1234", True), ("01234", False), ("1234.0", False)])
def test_transfer_rule_vendor_code_compared_as_integer_text(criterion, matches):
    con = _con()
    _part(con, "P1", vendor=1234)
    _trule(con, 1, vendor=criterion)
    assert (_run(con)[K("P1")]["TransferRuleId"] == 1) is matches


@pytest.mark.parametrize("start,end,cur,applies", [
    (None, None, date(2026, 10, 1), True), (10, 10, date(2026, 10, 1), True), (11, 2, date(2026, 12, 1), True),
    (11, 2, date(2026, 1, 1), True), (11, 2, date(2026, 10, 1), False), (3, 9, date(2026, 10, 1), False),
])
def test_transfer_rule_season(start, end, cur, applies):
    con = _con()
    _part(con, "P1")
    _trule(con, 1, start=start, end=end)
    r = _run(con, cur=cur, today=cur)[K("P1")]
    assert (r["TransferRuleId"] == 1) is applies


def test_transfer_rule_inactive_and_archived_ignored_and_not_reported():
    con = _con()
    _part(con, "P1")
    _trule(con, 1, priority=0, archived=None)
    _trule(con, 2, priority=10, active=False)
    _trule(con, 3, priority=20, active=None)
    _trule(con, 4, priority=30, archived=True)
    _trule(con, 5, priority=40, archived=True, excess=None)      # invalid but archived: not reported
    _trule(con, 6, priority=50, active=False, excess=None)       # invalid but inactive: not reported
    assert _run(con)[K("P1")]["TransferRuleId"] == 1
    assert chk.invalid_transfer_rules(con) == []


def test_invalid_transfer_rule_skipped_falls_back_to_next():
    con = _con()
    _part(con, "P1")
    _trule(con, 1, "Good", priority=0)
    _trule(con, 2, "Bad", priority=10, excess=None)
    assert _run(con)[K("P1")]["TransferRuleId"] == 1
    assert chk.invalid_transfer_rules(con) == [(2, "Bad", "ExcessSupply is missing")]


def test_each_branch_uses_its_own_transfer_rule():
    con = _con()
    _part(con, "P1", branch="1")
    _part(con, "P1", branch="92")
    _trule(con, 1, branch="92", send=False, excess_unit="Weeks", excess=26)
    r = _run(con)
    assert (r[K("P1", "92")]["TransferRuleId"], r[K("P1", "92")]["AllowSend"],
            r[K("P1", "92")]["ExcessUnit"]) == (1, False, "Weeks")
    assert r[K("P1", "1")]["TransferRuleName"] == "Built-in default"


@pytest.mark.parametrize("kw,expected", [
    (dict(excess_unit=" weeks "), dict(ExcessUnit="Weeks")),
    (dict(excess_unit=None), dict(ExcessUnit="Months")),
    (dict(excess_unit=""), dict(ExcessUnit="Months")),
    (dict(send=None, receive=None), dict(AllowSend=True, AllowReceive=True)),
    (dict(send=False, receive=False), dict(AllowSend=False, AllowReceive=False)),
    (dict(redist=None, redist_unit=None), dict(RedistMax=6, RedistUnit="Months")),
    (dict(redist=None, redist_unit="Weeks"), dict(RedistMax=6, RedistUnit="Months")),   # blank = 6 months
    (dict(redist=10, redist_unit="WEEKS"), dict(RedistMax=10, RedistUnit="Weeks")),
    (dict(redist=0), dict(RedistMax=0, RedistUnit="Months")),
    (dict(minval=None), dict(RedistMinValue=0)),
    (dict(minval=25), dict(RedistMinValue=25)),
])
def test_transfer_rule_values_output_with_blank_defaults(kw, expected):
    con = _con()
    _part(con, "P1")
    _trule(con, 1, **kw)
    r = _run(con)[K("P1")]
    assert r["TransferRuleId"] == 1
    assert {c: r[c] for c in expected} == expected


@pytest.mark.parametrize("name", [None, "", "  "])
def test_transfer_rule_name_falls_back_to_rule_id(name):
    con = _con()
    _part(con, "P1")
    _trule(con, 7)
    _trule(con, 8, excess=None)
    con.execute("UPDATE transfer_rules SET RuleName = ?", [name])
    assert _run(con)[K("P1")]["TransferRuleName"] == "Rule 7"
    assert chk.invalid_transfer_rules(con) == [(8, "Rule 8", "ExcessSupply is missing")]


# ---------------------------------------------------------------------------------------------------------
# round 2: transfer rule validation (spec "Validation", transfer rules)
# ---------------------------------------------------------------------------------------------------------
EX_MONTHS = "ExcessSupply must be 0-60 months"
EX_WEEKS = "ExcessSupply must be 0-260 weeks"
RD_MONTHS = "RedistMax must be 0-24 months"
RD_WEEKS = "RedistMax must be 0-104 weeks"
MINVAL = "RedistMinValue must be 0 or more"
T_INVALID = {
    "missing Priority": (dict(priority=None), "Priority is missing"),
    "missing ExcessSupply": (dict(excess=None), "ExcessSupply is missing"),
    "61 months": (dict(excess=61), EX_MONTHS),
    "61 months, unit blank": (dict(excess=61, excess_unit=" "), EX_MONTHS),
    "negative months": (dict(excess=-0.5), EX_MONTHS),
    "NaN months": (dict(excess=float("nan")), EX_MONTHS),
    "infinite months": (dict(excess=float("inf")), EX_MONTHS),
    "261 weeks": (dict(excess=261, excess_unit="Weeks"), EX_WEEKS),
    "negative weeks": (dict(excess=-1, excess_unit="weeks"), EX_WEEKS),
    "bad ExcessUnit": (dict(excess_unit="Days"), "ExcessUnit must be Weeks or Months"),
    "bad ExcessUnit, supply missing": (dict(excess_unit="Days", excess=None), "ExcessUnit must be Weeks or Months"),
    "RedistMax 25 months": (dict(redist=25), RD_MONTHS),
    "RedistMax 25, unit blank": (dict(redist=25, redist_unit=None), RD_MONTHS),
    "RedistMax negative": (dict(redist=-1), RD_MONTHS),
    "RedistMax NaN": (dict(redist=float("nan")), RD_MONTHS),
    "RedistMax 105 weeks": (dict(redist=105, redist_unit="Weeks"), RD_WEEKS),
    "bad RedistUnit": (dict(redist_unit="Years"), "RedistUnit must be Weeks or Months"),
    "bad RedistUnit, RedistMax blank": (dict(redist_unit="Years", redist=None), "RedistUnit must be Weeks or Months"),
    "RedistMinValue -1": (dict(minval=-1), MINVAL),
    "RedistMinValue NaN": (dict(minval=float("nan")), MINVAL),
    "RedistMinValue infinite": (dict(minval=float("inf")), MINVAL),
    "start month only": (dict(start=6), MONTHS_BOTH),
    "end month only": (dict(end=6), MONTHS_BOTH),
    "month 13": (dict(start=6, end=13), "EndMonth must be a whole number 1-12"),
    "month 0": (dict(start=0, end=5), START_1_12),
    "fractional month": (dict(start=2.5, end=5), START_1_12),
}


@pytest.mark.parametrize("kw,reason", T_INVALID.values(), ids=T_INVALID.keys())
def test_invalid_transfer_rule_skipped_and_reported(kw, reason):
    con = _con()
    _part(con, "P1")
    _trule(con, 1, "Good", priority=0)
    _trule(con, 2, "Bad", **{"priority": 10, **kw})
    assert _run(con)[K("P1")]["TransferRuleId"] == 1
    assert chk.invalid_transfer_rules(con) == [(2, "Bad", reason)]


T_VALID = {
    "0 months": dict(excess=0), "60 months": dict(excess=60), "12.5 months": dict(excess=12.5),
    "260 weeks": dict(excess=260, excess_unit="Weeks"), "unit any case": dict(excess=260, excess_unit=" wEEks "),
    "unit blank": dict(excess_unit=None), "RedistMax 0": dict(redist=0), "RedistMax 24": dict(redist=24),
    "RedistMax 104 weeks": dict(redist=104, redist_unit="Weeks"), "RedistMax blank": dict(redist=None),
    "RedistUnit blank": dict(redist_unit=""), "RedistMinValue 0": dict(minval=0),
    "RedistMinValue blank": dict(minval=None), "RedistMinValue 25": dict(minval=25),
    "send/receive blank": dict(send=None, receive=None), "season": dict(start=11, end=2),
}


@pytest.mark.parametrize("kw", T_VALID.values(), ids=T_VALID.keys())
def test_valid_transfer_rule(kw):
    con = _con()
    _trule(con, 1, **kw)
    assert chk.invalid_transfer_rules(con) == []


def test_invalid_transfer_rules_lists_every_problem_in_order():
    con = _con()
    _trule(con, 3, "Many", priority=None, excess=61, redist=-1, minval=-1, start=6)
    _trule(con, 1, "Units", excess_unit="Days", redist_unit="Days")
    assert chk.invalid_transfer_rules(con) == [
        (1, "Units", "ExcessUnit must be Weeks or Months; RedistUnit must be Weeks or Months"),
        (3, "Many", "; ".join(["Priority is missing", EX_MONTHS, RD_MONTHS, MINVAL, MONTHS_BOTH]))]


# ---------------------------------------------------------------------------------------------------------
# round 2 Part 2: transfer inputs per part (ExcessKeep, FreeExcess, ConvNeed, RedistCap, RedistEligible)
# ---------------------------------------------------------------------------------------------------------
P2 = ("ExcessKeep", "FreeExcess", "ConvNeed", "RedistCap", "RedistEligible")


def _p2(row):
    return tuple(row[c] for c in P2)


def test_part2_with_sales_under_the_default():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=20, units=6, pending=2)       # keep 6, free 20 - 2 - 6 = 12
    _br(con, "2", oh=1, oo=1, units=6)             # need 4, cap ceil(6/12 * 6) = 3
    r = _run(con)
    assert _p2(r[K("P1", "1")]) == (6, 12, 0, 3, False)
    assert _p2(r[K("P1", "2")]) == (6, 0, 4, 3, True)


def test_excess_keep_with_rate_zero_is_the_target():
    con = _con()
    _part(con, "P1", oh=10)
    _setting(con, "P1", min_override=4)
    r = _run(con)[K("P1")]
    assert (r["MonthlyRate"], r["StockingTarget"], r["ExcessKeep"], r["FreeExcess"]) == (0, 4, 4, 6)


def test_excess_keep_is_the_larger_of_target_and_excess_supply():
    con = _con()
    _simple_rule(con, woc=4)                       # target = ceil(12/12 * 4*12/52) = 1
    _br(con, "1", oh=30, units=12)                 # rate 1
    _trule(con, 1, excess=26, excess_unit="Weeks")  # 1 * 26*12/52 = 6
    r = _run(con)[K("P1")]
    assert (r["StockingTarget"], r["ExcessKeep"], r["FreeExcess"]) == (1, 6, 24)


def test_excess_keep_rounds_up_after_round9():
    con = _con()
    _simple_rule(con, hm=3, woc=0)                 # target 0
    _br(con, "1", oh=200, units=221)               # rate 221/3
    _trule(con, 1, excess=7, excess_unit="Weeks")  # 221/3 * (7*12/52) = 119.00000000000001 -> 119, not 120
    r = _run(con)[K("P1")]
    assert (r["StockingTarget"], r["ExcessKeep"], r["FreeExcess"]) == (0, 119, 81)


def test_excess_keep_target_wins_over_excess_supply():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=30, units=6)
    _setting(con, "P1", min_override=20)
    r = _run(con)[K("P1")]
    assert (r["StockingTarget"], r["ExcessKeep"], r["FreeExcess"]) == (20, 20, 10)


@pytest.mark.parametrize("pending,free", [(None, 10), (3, 7), (2.9, 8), (-4, 10), (20, 0)])
def test_free_excess_subtracts_truncated_pending(pending, free):
    con = _con()
    _part(con, "P1", oh=10, pending=pending)
    assert _run(con)[K("P1")]["FreeExcess"] == free


def test_free_excess_subtracts_app_outbound():
    con = _con()
    _part(con, "P1", oh=20, pending=3)
    _app_line(con, "Draft", 4, from_b="1", to_b="2")
    _app_line(con, "Exported", 1, from_b="1", to_b="3", tid=2)
    assert _run(con)[K("P1")]["FreeExcess"] == 12


def test_free_excess_truncates_on_hand():
    con = _con()
    _part(con, "P1", oh=5.9)
    assert _run(con)[K("P1")]["FreeExcess"] == 5


def test_allow_send_false_gives_no_free_excess():
    con = _con()
    _part(con, "P1", oh=20)
    _trule(con, 1, send=False)
    assert _run(con)[K("P1")]["FreeExcess"] == 0


def test_conv_need_is_the_base_qty_before_line_value_limits():
    con = _con()
    _simple_rule(con, maxlv=20, minlv=5)            # the order is capped to 2 ($20); ConvNeed is the base qty
    _br(con, "1", oh=2, oo=1, units=10)
    _app_line(con, "Draft", 3)                      # into 1: base 10 - 2 - 1 - 3 = 4
    r = _run(con)[K("P1")]
    assert (r["RecommendedOrderQty"], r["ConvNeed"]) == (2, 4)


@pytest.mark.parametrize("case", ["no receive", "manual", "masked", "no demand minimum", "free excess"])
def test_conv_need_zero(case):
    con = _con()
    _simple_rule(con)
    if case == "no receive":
        _br(con, "1", oh=0, units=6)
        _trule(con, 1, receive=False)
    elif case == "manual":
        _br(con, "1", oh=0, units=6)
        _setting(con, "P1", manual=True)
    elif case == "masked":
        _br(con, "1", oh=0, units=6)
        _setting(con, "P1", masked=True)
    elif case == "no demand minimum":
        _br(con, "1", oh=0)
        _minimum(con, "P1", 3)
    else:                                            # oh 10, oo -8: base 6 - 10 + 8 = 4, but free 10 - 6 = 4
        _br(con, "1", oh=10, oo=-8, units=6)
    r = _run(con)[K("P1")]
    if case == "no demand minimum":
        assert r["MinimumNoDemand"] is True
    if case == "free excess":
        assert r["FreeExcess"] == 4
    assert r["StockingTarget"] > 0 and r["ConvNeed"] == 0


def test_conv_need_zero_when_target_zero():
    con = _con()
    _part(con, "P1", oh=-3)
    assert _run(con)[K("P1")]["ConvNeed"] == 0


def test_conv_need_with_rate_zero_minimum_override():
    con = _con()
    _part(con, "P1", oh=1)
    _setting(con, "P1", min_override=4)
    r = _run(con)[K("P1")]
    assert (r["ConvNeed"], r["RedistEligible"]) == (3, False)       # rate 0: not RedistEligible


@pytest.mark.parametrize("redist,unit,units,cap", [
    (6, "Months", 6, 3), (6, "Months", 5, 3),      # 5/12 * 6 = 2.5 -> 3
    (26, "Weeks", 12, 6),                          # 1 * 26*12/52 = 6
    (0, "Months", 12, 0), (24, "Months", 1, 2), (6, "Months", 0, 0),
])
def test_redist_cap(redist, unit, units, cap):
    con = _con()
    _simple_rule(con)
    _br(con, "1", units=units)
    _trule(con, 1, redist=redist, redist_unit=unit)
    assert _run(con)[K("P1")]["RedistCap"] == cap


@pytest.mark.parametrize("case,eligible", [
    ("plain", True), ("no receive", False), ("manual", False), ("masked", False), ("free excess", False),
    ("target zero", False), ("rate zero", False),
])
def test_redist_eligible(case, eligible):
    con = _con()
    _simple_rule(con, md=3 if case == "target zero" else 0)    # 1 request < 3 demands: target 0, rate > 0
    _br(con, "1", oh=30 if case == "free excess" else 2, units=0 if case == "rate zero" else 6)
    if case == "rate zero":
        _setting(con, "P1", min_override=4)
    if case == "no receive":
        _trule(con, 1, receive=False)
    if case == "manual":
        _setting(con, "P1", manual=True)
    if case == "masked":
        _setting(con, "P1", masked=True)
    assert _run(con)[K("P1")]["RedistEligible"] is eligible


# ---------------------------------------------------------------------------------------------------------
# round 2 Part 3: conventional allocation
# ---------------------------------------------------------------------------------------------------------
def test_conventional_lowest_receiver_cover_first():
    con = _con()
    _simple_rule(con)
    _br(con, "9", oh=10)                           # rate 0, no target: free 10
    _br(con, "1", oh=2, units=12)                  # cover 2, need 10
    _br(con, "2", oh=9, units=36)                  # cover 3, need 27 (bigger need, but more cover)
    assert _lines(con) == [("C", "9", "1", 10, 1)]


def test_conventional_rate_zero_receivers():
    con = _con()
    _simple_rule(con)
    _br(con, "9", oh=4)                            # free 4
    _br(con, "1", oh=1, units=24)                  # rate 2: cover 0.5, need 23
    _br(con, "2", oh=0)                            # rate 0, no stock: cover 0
    _setting(con, "P1", branch="2", min_override=2)
    _br(con, "3", oh=1)                            # rate 0 with stock: cover +inf
    _setting(con, "P1", sid=2, branch="3", min_override=3)
    assert _lines(con) == [("C", "9", "2", 2, 1), ("C", "9", "1", 2, 2)]


def test_conventional_rate_zero_negative_stock_is_cover_zero():
    con = _con()
    _simple_rule(con)
    _br(con, "9", oh=3)
    _br(con, "1", oh=1, units=12)                  # cover 1
    _br(con, "2", oh=-2)                           # rate 0, stock -2 <= 0: cover 0
    _setting(con, "P1", branch="2", min_override=1)
    assert _lines(con) == [("C", "9", "2", 3, 1)]


def test_conventional_cover_tie_goes_to_larger_need():
    con = _con()
    _simple_rule(con)
    _br(con, "9", oh=30)
    _br(con, "1", oh=0, units=12)                  # cover 0, need 12
    _br(con, "2", oh=0, units=24)                  # cover 0, need 24
    assert _lines(con) == [("C", "9", "2", 24, 1), ("C", "9", "1", 6, 2)]


def test_conventional_then_branch_order():
    con = _con()
    _simple_rule(con)
    _br(con, "92", oh=24)
    for b in ("7X", "10", "2"):
        _br(con, b, oh=0, units=12)
    assert _lines(con) == [("C", "92", "2", 12, 1), ("C", "92", "10", 12, 2)]


def test_branch_order_key():
    codes = ["4B", "10", "2", "A", "02", " 3 ", "10A", "b", "B"]
    assert sorted(codes, key=chk.branch_order_key) == ["02", "2", " 3 ", "10", "10A", "4B", "A", "B", "b"]


def test_sender_with_greatest_cover_first():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=30, units=12)                 # rate 1: keep 12, free 18, cover 30
    _br(con, "2", oh=5, units=1)                   # rate 1/12: keep 1, free 4, cover 60
    _br(con, "3", oh=0, units=6)                   # need 6
    assert _lines(con) == [("C", "2", "3", 4, 1), ("C", "1", "3", 2, 2)]


def test_rate_zero_sender_first_then_largest_free_then_branch_order():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=100, units=12)                # cover 100, free 88
    _br(con, "4", oh=3)                            # rate 0: cover +inf, free 3
    _br(con, "3", oh=5)                            # rate 0: cover +inf, free 5
    _br(con, "2", oh=5)                            # rate 0: cover +inf, free 5 (branch 2 before 3)
    _br(con, "7", oh=0, units=20)                  # need 20
    assert _lines(con) == [("C", "2", "7", 5, 1), ("C", "3", "7", 5, 2), ("C", "4", "7", 3, 3),
                           ("C", "1", "7", 7, 4)]


def test_sender_repicked_after_every_line():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=30, units=12)                 # cover 30, free 18
    _br(con, "2", oh=28, units=12)                 # cover 28, free 16
    _br(con, "3", oh=0, units=5)                   # cover 0, need 5: first
    _br(con, "4", oh=1, units=5)                   # cover 2.4, need 4
    # after 5 from branch 1 its cover is 25 < 28, so branch 4 is filled from branch 2
    assert _lines(con) == [("C", "1", "3", 5, 1), ("C", "2", "4", 4, 2)]


def test_sender_cover_tie_goes_to_larger_free():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=24, units=12, pending=4)      # cover 24, free 8
    _br(con, "2", oh=24, units=12)                 # cover 24, free 12
    _br(con, "3", oh=0, units=6)
    assert _lines(con) == [("C", "2", "3", 6, 1)]


def test_one_receiver_from_two_senders_gives_seq_1_2():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=3)
    _br(con, "2", oh=4)
    _br(con, "3", oh=0, units=6)
    assert _lines(con) == [("C", "2", "3", 4, 1), ("C", "1", "3", 2, 2)]


def _arow(branch, free=0, need=0, eligible=False, cap=0, oh=0, oo=0, inbound=0, rate=1.0, cost=10.0, minval=0.0,
          target=1, keep=0, pn="P1", franchise="MC"):
    """One allocate_group input row (the Part 1-2 columns it reads)."""
    return {"Branch": branch, "Franchise": franchise, "PartNumber": pn, "oh": oh, "oo": oo, "AppInboundQty": inbound,
            "MonthlyRate": rate, "StockingTarget": target, "ExcessKeep": keep, "FreeExcess": free, "ConvNeed": need,
            "RedistEligible": eligible, "RedistCap": cap, "cost": cost, "RedistMinValue": minval}


def test_allocate_group_never_sends_to_itself():
    # A branch with both FreeExcess and a need can't come out of Part 2, but allocate_group must still guard it
    rows = [_arow("1", free=5, need=3, oh=8, rate=0.0), _arow("2", free=2, oh=2, rate=0.0)]
    lines = chk.allocate_group(rows, chk.branch_order_key)
    assert [(l["FromBranch"], l["ToBranch"], l["Qty"]) for l in lines] == [("2", "1", 2)]


def test_allocate_group_redistribution_never_to_itself():
    rows = [_arow("1", free=5, eligible=True, cap=10, oh=1), _arow("2", free=0, need=1, oh=0)]
    lines = chk.allocate_group(rows, chk.branch_order_key)
    assert [(l["Kind"], l["FromBranch"], l["ToBranch"], l["Qty"]) for l in lines] == [("Conventional", "1", "2", 1)]


def test_allocate_group_needs_a_sender_and_another_receiver():
    assert chk.allocate_group([_arow("1", free=5), _arow("2", free=3)], chk.branch_order_key) == []
    assert chk.allocate_group([_arow("1", need=5), _arow("2", eligible=True, cap=9)], chk.branch_order_key) == []
    assert chk.allocate_group([_arow("1", free=5, need=2)], chk.branch_order_key) == []


def test_allocate_group_is_independent_of_row_order():
    rng = random.Random(7)
    rows = [_arow(str(b), free=rng.choice([0, 0, 3, 8]), need=rng.choice([0, 0, 2, 5]), eligible=rng.random() < .4,
                  cap=rng.randint(0, 9), oh=rng.randint(0, 6), rate=rng.choice([0.25, 0.5, 1.0, 2.0]),
                  minval=rng.choice([0.0, 25.0])) for b in [1, 2, 3, 10, 20, 92, 93, 95]]
    want = chk.allocate_group(rows, chk.branch_order_key)
    assert want
    for _ in range(10):
        rng.shuffle(rows)
        assert chk.allocate_group(list(rows), chk.branch_order_key) == want


# ---------------------------------------------------------------------------------------------------------
# round 2 Part 3: redistribution
# ---------------------------------------------------------------------------------------------------------
def test_redistribution_runs_on_what_conventional_left():
    con = _con()
    _simple_rule(con, woc=4)                       # target = ceil(units * 4 / 52)
    _br(con, "9", oh=10)                           # free 10
    _br(con, "1", oh=0, units=26)                  # target 2, need 2; rate 26/12, cap ceil(13) = 13: room 11
    _br(con, "2", oh=2, units=12)                  # target 1, no need; rate 1, cap 6: room 4
    assert _lines(con) == [("C", "9", "1", 2, 1), ("R", "9", "1", 8, 2)]


def test_redistribution_lowest_cover_first():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=5)
    _br(con, "1", oh=3, units=12)                  # cover 3, room 3
    _br(con, "2", oh=2, units=12)                  # cover 2, room 4: first
    assert _lines(con) == [("R", "9", "2", 4, 1), ("R", "9", "1", 1, 2)]


def test_redistribution_cover_counts_conventional_got():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=9)
    _br(con, "1", oh=0, units=12)                  # rate 1, min override 3: need 3; cap 6, room 3; cover 0 -> 3
    _setting(con, "P1", branch="1", min_override=3)
    _br(con, "2", oh=2, units=12)                  # target 1, no need; cap 6, room 4; cover 2: first
    assert _lines(con) == [("C", "9", "1", 3, 1), ("R", "9", "2", 4, 2), ("R", "9", "1", 2, 3)]


def test_redistribution_room_counts_conventional_got():
    con = _con()
    _simple_rule(con)                              # target = units
    _br(con, "9", oh=40)
    _br(con, "1", oh=0, units=12)                  # need 12; cap 24 (rule): room 24 - 12 = 12, not 24
    _trule(con, 1, redist=24)
    assert _lines(con) == [("C", "9", "1", 12, 1), ("R", "9", "1", 12, 2)]


def test_redistribution_room_counts_on_order_and_app_inbound():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=40)
    _br(con, "1", oh=1, oo=1, units=12)            # cap 6, room 6 - 1 - 1 - 2 = 2
    _app_line(con, "Draft", 2, from_b="5X", to_b="1")
    assert _lines(con) == [("R", "9", "1", 2, 1)]


def test_redist_max_zero_takes_no_redistribution():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=40)
    _br(con, "1", oh=1, units=12)
    _trule(con, 1, branch="1", redist=0)
    assert _lines(con) == []


def test_redist_min_value_skips_a_sender_and_tries_the_next():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=2, cost=10)                   # cover +inf, free 2: 2 x $10 = $20 < $25, skipped
    _br(con, "8", oh=12, units=1, cost=10)         # rate 1/12, keep 1, free 11, cover 144
    _br(con, "1", oh=1, units=12, cost=10)         # room 5
    _trule(con, 1, branch="9", minval=25)
    assert _lines(con) == [("R", "8", "1", 5, 1)]


def test_redist_min_value_is_the_senders_rule_and_compared_on_round9():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=3, cost=0.1)                  # 3 x 0.1 = 0.30000000000000004, round9 = 0.3: not below 0.3
    _br(con, "1", oh=1, units=12, cost=50)         # room 5; the receiver's own minimum doesn't matter
    _trule(con, 1, branch="9", minval=0.3)
    _trule(con, 2, branch="1", minval=1000)
    assert _lines(con) == [("R", "9", "1", 3, 1)]


def test_redist_default_minimum_skips_nothing():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=1, cost=0.01)
    _br(con, "1", oh=1, units=12)
    assert _lines(con) == [("R", "9", "1", 1, 1)]


def test_redistribution_senders_greatest_cover_first_and_resorted():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "8", oh=22, units=12)                 # rate 1: keep 12, free 10, cover 22
    _br(con, "9", oh=21, units=12)                 # cover 21, free 9
    _br(con, "1", oh=0, units=12)                  # target 1, need 1 (conventional); cap 6
    _br(con, "2", oh=1, units=12)                  # cap 6, room 5
    # conventional: 1 from 8 (cover 22 -> 21, free 9). Redistribution: 1 and 2 both cover 1, branch order. Into 1:
    # 8 and 9 tie on cover 21 and free 9, so branch 8 sends 5 (cover 16). Into 2: branch 9 now has more cover.
    assert _lines(con) == [("C", "8", "1", 1, 1), ("R", "8", "1", 5, 2), ("R", "9", "2", 5, 3)]


def test_no_receivers_or_no_senders_no_lines():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=30, units=6)                  # excess, no receiver anywhere
    _br(con, "2", oh=6, units=6)                   # RedistEligible, but no room (cap 3)
    _br(con, "1", pn="P2", oh=0, units=6)          # a receiver of another part, with no sender
    r = _run(con)
    assert r[K("P1", "1")]["FreeExcess"] == 24 and r[K("P2", "1")]["ConvNeed"] == 6
    assert _lines(con) == []


def test_groups_are_franchise_and_exact_part_number():
    con = _con()
    _simple_rule(con)
    _br(con, "1", oh=30, pn="X")
    _br(con, "2", oh=0, units=6, pn="X ")         # different group: nothing from branch 1's "X"
    _br(con, "3", oh=0, units=6, pn="X", franchise="KU")
    assert _lines(con) == []


# ---------------------------------------------------------------------------------------------------------
# round 2 Part 3: output and determinism
# ---------------------------------------------------------------------------------------------------------
def test_suggestion_line_columns():
    con = _con()
    _simple_rule(con)
    _br(con, "9", oh=10, cost=12.5)
    _br(con, "1", oh=1, oo=1, units=6, cost=3.35)
    rows = _line_rows(con)
    assert rows == [{"Kind": "Conventional", "Franchise": "MC", "PartNumber": "P1", "FromBranch": "9", "ToBranch": "1",
                     "Seq": 1, "Qty": 4, "FromCost": 12.5, "ToCost": 3.35, "Value": 13.4, "FromOnHand": 10,
                     "FromExcessKeep": 0, "FromFreeExcess": 10, "ToOnHand": 1, "ToOnOrder": 1, "ToTarget": 6,
                     "ToNeed": 4, "ToRate": 0.5}]
    assert [c for c, _ in chk.SUGGESTION_COLS] == list(rows[0])


def test_value_is_qty_times_receiver_cost_to_cents():
    con = _con()
    _simple_rule(con)
    _br(con, "9", oh=10, cost=1)
    _br(con, "1", oh=0, units=3, cost=3.35)        # 3 x 3.35 = 10.049999999999999 -> 10.05
    assert _line_rows(con)[0]["Value"] == 10.05


def test_redistribution_to_need_is_the_room():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "8", oh=2)
    _br(con, "9", oh=1)
    _br(con, "1", oh=2, units=12)                  # room 4
    rows = _line_rows(con)
    assert [(r["FromBranch"], r["Qty"], r["ToNeed"]) for r in rows] == [("8", 2, 4), ("9", 1, 4)]


def test_suggested_quantities_per_part():
    con = _con()
    _simple_rule(con, woc=4)
    _br(con, "9", oh=10)
    _br(con, "1", oh=0, units=26)                  # 2 conventional + 8 redistribution
    _br(con, "2", oh=2, units=12)
    r = _run(con)
    got = {b: (r[K("P1", b)]["SuggestedInQty"], r[K("P1", b)]["SuggestedConvInQty"], r[K("P1", b)]["SuggestedOutQty"])
           for b in ("9", "1", "2")}
    assert got == {"9": (0, 0, 10), "1": (10, 2, 0), "2": (0, 0, 0)}


def test_parts_without_suggestions_have_zero_suggested():
    con = _con()
    _part(con, "P1")
    r = _run(con)[K("P1")]
    assert (r["SuggestedInQty"], r["SuggestedConvInQty"], r["SuggestedOutQty"]) == (0, 0, 0)


def test_insert_order_does_not_change_the_result():
    def build(order):
        con = _con()
        _simple_rule(con, woc=4)
        specs = [("9", dict(oh=10)), ("8", dict(oh=7, units=1)), ("1", dict(oh=0, units=26)),
                 ("2", dict(oh=2, units=12)), ("10", dict(oh=1, units=12)), ("3", dict(oh=0, units=12))]
        for i in order:
            _br(con, specs[i][0], **specs[i][1])
        return _line_rows(con)
    want = build(range(6))
    assert len(want) >= 4
    rng = random.Random(3)
    for _ in range(5):
        order = list(range(6))
        rng.shuffle(order)
        assert build(order) == want


def test_excluded_branches_never_send_or_receive():
    con = _con()
    _simple_rule(con)
    _br(con, "12", oh=50)
    _br(con, "4B", oh=0, units=6)
    _br(con, "1", oh=0, units=6)
    assert _lines(con) == []


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
    for col in ("SLC", "Source", "VendorCode", "ProductGroup", "CommodityCode"):
        con.execute(f"ALTER TABLE order_rules_src DROP COLUMN {col}")
    for col in ("ManualOrder", "MaskedOn", "PhaseInQty", "PhaseInEnds", "PhaseInOn"):
        con.execute(f"ALTER TABLE settings_src DROP COLUMN {col}")
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
    assert r[K("P1")]["PhaseInQty"] is None and r[K("P1")]["PhaseInActive"] is False


def test_rule_and_settings_columns_include_round_2():
    assert chk.RULE_COLS[1] == {"MinDemands": "DOUBLE", "SupplyUnit": "VARCHAR", "MinLineValue": "DOUBLE",
                                "MaxLineValue": "DOUBLE", "Archived": "BOOLEAN", "SLC": "VARCHAR",
                                "Source": "VARCHAR", "VendorCode": "VARCHAR", "ProductGroup": "VARCHAR",
                                "CommodityCode": "VARCHAR"}
    assert chk.SETTINGS_COLS[1] == {"ManualOrder": "BOOLEAN", "MaskedOn": "DATE", "PhaseInQty": "DOUBLE",
                                    "PhaseInEnds": "DATE", "PhaseInOn": "DATE"}


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
            ("Status", "VARCHAR"), ("PendingQty", "DOUBLE"), ("SLC", "VARCHAR"), ("Source", "VARCHAR"),
            ("CommodityCode", "VARCHAR"), ("PhaseInQty", "INTEGER"), ("PhaseInEnds", "DATE"), ("PhaseInOn", "DATE"),
            ("PhaseInActive", "BOOLEAN"), ("PhaseInEndReason", "VARCHAR"), ("AppInboundQty", "INTEGER"),
            ("AppOutboundQty", "INTEGER"), ("TransferRuleId", "BIGINT"), ("TransferRuleName", "VARCHAR"),
            ("ExcessSupply", "DOUBLE"), ("ExcessUnit", "VARCHAR"), ("AllowSend", "BOOLEAN"),
            ("AllowReceive", "BOOLEAN"), ("RedistMax", "DOUBLE"), ("RedistUnit", "VARCHAR"),
            ("RedistMinValue", "DOUBLE"), ("ExcessKeep", "INTEGER"), ("FreeExcess", "INTEGER"),
            ("ConvNeed", "INTEGER"), ("RedistCap", "INTEGER"), ("RedistEligible", "BOOLEAN"),
            ("SuggestedInQty", "INTEGER"), ("SuggestedConvInQty", "INTEGER"), ("SuggestedOutQty", "INTEGER")]
BASE = dict(Branch="1", Franchise="MC", PartNumber="A", RuleId=1, RuleName="Default", DemandBasis="UnitsSold",
            HistoryMonths=12, MinDemands=3, SupplyUnit="Weeks", Supply=12.0, SupplyMonths=12 * 12 / 52,
            MinLineValue=10.0, MaxLineValue=500.0, WindowDemand=3.0, UnitsSoldWindow=3.0, DemandCount=4, ActiveMonths=2,
            MonthlyRate=0.25, CalcTarget=1, EffectiveMin=0.0, MinimumNoDemand=False, StockingTarget=2,
            ValueCapped=False, BelowMinValue=False, ManualOrder=False, MaskedOn=date(2026, 10, 5), IsMasked=False,
            RecommendedOrderQty=1, SurplusQty=0, InboundTransferQty=0.0, Status="Reorder",
            PendingQty=1.0, SLC="00", Source="500", CommodityCode=None, PhaseInQty=5,
            PhaseInEnds=date(2027, 10, 1), PhaseInOn=date(2026, 10, 1), PhaseInActive=True, PhaseInEndReason=None,
            AppInboundQty=2, AppOutboundQty=0, TransferRuleId=None, TransferRuleName="Built-in default",
            ExcessSupply=12.0, ExcessUnit="Months", AllowSend=True, AllowReceive=True, RedistMax=6.0,
            RedistUnit="Months", RedistMinValue=0.0, ExcessKeep=2, FreeExcess=0, ConvNeed=1, RedistCap=1,
            RedistEligible=True, SuggestedInQty=1, SuggestedConvInQty=1, SuggestedOutQty=0)


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
    ("PendingQty", 2.0), ("PendingQty", None), ("SLC", "00 "), ("SLC", None), ("Source", "AL"), ("Source", None),
    ("CommodityCode", "X"), ("PhaseInQty", 6), ("PhaseInQty", None), ("PhaseInEnds", date(2027, 10, 2)),
    ("PhaseInEnds", None), ("PhaseInOn", date(2026, 10, 2)), ("PhaseInOn", None), ("PhaseInActive", False),
    ("PhaseInActive", None), ("PhaseInEndReason", "Expired"), ("AppInboundQty", 3), ("AppInboundQty", None),
    ("AppOutboundQty", 1), ("AppOutboundQty", None),
    ("TransferRuleId", 3), ("TransferRuleName", "Cotton"), ("ExcessSupply", 24.0), ("ExcessSupply", None),
    ("ExcessUnit", "Weeks"), ("AllowSend", False), ("AllowReceive", None), ("RedistMax", 0.0),
    ("RedistUnit", "Weeks"), ("RedistMinValue", 25.0), ("ExcessKeep", 3), ("FreeExcess", 1), ("ConvNeed", 0),
    ("RedistCap", None), ("RedistEligible", False), ("SuggestedInQty", 0), ("SuggestedConvInQty", 0),
    ("SuggestedOutQty", 2),
])
def test_compare_flags_each_compared_column(col, value):
    r = _cmp([{}], [{col: value}])
    assert (r["only_gold"], r["only_expected"], r["different"]) == (0, 0, 1)


@pytest.mark.parametrize("col", ["Supply", "SupplyMonths", "MinLineValue", "MaxLineValue", "WindowDemand",
                                 "UnitsSoldWindow", "MonthlyRate", "EffectiveMin", "InboundTransferQty",
                                 "PendingQty", "ExcessSupply", "RedistMax", "RedistMinValue"])
def test_compare_tolerates_tiny_float_differences(col):
    r = _cmp([{}], [{col: BASE[col] + 1e-9}])
    assert r["different"] == 0


def test_compare_limited_to_columns_ignores_the_others():
    con = duckdb.connect()
    ddl = ", ".join(f"{c} {t}" for c, t in CMP_COLS)
    marks = ", ".join("?" for _ in CMP_COLS)
    for name, row in (("gold", {}), ("expected", {"PhaseInQty": 9, "PendingQty": 7.0})):
        con.execute(f"CREATE TABLE {name} ({ddl})")
        con.execute(f"INSERT INTO {name} VALUES ({marks})", [{**BASE, **row}[c] for c, _ in CMP_COLS])
    shared = [c for c, _ in CMP_COLS if c not in ("PhaseInQty", "PendingQty")]
    assert chk.compare(con, "gold", "expected", shared)["different"] == 0
    assert chk.compare(con, "gold", "expected")["different"] == 1
    assert chk.compare(con, "gold", "expected", ["Branch", "Franchise", "PartNumber"])["different"] == 0


# ---------------------------------------------------------------------------------------------------------
# compare_suggestions()
# ---------------------------------------------------------------------------------------------------------
S_BASE = dict(Kind="Conventional", Franchise="MC", PartNumber="A", FromBranch="92", ToBranch="1", Seq=1, Qty=4,
              FromCost=12.5, ToCost=12.5, Value=50.0, FromOnHand=30, FromExcessKeep=12, FromFreeExcess=18,
              ToOnHand=0, ToOnOrder=0, ToTarget=6, ToNeed=6, ToRate=0.5)


def _scmp(gold_rows, exp_rows, gold_cols=None):
    con = duckdb.connect()
    for name, rows in (("gold_s", gold_rows), ("exp_s", exp_rows)):
        cols = [(c, t) for c, t in chk.SUGGESTION_COLS if name == "exp_s" or gold_cols is None or c in gold_cols]
        con.execute(f"CREATE TABLE {name} (" + ", ".join(f"{c} {t}" for c, t in cols) + ")")
        for row in rows:
            con.execute(f"INSERT INTO {name} VALUES ({', '.join('?' for _ in cols)})",
                        [{**S_BASE, **row}[c] for c, _ in cols])
    return chk.compare_suggestions(con, "gold_s", "exp_s",
                                   None if gold_cols is None else [c for c, _ in chk.SUGGESTION_COLS if c in gold_cols])


def test_suggestion_compare_covers_every_column():
    keys = ["Kind", "Franchise", "PartNumber", "FromBranch", "ToBranch"]
    assert [c for c, _ in chk.SUGGESTION_COLS][:5] == keys
    assert set(chk.SUGGESTION_EXACT) | set(chk.SUGGESTION_TOLERANCE) == {c for c, _ in chk.SUGGESTION_COLS} - set(keys)
    assert not set(chk.SUGGESTION_EXACT) & set(chk.SUGGESTION_TOLERANCE)
    assert set(chk.SUGGESTION_TOLERANCE) == {"FromCost", "ToCost", "Value", "ToRate"}


def test_suggestion_compare_identical_and_empty():
    zero = {"only_gold": 0, "only_expected": 0, "different": 0, "dup_gold": 0, "dup_expected": 0}
    assert _scmp([{}], [{}]) == zero
    assert _scmp([], []) == zero


def test_suggestion_compare_counts_missing_keys_and_duplicates():
    r = _scmp([{}, {"Kind": "Redistribution"}], [{}, {"ToBranch": "2"}])
    assert (r["only_gold"], r["only_expected"], r["different"]) == (1, 1, 0)
    assert _scmp([{}, {}], [{}])["dup_gold"] == 1


@pytest.mark.parametrize("col,value", [
    ("Seq", 2), ("Qty", 5), ("FromOnHand", 31), ("FromExcessKeep", 11), ("FromFreeExcess", None), ("ToOnHand", 1),
    ("ToOnOrder", 2), ("ToTarget", 7), ("ToNeed", 5), ("FromCost", 12.51), ("ToCost", None), ("Value", 50.01),
    ("ToRate", 0.6),
])
def test_suggestion_compare_flags_each_column(col, value):
    assert _scmp([{}], [{col: value}])["different"] == 1


@pytest.mark.parametrize("col", ["FromCost", "ToCost", "Value", "ToRate"])
def test_suggestion_compare_tolerates_tiny_float_differences(col):
    assert _scmp([{}], [{col: S_BASE[col] + 1e-9}])["different"] == 0


def test_suggestion_compare_limited_to_gold_columns():
    gold_cols = [c for c, _ in chk.SUGGESTION_COLS if c not in ("ToRate", "ToNeed")]
    assert _scmp([{}], [{"ToRate": 9.0, "ToNeed": 9}], gold_cols=gold_cols)["different"] == 0


def test_transfer_rule_columns():
    assert chk.TRANSFER_RULE_COLS == {
        "Id": "BIGINT", "RuleName": "VARCHAR", "Priority": "DOUBLE", "Active": "BOOLEAN", "Archived": "BOOLEAN",
        "Franchise": "VARCHAR", "DealerGroupCode": "VARCHAR", "Branch": "VARCHAR", "SLC": "VARCHAR",
        "Source": "VARCHAR", "VendorCode": "VARCHAR", "ProductGroup": "VARCHAR", "CommodityCode": "VARCHAR",
        "StartMonth": "DOUBLE", "EndMonth": "DOUBLE", "ExcessSupply": "DOUBLE", "ExcessUnit": "VARCHAR",
        "AllowSend": "BOOLEAN", "AllowReceive": "BOOLEAN", "RedistMax": "DOUBLE", "RedistUnit": "VARCHAR",
        "RedistMinValue": "DOUBLE"}
