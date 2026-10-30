"""DuckDB reads of DP Gold for the publish script. Returns plain Python rows (dicts)."""
from datetime import datetime, timedelta, timezone

import os

import duckdb

import config
import publish_logic as pl

# Gold column -> published field (README "reorder_<branch>.json.gz"), in file order. Gold's RuleId and BuiltAtUtc
# are not published (TransferRuleId is, per plan E decision X6). check_columns() fails, naming them, if Gold lacks
# any of these.
REORDER_COLUMNS = [
    ("Branch", "branch"), ("Franchise", "franchise"), ("PartNumber", "partNumber"), ("Description", "description"),
    ("Bin", "bin"), ("VendorCode", "vendorCode"), ("ProductGroup", "productGroup"), ("SuperTo", "superTo"),
    ("SuperFrom", "superFrom"), ("QuantityOnHand", "onHand"), ("OnOrder", "onOrder"), ("BackOrderQty", "backOrder"),
    ("Cost", "cost"), ("SellPrice1", "sellPrice"), ("ListPrice", "listPrice"), ("MinimumQty", "minimumQty"),
    ("MaximumQty", "maximumQty"), ("ReorderCode", "reorderCode"), ("ActivityCode", "activityCode"),
    ("MinOverride", "minOverride"), ("ManualOrder", "manualOrder"), ("IsMasked", "isMasked"),
    ("MaskExpires", "maskExpires"), ("MaskedOn", "maskedOn"), ("IsLowMargin", "isLowMargin"),
    ("Current12MoSales", "sales12"), ("Previous12MoSales", "salesPrev12"), ("DateLastRequested", "lastRequested"),
    ("DealerGroupCode", "dealerGroupCode"), ("RuleName", "ruleName"), ("DemandBasis", "demandBasis"),
    ("HistoryMonths", "historyMonths"), ("MinDemands", "minDemands"), ("SupplyUnit", "supplyUnit"),
    ("Supply", "supply"), ("SupplyMonths", "supplyMonths"), ("MinLineValue", "minLineValue"),
    ("MaxLineValue", "maxLineValue"), ("WindowDemand", "windowDemand"), ("UnitsSoldWindow", "unitsSoldWindow"),
    ("DemandCount", "demandCount"), ("ActiveMonths", "activeMonths"), ("MonthlyRate", "monthlyRate"),
    ("CalcTarget", "calcTarget"), ("EffectiveMin", "effectiveMin"), ("MinimumNoDemand", "minimumNoDemand"),
    ("StockingTarget", "target"), ("ValueCapped", "valueCapped"), ("BelowMinValue", "belowMinValue"),
    ("RecommendedOrderQty", "recommendedQty"), ("EstOrderValue", "estValue"), ("SurplusQty", "surplusQty"),
    ("InboundTransferQty", "inboundQty"), ("Status", "status"),
    # round 2 (contract v3): Part 1 (phase-in, committed app transfers), Part 2 (transfer rule and inputs), Part 3
    ("PendingQty", "pendingQty"), ("SLC", "slc"), ("Source", "source"), ("CommodityCode", "commodityCode"),
    ("PhaseInQty", "phaseInQty"), ("PhaseInEnds", "phaseInEnds"), ("PhaseInOn", "phaseInOn"),
    ("PhaseInActive", "phaseInActive"), ("PhaseInEndReason", "phaseInEndReason"),
    ("AppInboundQty", "appInboundQty"), ("AppOutboundQty", "appOutboundQty"),
    ("TransferRuleId", "transferRuleId"), ("TransferRuleName", "transferRuleName"), ("ExcessSupply", "excessSupply"),
    ("ExcessUnit", "excessUnit"), ("AllowSend", "allowSend"), ("AllowReceive", "allowReceive"),
    ("RedistMax", "redistMax"), ("RedistUnit", "redistUnit"), ("RedistMinValue", "redistMinValue"),
    ("ExcessKeep", "excessKeep"), ("FreeExcess", "freeExcess"), ("ConvNeed", "convNeed"), ("RedistCap", "redistCap"),
    ("RedistEligible", "redistEligible"), ("SuggestedInQty", "suggestedInQty"),
    ("SuggestedConvInQty", "suggestedConvInQty"), ("SuggestedOutQty", "suggestedOutQty"),
    # round 3 (contract v4, Plan I): newest supplier receipt date (DATE; null = never received)
    ("LastReceived", "lastReceived"),
]
REORDER_SQL = ("SELECT " + ", ".join(f'{g} AS "{f}"' for g, f in REORDER_COLUMNS)
               + "\nFROM {src}\nORDER BY branch, franchise, partNumber")

