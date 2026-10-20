"""DuckDB reads of DP Gold for the publish script. Returns plain Python rows (dicts)."""
from datetime import datetime, timedelta, timezone

import os

import duckdb

import config

REORDER_SQL = """
SELECT Branch AS branch, Franchise AS franchise, PartNumber AS partNumber, Description AS description,
       Bin AS bin, VendorCode AS vendorCode, ProductGroup AS productGroup, SuperTo AS superTo, SuperFrom AS superFrom,
       QuantityOnHand AS onHand, OnOrder AS onOrder, BackOrderQty AS backOrder, Cost AS cost,
       SellPrice1 AS sellPrice, ListPrice AS listPrice, MinimumQty AS minimumQty, MaximumQty AS maximumQty,
       ReorderCode AS reorderCode, ActivityCode AS activityCode, MinOverride AS minOverride, IsMasked AS isMasked,
       MaskExpires AS maskExpires, IsLowMargin AS isLowMargin, Current12MoSales AS sales12,
       Previous12MoSales AS salesPrev12, DateLastRequested AS lastRequested, MonthCount AS monthCount,
       AvgMonthlyDemand AS avgDemand, AvgMonthlySales AS avgSales, StockingTarget AS target,
       RecommendedOrderQty AS recommendedQty, EstOrderValue AS estValue, SurplusQty AS surplusQty,
       InboundTransferQty AS inboundQty, Status AS status
FROM delta_scan('{path}')
ORDER BY branch, franchise, partNumber
"""


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


def _dicts(cur) -> list:
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def log_rows(con, days: int = 14) -> list:
    """The Gold item's rows plus every run-level row: item rows carry only end_utc, so the run's start time
    (publish_logic.run_start) comes from its row_type='run' rows (the InProgress row has no end_utc)."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    return _dicts(con.execute(f"""
        SELECT run_id, name, row_type, status, start_utc, end_utc FROM delta_scan('{config.table_path("dp_refresh_log")}')
        WHERE ((name = 'Build_Gold_NonJD_Reorder' AND row_type = 'item') OR row_type = 'run')
          AND coalesce(end_utc, start_utc) >= ?""", [since]))


def built_at(con) -> datetime:
    return con.execute(f"SELECT max(BuiltAtUtc) FROM delta_scan('{config.table_path('Fact_NonJD_Reorder')}')").fetchone()[0]


def reorder(con) -> list:
    return _dicts(con.execute(REORDER_SQL.format(path=config.table_path("Fact_NonJD_Reorder"))))


def stage_history(con) -> int:
    """Copy the history table into a DuckDB temp table once; returns its row count."""
    con.execute(f"""CREATE OR REPLACE TEMP TABLE hist AS
        SELECT trim(Branch) AS branch, Franchise AS franchise, PartNumber AS partNumber, MonthOffset AS monthOffset,
               SalesQty AS salesQty, RequestCount AS requestCount
        FROM delta_scan('{config.table_path('Fact_NonJD_SalesHistory')}')""")
    return con.execute("SELECT count(*) FROM hist").fetchone()[0]


def history_for(con, branch: str) -> list:
    return _dicts(con.execute("SELECT * FROM hist WHERE branch = ?", [branch]))


def transfers(con) -> list:
    return _dicts(con.execute(f"""
        SELECT t.RequestingBranch AS toBranch, t.SupplyingBranch AS fromBranch, t.PartNumber AS partNumber,
               t.PartTicket AS ticket, t.LineNumber AS line, t.OrderQty AS orderQty, t.ShippedQty AS shippedQty,
               t.OpenQty AS openQty, t.FulfillmentStatus AS status, t.TransferSubType AS subType,
               t.OrderAge AS ageDays, t.Date AS date
        FROM delta_scan('{config.table_path('Fact_OutstandingTransfers')}') t
        WHERE t.PartNumber IN (SELECT DISTINCT upper(trim(PartNumber))
                               FROM delta_scan('{config.table_path('Fact_NonJD_Reorder')}'))
        ORDER BY toBranch, partNumber, ticket, line, fromBranch, date"""))


def branch_names(con) -> dict:
    rows = con.execute(f"SELECT BranchID, BranchName FROM delta_scan('{config.table_path('dim_BranchLocation')}')").fetchall()
    return {str(b).strip(): n for b, n in rows if b is not None}
