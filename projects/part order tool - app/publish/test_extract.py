"""Tests for extract's SQL, run against in-memory DuckDB tables named like the Gold tables (no OneLake)."""
import duckdb
import pytest

import extract
import publish_logic as pl

# Gold's Fact_NonJD_Reorder output columns (Build_Gold_NonJD_Reorder round 1, fabric-workspace-docs 25bb5fc9).
GOLD_REORDER = [
    "Branch", "Franchise", "PartNumber", "Description", "Bin", "VendorCode", "DealerGroupCode", "ProductGroup",
    "SuperTo", "SuperFrom", "QuantityOnHand", "OnOrder", "BackOrderQty", "Cost", "SellPrice1", "ListPrice",
    "MinimumQty", "MaximumQty", "ReorderCode", "ActivityCode", "MinOverride", "ManualOrder", "IsMasked",
    "MaskExpires", "MaskedOn", "IsLowMargin", "Current12MoSales", "Previous12MoSales", "DateLastRequested",
    "RuleId", "RuleName", "DemandBasis", "HistoryMonths", "MinDemands", "SupplyUnit", "Supply", "SupplyMonths",
    "MinLineValue", "MaxLineValue", "WindowDemand", "UnitsSoldWindow", "DemandCount", "ActiveMonths", "MonthlyRate",
    "CalcTarget", "EffectiveMin", "MinimumNoDemand", "StockingTarget", "ValueCapped", "BelowMinValue",
    "RecommendedOrderQty", "EstOrderValue", "SurplusQty", "InboundTransferQty", "Status", "BuiltAtUtc"]
RULE_COLS = ["Id", "RuleName", "Priority", "Active", "Franchise", "DealerGroupCode", "Branch", "StartMonth",
             "EndMonth", "HistoryMonths", "MinActiveMonths", "WeeksOfCover", "DemandBasis", "Modified", "MinDemands",
             "SupplyUnit", "MinLineValue", "MaxLineValue", "Archived"]


@pytest.fixture
def con(monkeypatch):
    c = duckdb.connect()
    monkeypatch.setattr(extract, "_src", lambda table: f'"{table}"')
    return c


def _table(con, name, cols, rows=()):
    con.execute(f'CREATE TABLE "{name}" ({", ".join(f"{c} VARCHAR" for c in cols)})')
    for r in rows:
        con.execute(f'INSERT INTO "{name}" VALUES ({", ".join("?" for _ in cols)})', list(r))


def _gold_tables(con, reorder_cols=GOLD_REORDER, rule_cols=RULE_COLS):
    _table(con, "Fact_NonJD_Reorder", reorder_cols)
    _table(con, "NonJD_OrderRules", rule_cols)
    _table(con, "Fact_NonJD_SalesHistory", ["Branch", "Franchise", "PartNumber", "MonthOffset", "MonthStart",
                                            "SalesQty", "RequestCount"])
    _table(con, "Fact_OutstandingTransfers", ["RequestingBranch", "SupplyingBranch", "PartNumber", "PartTicket",
                                              "LineNumber", "OrderQty", "ShippedQty", "OpenQty", "FulfillmentStatus",
                                              "TransferSubType", "OrderAge", "Date"])


def test_reorder_columns_cover_gold_except_ruleid_and_builtat():
    gold = [g for g, _ in extract.REORDER_COLUMNS]
    assert sorted(gold) == sorted(c for c in GOLD_REORDER if c not in ("RuleId", "BuiltAtUtc"))
    fields = [f for _, f in extract.REORDER_COLUMNS]
    assert len(fields) == len(set(fields)) == 54


def test_reorder_field_names():
    m = dict(extract.REORDER_COLUMNS)
    assert m["MinimumNoDemand"] == "minimumNoDemand"
    assert m["MinDemands"] == "minDemands"
    assert (m["Supply"], m["SupplyUnit"], m["SupplyMonths"]) == ("supply", "supplyUnit", "supplyMonths")
    assert m["StockingTarget"] == "target" and m["RecommendedOrderQty"] == "recommendedQty"
    for gold, field in [("DemandCount", "demandCount"), ("UnitsSoldWindow", "unitsSoldWindow"),
                        ("MinLineValue", "minLineValue"), ("MaxLineValue", "maxLineValue"),
                        ("ValueCapped", "valueCapped"), ("BelowMinValue", "belowMinValue"),
                        ("ManualOrder", "manualOrder"), ("MaskedOn", "maskedOn")]:
        assert m[gold] == field
    assert not {"MinimumIgnored", "MinActiveMonths", "WeeksOfCover"} & set(m)