# NonJD_OrderRules column -> rules.json field: exactly the columns Gold reads (MinActiveMonths is left in the list
# unused (D1) and Modified is not published).
RULE_COLUMNS = [
    ("Id", "id"), ("RuleName", "ruleName"), ("Priority", "priority"), ("Active", "active"), ("Archived", "archived"),
    ("Franchise", "franchise"), ("DealerGroupCode", "dealerGroupCode"), ("Branch", "branch"),
    ("SLC", "slc"), ("Source", "source"), ("VendorCode", "vendorCode"), ("ProductGroup", "productGroup"),
    ("CommodityCode", "commodityCode"),
    ("StartMonth", "startMonth"), ("EndMonth", "endMonth"), ("HistoryMonths", "historyMonths"),
    ("MinDemands", "minDemands"), ("WeeksOfCover", "weeksOfCover"), ("SupplyUnit", "supplyUnit"),
    ("MinLineValue", "minLineValue"), ("MaxLineValue", "maxLineValue"), ("DemandBasis", "demandBasis"),
]
# NonJD_TransferRules column -> transfer_rules.json field: every column Gold reads (Modified and Notes are not).
TRANSFER_RULE_COLUMNS = [
    ("Id", "id"), ("RuleName", "ruleName"), ("Priority", "priority"), ("Active", "active"), ("Archived", "archived"),
    ("Franchise", "franchise"), ("DealerGroupCode", "dealerGroupCode"), ("Branch", "branch"), ("SLC", "slc"),
    ("Source", "source"), ("VendorCode", "vendorCode"), ("ProductGroup", "productGroup"),
    ("CommodityCode", "commodityCode"), ("StartMonth", "startMonth"), ("EndMonth", "endMonth"),
    ("ExcessSupply", "excessSupply"), ("ExcessUnit", "excessUnit"), ("AllowSend", "allowSend"),
    ("AllowReceive", "allowReceive"), ("RedistMax", "redistMax"), ("RedistUnit", "redistUnit"),
    ("RedistMinValue", "redistMinValue"),
]
# Fact_NonJD_TransferSuggestion column -> transfer_suggestions.json "lines" field (the analysis columns, e.g.
# FromFreeExcess and ToNeed, stay in Gold).
SUGGESTION_COLUMNS = [
    ("Kind", "kind"), ("Franchise", "franchise"), ("PartNumber", "partNumber"), ("FromBranch", "fromBranch"),
    ("ToBranch", "toBranch"), ("Seq", "seq"), ("Qty", "qty"), ("FromCost", "fromCost"), ("ToCost", "toCost"),
    ("Value", "value"), ("Description", "description"), ("FromBin", "fromBin"), ("ToBin", "toBin"),
]
# NonJD_Transfers column -> transfer_suggestions.json "committed" field (the lines Gold counted in step 8b).
COMMITTED_COLUMNS = [
    ("TransferId", "transferId"), ("LineId", "lineId"), ("Status", "status"), ("PlacedAt", "placedAt"),
    ("FromBranch", "fromBranch"), ("ToBranch", "toBranch"), ("Franchise", "franchise"), ("PartNumber", "partNumber"),
    ("Qty", "qty"),
]
# Fact_NonJD_Purchases column -> purchases.json.gz "rows" field (round 3; BuiltAtUtc is not published).
PURCHASES_COLUMNS = [("Branch", "branch"), ("Franchise", "franchise"), ("Purchases12", "purchases12")]
HISTORY_COLUMNS = ["Branch", "Franchise", "PartNumber", "MonthOffset", "SalesQty", "RequestCount"]
TRANSFER_COLUMNS = ["RequestingBranch", "SupplyingBranch", "PartNumber", "PartTicket", "LineNumber", "OrderQty",
                    "ShippedQty", "OpenQty", "FulfillmentStatus", "TransferSubType", "OrderAge", "Date"]
