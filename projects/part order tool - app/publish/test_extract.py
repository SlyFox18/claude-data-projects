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
    "LastReceived",
    # round 3 phase 3 (Plan K1, Build_Gold_NonJD_Reorder on Dev, fabric-workspace-docs 863afe35)
    "EquipStockValue", "BuiltAtUtc"]
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
                 app_cols=APP_TRANSFER_COLS, sugg_cols=SUGGESTION_COLS, purchases_cols=PURCHASES_COLS,
                 jd_cols="all", idle_cols="all"):
    _table(con, "Fact_NonJD_Reorder", reorder_cols)
    if jd_cols is not None:        # None = an older Gold without Fact_CorpParts_JD (Plan L)
        _table(con, "Fact_CorpParts_JD", GOLD_JD if jd_cols == "all" else jd_cols)
    if idle_cols is not None:      # None = an older Gold without Fact_CorpParts_JD_Idle (Plan M)
        _table(con, "Fact_CorpParts_JD_Idle", GOLD_JD_IDLE if idle_cols == "all" else idle_cols)
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
    assert len(fields) == len(set(fields)) == 84
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
    assert len(rows[0]) == 84
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

def test_reorder_columns_include_last_received():
    assert ("LastReceived", "lastReceived") in extract.REORDER_COLUMNS


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


# ---- Round 3 phase 3 (Plan K3): contract v5, EquipStockValue ----

def test_reorder_columns_end_with_equip_stock_value():
    assert extract.REORDER_COLUMNS[-1] == ("EquipStockValue", "equipStockValue")


def test_reorder_reads_equip_stock_value(con):
    _gold_tables(con, reorder_cols=[c for c in GOLD_REORDER if c != "EquipStockValue"])
    con.execute('ALTER TABLE "Fact_NonJD_Reorder" ADD COLUMN EquipStockValue DECIMAL(18,2)')
    con.execute('INSERT INTO "Fact_NonJD_Reorder" (Branch, Franchise, PartNumber, EquipStockValue) '
                "VALUES ('1', 'A', 'P1', 123.45), ('1', 'A', 'P2', -7.10)")
    from decimal import Decimal
    rows = extract.reorder(con)
    assert [r["equipStockValue"] for r in rows] == [Decimal("123.45"), Decimal("-7.10")]


def test_check_columns_names_missing_equip_stock_value(con):
    # a round 3 phase 1 Gold (contract v4) has LastReceived but no EquipStockValue
    _gold_tables(con, reorder_cols=[c for c in GOLD_REORDER if c != "EquipStockValue"])
    with pytest.raises(pl.MissingColumnsError, match="Fact_NonJD_Reorder.*EquipStockValue"):
        extract.check_columns(con)


# ---- Plan L (L4): contract v6, Fact_CorpParts_JD ----

# Gold's Fact_CorpParts_JD columns (Build_Gold_NonJD_Reorder Part 5, fabric-workspace-docs 6e7e7dc4).
GOLD_JD = ["Branch", "Franchise", "PartNumber", "Description", "Cost", "OnHand", "OnOrder", "PackageQty",
           "ReturnIndicator", "Source", "SLC", "SuperTo", "CommodityCode", "CommodityGroup", "DealerGroupCode",
           "MinimumQty", "MaximumQty", "Sales12", "SalesPrev12", "CorpDemands", "BinQty", "PiecesInSet", "PisInvoices",
           "PisSalesQty", "PisQty", "PisQtyInvoices", "PisMultipleInvoices", "DemandAsOf", "BuiltAtUtc"]
JD_FIELDS = ["partNumber", "description", "cost", "onHand", "onOrder", "packageQty", "returnIndicator", "source",
             "slc", "superTo", "commodityCode", "commodityGroup", "dealerGroupCode", "minimumQty", "maximumQty",
             "sales12", "salesPrev12", "corpDemands", "binQty", "piecesInSet", "pisInvoices", "pisSalesQty", "pisQty",
             "pisQtyInvoices", "pisMultipleInvoices"]


