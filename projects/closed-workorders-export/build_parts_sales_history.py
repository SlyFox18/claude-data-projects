"""Build the frozen PartsSales_<year>.csv files for Casey (Aug-Dec 2024, 2025) locally with DuckDB.

The live 2026+ months, PartsSalesSummary.csv and PartsCustomers.csv come from the Power Automate flow
"Parts Sales Export - Biweekly" (PartsSalesLines.sql / PartsSalesSummary.sql / PartsCustomers.sql).
This script is the DuckDB port of PartsSalesLines.sql; keep the two in step. It was checked against
the flow's own 2026 month files line for line (2026-10-27).

Reads the Prod DP_Presentation tables over OneLake (az CLI login). Writes CRLF CSVs identical in
format to the flow's output.

    python build_parts_sales_history.py <out_dir> [--months 2026-01,2026-02]   # --months: check only
"""
import os
import sys

import duckdb

P = ("abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/"
     "966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/")
HEADER = ("TransDate,Branch,StoreName,InvoiceNumber,Channel,WorkOrder,CustomerAccount,AccountKind,"
          "InvoiceName,WOCustomerAccount,SaleType,JobCode,PartNumber,Description,Franchise,Quantity,"
          "UnitPrice,LineTotal")


def connect():
    con = duckdb.connect()
    # Silver timestamps hold Equip's shop-local wall clock as UTC, like the SQL endpoint shows them.
    con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    con.sql(f"""CREATE TABLE it AS SELECT * FROM delta_scan('{P}Silver_InTrans')
                WHERE TransDatetime >= TIMESTAMP '2024-08-01' AND Type IN ('I', 'C')""")
    con.sql(f"""CREATE TABLE hdr AS SELECT * FROM delta_scan('{P}Silver_Invoice')
                WHERE InvoiceType IN ('I', 'C', 'S') AND InvoiceDate >= TIMESTAMP '2024-07-01'""")
    for t in ("Silver_WkInvReg", "Silver_WkRoFile", "CustomerLookup", "dim_Parts", "dim_BranchLocation"):
        con.sql(f"CREATE TABLE {t} AS SELECT * FROM delta_scan('{P}{t}')")
    return con