_EXCLUDED_SQL = ", ".join(f"'{b}'" for b in pl.EXCLUDED_BRANCHES)


def _q(s: str) -> str:
    return s.replace("'", "''")


def connect():
    con = duckdb.connect()
    spill = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".duckdb_spill").replace("\\", "/")
    con.execute(f"SET memory_limit='3GB'; SET temp_directory='{_q(spill)}'; SET preserve_insertion_order=false;")
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
    if config.CLIENT_SECRET:
        con.execute(f"""CREATE SECRET (TYPE azure, PROVIDER service_principal, TENANT_ID '{_q(config.TENANT_ID)}',
                        CLIENT_ID '{_q(config.CLIENT_ID)}', CLIENT_SECRET '{_q(config.CLIENT_SECRET)}');""")
    else:
        con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    return con


def _src(table: str) -> str:
    """The FROM source of a DP_Presentation table (tests swap it for an in-memory table)."""
    return f"delta_scan('{_q(config.table_path(table))}')"


def columns(con, table: str) -> list:
    return [r[0] for r in con.execute(f"DESCRIBE SELECT * FROM {_src(table)}").fetchall()]


def _readable_columns(con, table: str, deploy: str) -> list:
    """columns(), with a clear error naming what to deploy when the table is missing or unreadable."""
    try:
        return columns(con, table)
    except Exception as ex:
        first = (str(ex).splitlines() or [""])[0]
        raise RuntimeError(f"{table} not found or unreadable in the {config.SOURCE} DP_Presentation "
                           f"lakehouse ({type(ex).__name__}: {first}); deploy {deploy} before publishing") from ex


def check_columns(con) -> None:
    """Fail before extracting, naming every missing column, if a Gold table lacks a column the publish reads
    (e.g. the publish is newer or older than the Gold notebook), including the list tables Gold reads."""
    pl.require_columns("Fact_NonJD_Reorder", columns(con, "Fact_NonJD_Reorder"),
                       [g for g, _ in REORDER_COLUMNS] + ["BuiltAtUtc"])
    pl.require_columns("Fact_NonJD_SalesHistory", columns(con, "Fact_NonJD_SalesHistory"), HISTORY_COLUMNS)
    pl.require_columns("Fact_OutstandingTransfers", columns(con, "Fact_OutstandingTransfers"), TRANSFER_COLUMNS)
    for table, cols, deploy in [
            ("NonJD_OrderRules", RULE_COLUMNS, "the rules dataflow and shortcut"),
            ("NonJD_TransferRules", TRANSFER_RULE_COLUMNS, "df_NonJD_TransferRules_Raw and its shortcut"),
            ("NonJD_Transfers", COMMITTED_COLUMNS, "df_NonJD_Transfers_Raw and its shortcut"),
            ("Fact_NonJD_TransferSuggestion", SUGGESTION_COLUMNS, "the round 2 Build_Gold_NonJD_Reorder"),
            ("Fact_NonJD_Purchases", PURCHASES_COLUMNS, "the round 3 Build_Gold_NonJD_Reorder")]:
        pl.require_columns(table, _readable_columns(con, table, deploy), [g for g, _ in cols])