def test_jd_columns_are_the_l_d18_and_plan_r_fields_plus_branch():
    assert extract.JD_COLUMNS[0] == ("Branch", "branch")
    assert [f for _, f in extract.JD_COLUMNS[1:]] == JD_FIELDS
    m = dict(extract.JD_COLUMNS)
    assert (m["Sales12"], m["SalesPrev12"], m["CorpDemands"]) == ("sales12", "salesPrev12", "corpDemands")
    assert {g for g, _ in extract.JD_COLUMNS} <= set(GOLD_JD)
    assert not {"Franchise", "DemandAsOf", "BuiltAtUtc"} & {g for g, _ in extract.JD_COLUMNS}


def test_jd_parts_reads_and_renames(con):
    _gold_tables(con)
    con.execute('INSERT INTO "Fact_CorpParts_JD" (Branch, Franchise, PartNumber, Description, CorpDemands, '
                "PackageQty) VALUES ('2', 'D', 'B1', 'Bolt', '2', NULL), ('1', 'D', 'A2 ', NULL, '0', '1.00'), "
                "('1', 'D', 'A1', 'Nut', '3', '2.00')")
    rows = extract.jd_parts(con)
    assert [(r["branch"], r["partNumber"]) for r in rows] == [("1", "A1"), ("1", "A2 "), ("2", "B1")]
    assert set(rows[0]) == {"branch"} | set(JD_FIELDS)
    assert rows[1]["description"] is None and rows[2]["packageQty"] is None and rows[0]["corpDemands"] == "3"


def test_check_columns_passes_with_the_jd_table(con):
    _gold_tables(con)
    extract.check_columns(con)


@pytest.mark.parametrize("missing", ["CorpDemands", "PackageQty", "CommodityGroup", "BuiltAtUtc"])
def test_check_columns_names_missing_jd_column(con, missing):
    _gold_tables(con, jd_cols=[c for c in GOLD_JD if c != missing])
    with pytest.raises(pl.MissingColumnsError, match=f"Fact_CorpParts_JD.*{missing}"):
        extract.check_columns(con)


@pytest.mark.parametrize("missing", ["BinQty", "PiecesInSet", "PisInvoices", "PisSalesQty", "PisQty", "PisQtyInvoices",
                                     "PisMultipleInvoices"])
def test_check_columns_v8_gold_without_plan_r_says_what_to_deploy(con, missing):
    _gold_tables(con, jd_cols=[c for c in GOLD_JD if c != missing])
    with pytest.raises(pl.MissingColumnsError, match=f"Fact_CorpParts_JD.*{missing}.*[Dd]eploy Plan R.*before publishing v9"):
        extract.check_columns(con)


def test_check_columns_missing_jd_table_is_clear_error(con):
    # an older Gold (before Plan L) has every other table but not Fact_CorpParts_JD
    _gold_tables(con, jd_cols=None)
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD not found or unreadable.*Plan L") as ei:
        extract.check_columns(con)
    assert not isinstance(ei.value, pl.MissingColumnsError)


def test_jd_built_at(con):
    _gold_tables(con)
    con.execute('INSERT INTO "Fact_CorpParts_JD" (Branch, PartNumber, BuiltAtUtc) VALUES '
                "('1', 'A', '2026-11-03 15:26:59'), ('2', 'B', '2026-11-03 15:26:59')")
    assert str(extract.jd_built_at(con)) == "2026-11-03 15:26:59"


# ---- Plan M (M3): contract v7, Fact_CorpParts_JD_Idle ----

# Gold's Fact_CorpParts_JD_Idle columns (Build_Gold_NonJD_Reorder Part 5, fabric-workspace-docs c5262e7f).
GOLD_JD_IDLE = ["Branch", "Franchise", "PartNumber", "Description", "Cost", "OnOrder", "PackageQty",
                "ReturnIndicator", "Source", "SLC", "SuperTo", "CommodityCode", "CommodityGroup", "DealerGroupCode",
                "MinimumQty", "MaximumQty", "BuiltAtUtc"]
JD_IDLE_FIELDS = ["partNumber", "description", "cost", "onOrder", "packageQty", "returnIndicator", "source", "slc",
                  "superTo", "commodityCode", "commodityGroup", "dealerGroupCode", "minimumQty", "maximumQty"]


