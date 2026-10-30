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
    "RecommendedOrderQty", "EstOrderValue", "SurplusQty", "InboundTransferQty", "Status",
    # round 2 (Build_Gold_NonJD_Reorder, fabric-workspace-docs ba56d111)
    "PendingQty", "SLC", "Source", "CommodityCode", "PhaseInQty", "PhaseInEnds", "PhaseInOn", "PhaseInActive",
    "PhaseInEndReason", "AppInboundQty", "AppOutboundQty", "TransferRuleId", "TransferRuleName", "ExcessSupply",
    "ExcessUnit", "AllowSend", "AllowReceive", "RedistMax", "RedistUnit", "RedistMinValue", "ExcessKeep",
    "FreeExcess", "ConvNeed", "RedistCap", "RedistEligible", "SuggestedInQty", "SuggestedConvInQty",
    "SuggestedOutQty",
    # round 3 (Plan I1, Build_Gold_NonJD_Reorder on Dev)
    "LastReceived", "BuiltAtUtc"]
ROUND2_FIELDS = {"pendingQty", "slc", "source", "commodityCode", "phaseInQty", "phaseInEnds", "phaseInOn",
                 "phaseInActive", "phaseInEndReason", "appInboundQty", "appOutboundQty", "transferRuleId",
                 "transferRuleName", "excessSupply", "excessUnit", "allowSend", "allowReceive", "redistMax",
                 "redistUnit", "redistMinValue", "excessKeep", "freeExcess", "convNeed", "redistCap",
                 "redistEligible", "suggestedInQty", "suggestedConvInQty", "suggestedOutQty"}
RULE_COLS = ["Id", "RuleName", "Priority", "Active", "Franchise", "DealerGroupCode", "Branch", "StartMonth",
             "EndMonth", "HistoryMonths", "MinActiveMonths", "WeeksOfCover", "DemandBasis", "Modified", "MinDemands",
             "SupplyUnit", "MinLineValue", "MaxLineValue", "Archived", "SLC", "Source", "VendorCode", "ProductGroup",
             "CommodityCode"]
# Staging columns in Dev (df_NonJD_TransferRules_Raw / df_NonJD_Transfers_Raw, E1) and Gold's suggestion table (E5).
TRULE_COLS = ["Id", "RuleName", "Priority", "Active", "Archived", "Franchise", "DealerGroupCode", "Branch", "SLC",
              "Source", "VendorCode", "ProductGroup", "CommodityCode", "StartMonth", "EndMonth", "ExcessSupply",
              "ExcessUnit", "AllowSend", "AllowReceive", "RedistMax", "RedistUnit", "RedistMinValue", "Modified"]
APP_TRANSFER_COLS = ["TransferId", "Status", "PlacedAt", "FromBranch", "ToBranch", "LineId", "Franchise",
                     "PartNumber", "Qty", "Kind", "Created"]
SUGGESTION_COLS = ["Kind", "Franchise", "PartNumber", "FromBranch", "ToBranch", "Seq", "Qty", "FromCost", "ToCost",
                   "Value", "FromOnHand", "FromExcessKeep", "FromFreeExcess", "ToOnHand", "ToOnOrder", "ToTarget",
                   "ToNeed", "ToRate", "FromBin", "ToBin", "Description", "BuiltAtUtc"]
PURCHASES_COLS = ["Branch", "Franchise", "Purchases12", "BuiltAtUtc"]


@pytest.fixture
def con(monkeypatch):
    c = duckdb.connect()
    monkeypatch.setattr(extract, "_src", lambda table: f'"{table}"')
    return c


def _table(con, name, cols, rows=()):
    con.execute(f'CREATE TABLE "{name}" ({", ".join(f"{c} VARCHAR" for c in cols)})')
    for r in rows:
        con.execute(f'INSERT INTO "{name}" VALUES ({", ".join("?" for _ in cols)})', list(r))