def test_reorder_reads_and_renames(con):
    _gold_tables(con)
    con.execute('INSERT INTO "Fact_NonJD_Reorder" (Branch, Franchise, PartNumber, MinDemands, SupplyUnit) '
                "VALUES ('92', 'A', 'P2', '3', 'Weeks'), ('1', 'A', 'P1', '2', 'Months')")
    rows = extract.reorder(con)
    assert [r["partNumber"] for r in rows] == ["P1", "P2"]
    assert len(rows[0]) == 54
    assert rows[0]["minDemands"] == "2" and rows[0]["supplyUnit"] == "Months"


def test_check_columns_passes_on_round1_gold(con):
    _gold_tables(con)
    extract.check_columns(con)


def test_check_columns_names_missing_reorder_columns(con):
    old = [c for c in GOLD_REORDER if c not in ("MinDemands", "SupplyUnit", "ManualOrder")] + [
        "MinActiveMonths", "WeeksOfCover", "MinimumIgnored"]
    _gold_tables(con, reorder_cols=old)
    with pytest.raises(pl.MissingColumnsError) as ei:
        extract.check_columns(con)
    msg = str(ei.value)
    assert "Fact_NonJD_Reorder" in msg
    assert "MinDemands" in msg and "SupplyUnit" in msg and "ManualOrder" in msg


def test_check_columns_covers_history_and_transfers(con):
    _gold_tables(con)
    con.execute('ALTER TABLE "Fact_OutstandingTransfers" DROP COLUMN OpenQty')
    with pytest.raises(pl.MissingColumnsError, match="Fact_OutstandingTransfers.*OpenQty"):
        extract.check_columns(con)


def test_rules_read_new_fields(con):
    _gold_tables(con)
    con.execute('INSERT INTO "NonJD_OrderRules" (Id, RuleName, MinDemands, SupplyUnit, MinLineValue, MaxLineValue, '
                "Archived, WeeksOfCover, MinActiveMonths) VALUES ('1', 'Default', '3', NULL, '10', '500', NULL, '12', '3')")
    rules = extract.rules(con)
    assert set(rules[0]) == {"id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode",
                             "branch", "startMonth", "endMonth", "historyMonths", "minDemands", "weeksOfCover",
                             "supplyUnit", "minLineValue", "maxLineValue", "demandBasis"}
    assert rules[0]["minDemands"] == "3" and rules[0]["archived"] is None


def test_rules_missing_new_columns_fail_naming_them(con):
    _gold_tables(con, rule_cols=[c for c in RULE_COLS if c not in ("Archived", "MinDemands")])
    with pytest.raises(pl.MissingColumnsError) as ei:
        extract.rules(con)
    assert "NonJD_OrderRules" in str(ei.value) and "Archived" in str(ei.value) and "MinDemands" in str(ei.value)


def test_transfers_drop_excluded_branches_both_ways(con):
    _gold_tables(con)
    con.execute('INSERT INTO "Fact_NonJD_Reorder" (Branch, Franchise, PartNumber) VALUES '
                "('1', 'A', 'p1 '), ('92', 'A', 'P2')")
    for i, (to, fr, pn) in enumerate([("1", "92", "P1"), ("12", "1", "P1"), ("1", "93C ", "P1"), ("4b", "92", "P2"),
                                      ("92", "5", "P2"), (" 97", "1", "P1"), ("", "1", "P2"), ("1", None, "P1"),
                                      ("1", "92", "OTHER")]):
        con.execute('INSERT INTO "Fact_OutstandingTransfers" (RequestingBranch, SupplyingBranch, PartNumber, '
                    "PartTicket, LineNumber) VALUES (?, ?, ?, ?, '1')", [to, fr, pn, f"T{i}"])
    assert sorted(t["ticket"] for t in extract.transfers(con)) == ["T0", "T6", "T7"]