def test_jd_idle_columns_are_the_m_d12_fields_plus_branch():
    assert extract.JD_IDLE_COLUMNS[0] == ("Branch", "branch")
    assert [f for _, f in extract.JD_IDLE_COLUMNS[1:]] == JD_IDLE_FIELDS
    assert {g for g, _ in extract.JD_IDLE_COLUMNS} <= set(GOLD_JD_IDLE)
    assert not {"Franchise", "BuiltAtUtc"} & {g for g, _ in extract.JD_IDLE_COLUMNS}
    # the same Gold column -> field names as the active table
    jd = dict(extract.JD_COLUMNS)
    assert all(jd[g] == f for g, f in extract.JD_IDLE_COLUMNS)


def test_jd_idle_parts_reads_and_renames(con):
    _gold_tables(con)
    con.execute('INSERT INTO "Fact_CorpParts_JD_Idle" (Branch, Franchise, PartNumber, Description, OnOrder, '
                "PackageQty) VALUES ('4', 'D', 'B1', 'Bolt', '-1.00', NULL), ('1', 'D', 'A2 ', NULL, '0.00', "
                "'1.00'), ('1', 'D', 'A1', 'Nut', '0.00', '2.00')")
    rows = extract.jd_idle_parts(con)
    assert [(r["branch"], r["partNumber"]) for r in rows] == [("1", "A1"), ("1", "A2 "), ("4", "B1")]
    assert set(rows[0]) == {"branch"} | set(JD_IDLE_FIELDS)
    assert rows[1]["description"] is None and rows[2]["packageQty"] is None and rows[2]["onOrder"] == "-1.00"


def test_check_columns_passes_with_the_idle_table(con):
    _gold_tables(con)
    extract.check_columns(con)


@pytest.mark.parametrize("missing", ["OnOrder", "PackageQty", "DealerGroupCode", "BuiltAtUtc"])
def test_check_columns_names_missing_idle_column(con, missing):
    _gold_tables(con, idle_cols=[c for c in GOLD_JD_IDLE if c != missing])
    with pytest.raises(pl.MissingColumnsError, match=f"Fact_CorpParts_JD_Idle.*{missing}"):
        extract.check_columns(con)


def test_check_columns_missing_idle_table_is_clear_error(con):
    # a Plan L Gold has every other table, Fact_CorpParts_JD included, but not Fact_CorpParts_JD_Idle
    _gold_tables(con, idle_cols=None)
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD_Idle not found or unreadable.*"
                                           "deploy Plan M.*before publishing v7") as ei:
        extract.check_columns(con)
    assert not isinstance(ei.value, pl.MissingColumnsError)


def test_check_columns_missing_jd_table_still_names_plan_l(con):
    _gold_tables(con, jd_cols=None, idle_cols=None)
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD not found or unreadable.*Plan L"):
        extract.check_columns(con)


def test_jd_idle_built_at(con):
    _gold_tables(con)
    con.execute('INSERT INTO "Fact_CorpParts_JD_Idle" (Branch, PartNumber, BuiltAtUtc) VALUES '
                "('1', 'A', '2026-11-03 15:26:59'), ('2', 'B', '2026-11-03 15:26:59')")
    assert str(extract.jd_idle_built_at(con)) == "2026-11-03 15:26:59"



# ---- Plan S (contract 9): the JD order files ----
JD_ORDER_GOLD = [c for c in GOLD_REORDER if c not in (
    "AppOutboundQty", "TransferRuleId", "TransferRuleName", "ExcessSupply", "ExcessUnit", "AllowSend",
    "AllowReceive", "RedistMax", "RedistUnit", "RedistMinValue", "ExcessKeep", "FreeExcess", "ConvNeed", "RedistCap",
    "RedistEligible", "SuggestedInQty", "SuggestedConvInQty", "SuggestedOutQty")]


def _jd_tables(con, reorder=JD_ORDER_GOLD, hist=True, rules=True):
    _table(con, "Fact_JD_Reorder", reorder)
    if hist:
        _table(con, "Fact_JD_SalesHistory", ["Branch", "Franchise", "PartNumber", "MonthStart", "MonthOffset", "SalesQty",
                                             "RequestCount"])
    if rules:
        _table(con, "JD_OrderRules", RULE_COLS)


def test_jd_order_columns_are_the_reorder_columns_without_the_transfer_ones():
    gold = [g for g, _ in extract.JD_ORDER_COLUMNS]
    assert sorted(gold) == sorted(c for c in JD_ORDER_GOLD if c not in ("RuleId", "BuiltAtUtc", "AppInboundQty"))
    fields = {f for _, f in extract.JD_ORDER_COLUMNS}
    assert not {"appInboundQty", "appOutboundQty", "transferRuleId", "suggestedOutQty"} & fields
    assert {"phaseInEndReason", "lastReceived", "equipStockValue", "status"} <= fields