def _gold_tables(con, reorder_cols=GOLD_REORDER, rule_cols=RULE_COLS, trule_cols=TRULE_COLS,
                 app_cols=APP_TRANSFER_COLS, sugg_cols=SUGGESTION_COLS, purchases_cols=PURCHASES_COLS):
    _table(con, "Fact_NonJD_Reorder", reorder_cols)
    _table(con, "NonJD_OrderRules", rule_cols)
    _table(con, "NonJD_TransferRules", trule_cols)
    _table(con, "NonJD_Transfers", app_cols)
    _table(con, "Fact_NonJD_TransferSuggestion", sugg_cols)
    _table(con, "Fact_NonJD_Purchases", purchases_cols)
    _table(con, "Fact_NonJD_SalesHistory", ["Branch", "Franchise", "PartNumber", "MonthOffset", "MonthStart",
                                            "SalesQty", "RequestCount"])
    _table(con, "Fact_OutstandingTransfers", ["RequestingBranch", "SupplyingBranch", "PartNumber", "PartTicket",
                                              "LineNumber", "OrderQty", "ShippedQty", "OpenQty", "FulfillmentStatus",
                                              "TransferSubType", "OrderAge", "Date"])


def test_reorder_columns_cover_gold_except_ruleid_and_builtat():
    gold = [g for g, _ in extract.REORDER_COLUMNS]
    assert sorted(gold) == sorted(c for c in GOLD_REORDER if c not in ("RuleId", "BuiltAtUtc"))
    fields = [f for _, f in extract.REORDER_COLUMNS]
    assert len(fields) == len(set(fields)) == 83
    assert ROUND2_FIELDS <= set(fields)


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
    assert len(rows[0]) == 83
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
                             "branch", "slc", "source", "vendorCode", "productGroup", "commodityCode",
                             "startMonth", "endMonth", "historyMonths", "minDemands", "weeksOfCover",
                             "supplyUnit", "minLineValue", "maxLineValue", "demandBasis"}
    assert rules[0]["minDemands"] == "3" and rules[0]["archived"] is None


def test_check_columns_names_missing_rules_columns(con):
    _gold_tables(con, rule_cols=[c for c in RULE_COLS if c not in ("Archived", "MinDemands")])
    with pytest.raises(pl.MissingColumnsError) as ei:
        extract.check_columns(con)
    assert "NonJD_OrderRules" in str(ei.value) and "Archived" in str(ei.value) and "MinDemands" in str(ei.value)


def test_check_columns_missing_rules_table_is_clear_error(con):
    _gold_tables(con)
    con.execute('DROP TABLE "NonJD_OrderRules"')
    with pytest.raises(RuntimeError, match="NonJD_OrderRules not found or unreadable") as ei:
        extract.check_columns(con)
    assert not isinstance(ei.value, pl.MissingColumnsError)


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


# ---- Round 2 (Plan E6): new reorder columns, transfer rules, suggestions, committed transfer lines ----

def test_round2_reorder_field_names():
    m = dict(extract.REORDER_COLUMNS)
    assert (m["SLC"], m["TransferRuleId"], m["PhaseInEndReason"]) == ("slc", "transferRuleId", "phaseInEndReason")
    assert (m["SuggestedConvInQty"], m["RedistMinValue"]) == ("suggestedConvInQty", "redistMinValue")


def test_reorder_reads_round2_fields(con):
    _gold_tables(con)
    con.execute('INSERT INTO "Fact_NonJD_Reorder" (Branch, Franchise, PartNumber, SLC, Source, TransferRuleName) '
                "VALUES ('1', 'A', 'P1', 'X1', 'S', 'Built-in default')")
    row = extract.reorder(con)[0]
    assert (row["slc"], row["source"], row["transferRuleName"]) == ("X1", "S", "Built-in default")


@pytest.mark.parametrize("missing", ["PhaseInQty", "TransferRuleId", "SuggestedOutQty", "FreeExcess"])
def test_check_columns_names_missing_round2_column(con, missing):
    _gold_tables(con, reorder_cols=[c for c in GOLD_REORDER if c != missing])
    with pytest.raises(pl.MissingColumnsError, match=f"Fact_NonJD_Reorder.*{missing}"):
        extract.check_columns(con)