def _dicts(cur) -> list:
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def log_rows(con, days: int = 14) -> list:
    """The Gold item's rows plus every run-level row: item rows carry only end_utc, so the run's start time
    (publish_logic.run_start) comes from its row_type='run' rows (the InProgress row has no end_utc)."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    return _dicts(con.execute(f"""
        SELECT run_id, name, row_type, status, start_utc, end_utc FROM {_src("dp_refresh_log")}
        WHERE ((name = 'Build_Gold_NonJD_Reorder' AND row_type = 'item') OR row_type = 'run')
          AND coalesce(end_utc, start_utc) >= ?""", [since]))


def built_at(con) -> datetime:
    return con.execute(f"SELECT max(BuiltAtUtc) FROM {_src('Fact_NonJD_Reorder')}").fetchone()[0]


def reorder(con) -> list:
    return _dicts(con.execute(REORDER_SQL.format(src=_src("Fact_NonJD_Reorder"))))


def _select(cols) -> str:
    return ", ".join(f'{g} AS "{f}"' for g, f in cols)


def rules(con) -> list:
    """Its columns are checked in check_columns()."""
    return _dicts(con.execute(f"SELECT {_select(RULE_COLUMNS)} FROM {_src('NonJD_OrderRules')} ORDER BY Id"))


def transfer_rules(con) -> list:
    """NonJD_TransferRules raw, as Gold reads it, ordered by Id."""
    return _dicts(con.execute(f"SELECT {_select(TRANSFER_RULE_COLUMNS)} FROM {_src('NonJD_TransferRules')} "
                              "ORDER BY Id"))


def suggestions(con) -> list:
    """Gold's transfer suggestion lines, by group (Franchise, PartNumber; NULLs last) then emission order."""
    return _dicts(con.execute(f"SELECT {_select(SUGGESTION_COLUMNS)} FROM {_src('Fact_NonJD_TransferSuggestion')} "
                              "ORDER BY Franchise, PartNumber, Seq, Kind, FromBranch, ToBranch"))


def purchases(con) -> list:
    """Gold's 12-month purchases at cost, one row per branch + franchise (values as Gold stores them: trimmed,
    upper-case), ordered by branch then franchise."""
    return _dicts(con.execute(f"SELECT {_select(PURCHASES_COLUMNS)} FROM {_src('Fact_NonJD_Purchases')} "
                              "ORDER BY Branch, Franchise"))


def committed(con, build_date) -> list:
    """The NonJD_Transfers lines Gold counted as committed (step 8b) on the build's Central date. The table is small
    (the dataflow drops Cancelled and old Placed transfers), so the exact rule is applied in Python."""
    rows = _dicts(con.execute(f"SELECT {_select(COMMITTED_COLUMNS)} FROM {_src('NonJD_Transfers')}"))
    return pl.committed_lines(rows, build_date)


def stage_history(con) -> int:
    """Copy the history table into a DuckDB temp table once; returns its row count."""
    con.execute(f"""CREATE OR REPLACE TEMP TABLE hist AS
        SELECT trim(Branch) AS branch, Franchise AS franchise, PartNumber AS partNumber, MonthOffset AS monthOffset,
               SalesQty AS salesQty, RequestCount AS requestCount
        FROM {_src('Fact_NonJD_SalesHistory')}""")
    return con.execute("SELECT count(*) FROM hist").fetchone()[0]


def history_for(con, branch: str) -> list:
    return _dicts(con.execute("SELECT * FROM hist WHERE branch = ?", [branch]))


def transfers(con) -> list:
    """Outstanding transfer lines for part numbers in scope, leaving out any line to or from an excluded branch (D6)."""
    return _dicts(con.execute(f"""
        SELECT t.RequestingBranch AS toBranch, t.SupplyingBranch AS fromBranch, t.PartNumber AS partNumber,
               t.PartTicket AS ticket, t.LineNumber AS line, t.OrderQty AS orderQty, t.ShippedQty AS shippedQty,
               t.OpenQty AS openQty, t.FulfillmentStatus AS status, t.TransferSubType AS subType,
               t.OrderAge AS ageDays, t.Date AS date
        FROM {_src('Fact_OutstandingTransfers')} t
        WHERE t.PartNumber IN (SELECT DISTINCT upper(trim(PartNumber)) FROM {_src('Fact_NonJD_Reorder')})
          AND upper(trim(coalesce(t.RequestingBranch, ''))) NOT IN ({_EXCLUDED_SQL})
          AND upper(trim(coalesce(t.SupplyingBranch, ''))) NOT IN ({_EXCLUDED_SQL})
        ORDER BY toBranch, partNumber, ticket, line, fromBranch, date"""))


def branch_names(con) -> dict:
    rows = con.execute(f"SELECT BranchID, BranchName FROM {_src('dim_BranchLocation')}").fetchall()
    return {str(b).strip(): n for b, n in rows if b is not None}