def test_jd_order_available(con):
    assert extract.jd_order_available(con) is False                # nothing there yet
    _jd_tables(con, hist=False)
    assert extract.jd_order_available(con) is False                # no history table
    con.execute('DROP TABLE "Fact_JD_Reorder"')
    con.execute('DROP TABLE "JD_OrderRules"')
    _jd_tables(con, reorder=[c for c in JD_ORDER_GOLD if c != "EquipStockValue"])
    assert extract.jd_order_available(con) is False                # a column is missing
    con.execute('DROP TABLE "Fact_JD_Reorder"')
    con.execute('DROP TABLE "Fact_JD_SalesHistory"')
    con.execute('DROP TABLE "JD_OrderRules"')
    _jd_tables(con)
    assert extract.jd_order_available(con) is True


def test_jd_order_reads_jd_tables_and_ignores_non_jd(con):
    _gold_tables(con)
    _jd_tables(con)
    con.execute('INSERT INTO "Fact_NonJD_Reorder" (Branch, Franchise, PartNumber) VALUES (\'1\', \'A\', \'NOPE\')')
    con.execute('INSERT INTO "Fact_JD_Reorder" (Branch, Franchise, PartNumber, BuiltAtUtc) VALUES '
                "('12', 'D', 'B', '2026-11-06 12:00:00'), ('12', 'D', 'A', '2026-11-06 12:00:00')")
    rows = extract.jd_order(con)
    assert [r["partNumber"] for r in rows] == ["A", "B"]
    assert len(rows[0]) == len(extract.JD_ORDER_COLUMNS)
    assert str(extract.jd_order_built_at(con)) == "2026-11-06 12:00:00"


def test_jd_history_is_staged_apart_from_non_jd(con):
    _gold_tables(con)
    _jd_tables(con)
    con.execute('INSERT INTO "Fact_NonJD_SalesHistory" (Branch, Franchise, PartNumber, MonthOffset, SalesQty, RequestCount)'
                " VALUES ('1', 'A', 'N', '1', '9', '9')")
    con.execute('INSERT INTO "Fact_JD_SalesHistory" (Branch, Franchise, PartNumber, MonthOffset, SalesQty, RequestCount)'
                " VALUES ('12 ', 'D', 'J', '2', '3', '1')")
    assert extract.stage_history(con) == 1
    assert extract.stage_jd_history(con) == 1
    assert [r["partNumber"] for r in extract.history_for(con, "1")] == ["N"]
    assert extract.jd_history_for(con, "12") == [{"branch": "12", "franchise": "D", "partNumber": "J", "monthOffset": "2",
                                                  "salesQty": "3", "requestCount": "1"}]


def test_jd_rules_reads_its_own_list(con):
    _jd_tables(con)
    con.execute('INSERT INTO "JD_OrderRules" (Id, RuleName) VALUES (\'1\', \'Default\')')
    rows = extract.jd_rules(con)
    assert rows[0]["ruleName"] == "Default" and set(rows[0]) == {f for _, f in extract.RULE_COLUMNS}


def test_log_rows_includes_the_jd_item(con):
    con.execute("""CREATE TABLE dp_refresh_log (run_id VARCHAR, name VARCHAR, row_type VARCHAR, status VARCHAR,
                   start_utc TIMESTAMPTZ, end_utc TIMESTAMPTZ)""")
    con.execute("""INSERT INTO dp_refresh_log VALUES
        ('r', 'Build_Gold_JD_Reorder', 'item', 'Succeeded', NULL, now()),
        ('r', 'Build_Gold_NonJD_Reorder', 'item', 'Succeeded', NULL, now()),
        ('r', 'Build_Gold_Other', 'item', 'Succeeded', NULL, now())""")
    assert {r["name"] for r in extract.log_rows(con)} == {"Build_Gold_JD_Reorder", "Build_Gold_NonJD_Reorder"}


def test_check_columns_does_not_need_the_jd_tables(con):
    _gold_tables(con)                                               # S-P4: no Fact_JD_Reorder at all
    extract.check_columns(con)