@pytest.mark.parametrize("missing", ["SLC", "CommodityCode"])
def test_check_columns_names_missing_rule_criteria(con, missing):
    _gold_tables(con, rule_cols=[c for c in RULE_COLS if c != missing])
    with pytest.raises(pl.MissingColumnsError, match=f"NonJD_OrderRules.*{missing}"):
        extract.check_columns(con)


@pytest.mark.parametrize("table,kw,missing", [
    ("NonJD_TransferRules", "trule_cols", "RedistMinValue"),
    ("NonJD_Transfers", "app_cols", "PlacedAt"),
    ("Fact_NonJD_TransferSuggestion", "sugg_cols", "ToBin")])
def test_check_columns_names_missing_transfer_columns(con, table, kw, missing):
    cols = {"trule_cols": TRULE_COLS, "app_cols": APP_TRANSFER_COLS, "sugg_cols": SUGGESTION_COLS}[kw]
    _gold_tables(con, **{kw: [c for c in cols if c != missing]})
    with pytest.raises(pl.MissingColumnsError, match=f"{table}.*{missing}"):
        extract.check_columns(con)


@pytest.mark.parametrize("table", ["NonJD_TransferRules", "NonJD_Transfers", "Fact_NonJD_TransferSuggestion"])
def test_check_columns_missing_transfer_table_is_clear_error(con, table):
    _gold_tables(con)
    con.execute(f'DROP TABLE "{table}"')
    with pytest.raises(RuntimeError, match=f"{table} not found or unreadable") as ei:
        extract.check_columns(con)
    assert not isinstance(ei.value, pl.MissingColumnsError)


def test_transfer_rules_read_every_gold_column_by_id(con):
    _gold_tables(con)
    con.execute('INSERT INTO "NonJD_TransferRules" (Id, RuleName, ExcessSupply, ExcessUnit, Modified) VALUES '
                "('7', 'B', '12', 'Months', 'x'), ('3', 'A', '8', 'Weeks', 'y')")
    rows = extract.transfer_rules(con)
    assert [r["id"] for r in rows] == ["3", "7"]
    assert set(rows[0]) == {"id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode",
                            "branch", "slc", "source", "vendorCode", "productGroup", "commodityCode", "startMonth",
                            "endMonth", "excessSupply", "excessUnit", "allowSend", "allowReceive", "redistMax",
                            "redistUnit", "redistMinValue"}
    assert rows[0]["excessUnit"] == "Weeks" and rows[0]["excessSupply"] == "8"


def test_suggestions_read_contract_fields_in_group_order(con):
    _gold_tables(con)
    for kind, fr, pn, fb, tb, seq in [("Redistribution", "MC", "P2", "1", "7", 2),
                                      ("Conventional", "MC", "P2", "3", "7", 1),
                                      ("Conventional", "AB", "P9", "1", "2", 1)]:
        con.execute('INSERT INTO "Fact_NonJD_TransferSuggestion" (Kind, Franchise, PartNumber, FromBranch, ToBranch, '
                    "Seq, Qty, ToNeed) VALUES (?, ?, ?, ?, ?, ?, '1', '5')", [kind, fr, pn, fb, tb, str(seq)])
    rows = extract.suggestions(con)
    assert [(r["franchise"], r["partNumber"], r["seq"]) for r in rows] == [("AB", "P9", "1"), ("MC", "P2", "1"),
                                                                           ("MC", "P2", "2")]
    assert set(rows[0]) == {"kind", "franchise", "partNumber", "fromBranch", "toBranch", "seq", "qty", "fromCost",
                            "toCost", "value", "description", "fromBin", "toBin"}