LINES_SQL = """
WITH wir AS (
    -- Invoice -> work order (service invoices only); unique per invoice number (asserted below).
    SELECT i.InvoiceNumber, i.WorkOrder, r.AccountNumber AS WOAccount
    FROM Silver_WkInvReg i
    LEFT JOIN Silver_WkRoFile r ON r.Branch = i.Branch AND r.WorkOrder = i.WorkOrder
),
lines AS (
    SELECT CAST(t.TransDatetime AS DATE) AS TransDate, t.TransDatetime, t.TransId, t.Branch,
           b.City AS StoreName, t.RONumber AS InvoiceNumber,
           CASE h.ModuleType WHEN 'W' THEN 'Service' WHEN 'I' THEN 'Counter' WHEN 'S' THEN 'Equipment'
                ELSE COALESCE(h.ModuleType, '') END AS Channel,
           w.WorkOrder, TRIM(t.CustomerNo) AS CustomerAccount, c.DisplayName,
           TRIM(CONCAT_WS(' ', NULLIF(TRIM(h.CompanyName), ''), NULLIF(TRIM(h.FirstName), ''),
                          NULLIF(TRIM(h.LastName), ''))) AS HeaderName,
           w.WOAccount, t.TradeType AS SaleType, TRIM(t.JobCode) AS JobCode, t.PartNumber,
           COALESCE(p.Description, t.Description) AS Description, t.Franchise, t.Qty, t.SaleValue
    FROM it t
    JOIN hdr h ON h.InvoiceNumber = t.RONumber AND CAST(h.InvoiceDate AS DATE) = CAST(t.TransDatetime AS DATE)
    LEFT JOIN wir w ON h.ModuleType = 'W' AND w.InvoiceNumber = t.RONumber
    LEFT JOIN CustomerLookup c ON c.MatchKey = UPPER(TRIM(t.CustomerNo))
    LEFT JOIN dim_Parts p ON p.PartNumber = t.PartNumber
    LEFT JOIN dim_BranchLocation b ON b.BranchID = t.Branch
    WHERE t.TransDatetime >= CAST(? AS TIMESTAMP) AND t.TransDatetime < CAST(? AS TIMESTAMP)
),
kinds AS (
    SELECT *,
           CASE WHEN CustomerAccount = 'SUNDRY' THEN 'Sundry'
                WHEN UPPER(DisplayName) LIKE 'CASH%' THEN 'Cash'
                WHEN UPPER(DisplayName) LIKE '%ECOMMERCE%' THEN 'Web'
                WHEN UPPER(DisplayName) LIKE 'WARRANT%' THEN 'Warranty'
                WHEN UPPER(DisplayName) LIKE 'SOUTH PLAINS IMP%' OR UPPER(DisplayName) LIKE '%INTERNAL' THEN 'Internal'
                ELSE 'Customer' END AS AccountKind
    FROM lines
)
SELECT CONCAT(
    strftime(TransDate, '%Y-%m-%d'), ',',
    '"', Branch, '",',
    '"', REPLACE(COALESCE(StoreName, ''), '"', '""'), '",',
    '"', InvoiceNumber, '",',
    Channel, ',',
    COALESCE(CAST(WorkOrder AS VARCHAR), ''), ',',
    '"', REPLACE(COALESCE(CustomerAccount, ''), '"', '""'), '",',
    AccountKind, ',',
    '"', CASE WHEN AccountKind IN ('Cash', 'Web', 'Sundry') THEN REPLACE(COALESCE(HeaderName, ''), '"', '""') ELSE '' END, '",',
    '"', COALESCE(TRIM(CAST(WOAccount AS VARCHAR)), ''), '",',
    '"', COALESCE(SaleType, ''), '",',
    '"', REPLACE(COALESCE(JobCode, ''), '"', '""'), '",',
    '"', REPLACE(COALESCE(PartNumber, ''), '"', '""'), '",',
    '"', REPLACE(REPLACE(REPLACE(COALESCE(Description, ''), '"', '""'), chr(13), ' '), chr(10), ' '), '",',
    '"', COALESCE(Franchise, ''), '",',
    CAST(Qty AS VARCHAR), ',',
    -- UnitPrice in exact integer cents, rounded half away from zero like T-SQL's decimal ROUND
    -- (DuckDB decimal division is floating point: 267.45 / 10 would round to 26.74, not 26.75).
    CASE WHEN Qty <> 0 THEN CAST(CAST(CAST(
        SIGN(SaleValue) * SIGN(Qty) * ((ABS(CAST(SaleValue * 100 AS BIGINT)) * 200 + ABS(CAST(Qty * 100 AS BIGINT)))
                                       // (2 * ABS(CAST(Qty * 100 AS BIGINT)))) AS DECIMAL(14, 0)) / 100
        AS DECIMAL(12, 2)) AS VARCHAR) ELSE '' END, ',',
    CAST(SaleValue AS VARCHAR)
) AS Line
FROM kinds
ORDER BY TransDate, Branch, InvoiceNumber, TransDatetime, TransId, PartNumber
"""


def write(con, start, end, path):
    rows = con.execute(LINES_SQL, [start, end]).fetchall()
    base = con.execute("SELECT COUNT(*) FROM it WHERE TransDatetime >= CAST(? AS TIMESTAMP) AND TransDatetime < CAST(? AS TIMESTAMP)",
                       [start, end]).fetchone()[0]
    assert len(rows) == base, f"{path}: {len(rows)} lines written but {base} InTrans lines in range (header join not 1:1)"
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(HEADER + "\r\n")
        for (line,) in rows:
            f.write(line + "\r\n")
    print(f"{os.path.basename(path)}: {len(rows):,} lines, {os.path.getsize(path) / 1e6:.1f} MB")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    con = connect()
    dup = con.sql("SELECT COUNT(*) FROM (SELECT InvoiceNumber FROM Silver_WkInvReg GROUP BY 1 HAVING COUNT(*) > 1)").fetchone()[0]
    assert dup == 0, f"Silver_WkInvReg.InvoiceNumber is not unique ({dup} repeats)"
    if "--months" in sys.argv:
        for m in sys.argv[sys.argv.index("--months") + 1].split(","):
            y, mo = map(int, m.split("-"))
            nxt = f"{y + (mo == 12)}-{mo % 12 + 1:02d}-01"
            write(con, f"{m}-01", nxt, os.path.join(out, f"PartsSales_{m}.csv"))
        return
    write(con, "2024-08-01", "2025-01-01", os.path.join(out, "PartsSales_2024.csv"))
    write(con, "2025-01-01", "2026-01-01", os.path.join(out, "PartsSales_2025.csv"))


if __name__ == "__main__":
    main()
