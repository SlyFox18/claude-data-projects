"""DuckDB reads of DP Gold for the publish script. Returns plain Python rows (dicts)."""
from datetime import datetime, timedelta, timezone

import os

import duckdb

import config
import publish_logic as pl

# Gold column -> published field (README "reorder_<branch>.json.gz"), in file order. Gold's RuleId and BuiltAtUtc
# are not published. check_columns() fails, naming them, if Gold lacks any of these.
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
]
REORDER_SQL = ("SELECT " + ", ".join(f"{g} AS {f}" for g, f in REORDER_COLUMNS)
               + "\nFROM {src}\nORDER BY branch, franchise, partNumber")

# NonJD_OrderRules column -> rules.json field: exactly the columns Gold reads (MinActiveMonths is left in the list
# unused (D1) and Modified is not published).
RULE_COLUMNS = [
    ("Id", "id"), ("RuleName", "ruleName"), ("Priority", "priority"), ("Active", "active"), ("Archived", "archived"),
    ("Franchise", "franchise"), ("DealerGroupCode", "dealerGroupCode"), ("Branch", "branch"),
    ("StartMonth", "startMonth"), ("EndMonth", "endMonth"), ("HistoryMonths", "historyMonths"),
    ("MinDemands", "minDemands"), ("WeeksOfCover", "weeksOfCover"), ("SupplyUnit", "supplyUnit"),
    ("MinLineValue", "minLineValue"), ("MaxLineValue", "maxLineValue"), ("DemandBasis", "demandBasis"),
]
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


def check_columns(con) -> None:
    """Fail before extracting, naming every missing column, if a Gold table lacks a column the publish reads
    (e.g. the publish is newer or older than the Gold notebook). The rules table is checked in rules()."""
    pl.require_columns("Fact_NonJD_Reorder", columns(con, "Fact_NonJD_Reorder"),
                       [g for g, _ in REORDER_COLUMNS] + ["BuiltAtUtc"])
    pl.require_columns("Fact_NonJD_SalesHistory", columns(con, "Fact_NonJD_SalesHistory"), HISTORY_COLUMNS)
    pl.require_columns("Fact_OutstandingTransfers", columns(con, "Fact_OutstandingTransfers"), TRANSFER_COLUMNS)


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


def rules(con) -> list:
    pl.require_columns("NonJD_OrderRules", columns(con, "NonJD_OrderRules"), [g for g, _ in RULE_COLUMNS])
    sel = ", ".join(f"{g} AS {f}" for g, f in RULE_COLUMNS)
    return _dicts(con.execute(f"SELECT {sel} FROM {_src('NonJD_OrderRules')} ORDER BY Id"))


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