def test_committed_reads_the_lines_gold_counts(con):
    from datetime import date
    _gold_tables(con)
    con.execute('DROP TABLE "NonJD_Transfers"')
    con.execute('CREATE TABLE "NonJD_Transfers" (TransferId BIGINT, Status VARCHAR, PlacedAt TIMESTAMPTZ, '
                "FromBranch VARCHAR, ToBranch VARCHAR, LineId BIGINT, Franchise VARCHAR, PartNumber VARCHAR, "
                "Qty DOUBLE, Kind VARCHAR, Created TIMESTAMPTZ)")
    con.execute("""INSERT INTO "NonJD_Transfers" VALUES
        (2, 'Draft', NULL, '1', '92', 5, 'MC', 'P1 ', 2.0, 'Conventional', NULL),
        (1, 'Placed', '2026-10-27 05:00:00+00', '3', '1', 4, 'MC', 'P2', 1.5, 'Redistribution', NULL),
        (1, 'Placed', '2026-10-27 04:59:00+00', '3', '1', 3, 'MC', 'P3', 1.0, 'Conventional', NULL),
        (3, 'Exported', NULL, '12', '1', 1, 'MC', 'P1', 1.0, 'Conventional', NULL),
        (4, 'Cancelled', NULL, '1', '2', 1, 'MC', 'P1', 1.0, 'Conventional', NULL)""")
    rows = extract.committed(con, date(2026, 10, 27))
    assert [(r["transferId"], r["lineId"]) for r in rows] == [(1, 4), (2, 5)]
    assert set(rows[0]) == {"transferId", "lineId", "status", "placedAt", "fromBranch", "toBranch", "franchise",
                            "partNumber", "qty"}
    assert rows[1]["partNumber"] == "P1 " and rows[0]["qty"] == 1.5


# ---- Round 3 (Plan I3): contract v4, lastReceived and Fact_NonJD_Purchases ----

def test_reorder_columns_end_with_last_received():
    assert extract.REORDER_COLUMNS[-1] == ("LastReceived", "lastReceived")


def test_reorder_reads_last_received_as_a_date(con):
    _gold_tables(con, reorder_cols=[c for c in GOLD_REORDER if c != "LastReceived"])
    con.execute('ALTER TABLE "Fact_NonJD_Reorder" ADD COLUMN LastReceived DATE')
    con.execute('INSERT INTO "Fact_NonJD_Reorder" (Branch, Franchise, PartNumber, LastReceived) '
                "VALUES ('1', 'A', 'P1', DATE '2026-09-14'), ('1', 'A', 'P2', NULL)")
    from datetime import date
    rows = extract.reorder(con)
    assert [r["lastReceived"] for r in rows] == [date(2026, 9, 14), None]


def test_check_columns_names_missing_last_received(con):
    _gold_tables(con, reorder_cols=[c for c in GOLD_REORDER if c != "LastReceived"])
    with pytest.raises(pl.MissingColumnsError, match="Fact_NonJD_Reorder.*LastReceived"):
        extract.check_columns(con)


def test_check_columns_missing_purchases_table_is_clear_error(con):
    _gold_tables(con)
    con.execute('DROP TABLE "Fact_NonJD_Purchases"')
    with pytest.raises(RuntimeError, match="Fact_NonJD_Purchases not found or unreadable.*round 3") as ei:
        extract.check_columns(con)
    assert not isinstance(ei.value, pl.MissingColumnsError)


def test_check_columns_names_missing_purchases_column(con):
    _gold_tables(con, purchases_cols=["Branch", "Franchise", "BuiltAtUtc"])
    with pytest.raises(pl.MissingColumnsError, match="Fact_NonJD_Purchases.*Purchases12"):
        extract.check_columns(con)


def test_purchases_sorted_by_branch_then_franchise(con):
    _gold_tables(con)
    con.execute('DROP TABLE "Fact_NonJD_Purchases"')
    con.execute('CREATE TABLE "Fact_NonJD_Purchases" (Branch VARCHAR, Franchise VARCHAR, Purchases12 DOUBLE, '
                "BuiltAtUtc TIMESTAMP)")
    con.execute("""INSERT INTO "Fact_NonJD_Purchases" VALUES ('92', 'MC', 10.5, NULL), ('1', 'MC', 2.25, NULL),
                   ('1', 'AB', 1234.56, NULL)""")
    assert extract.purchases(con) == [{"branch": "1", "franchise": "AB", "purchases12": 1234.56},
                                      {"branch": "1", "franchise": "MC", "purchases12": 2.25},
                                      {"branch": "92", "franchise": "MC", "purchases12": 10.5}]
