"""Shared pieces for the JD data share workbooks: DuckDB over OneLake, the JD account -> branch map,
the machine (serial) -> customer bridge, and the Excel styling.

The share and its quirks are documented in fabric-workspace-docs/docs/JD-DATA-SHARE.md.
"""
import os
import re
from datetime import date

import duckdb
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.table import Table, TableStyleInfo

SHARE = ("aa26f4dc-a150-4f47-8b46-30a0bb5590e8", "09357485-aaf6-45bc-aa95-b2bd7179b398")   # JD_Dealer_DataExchange / Data_Sharing
DP = {"prod": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f"),  # DP_Presentation
      "dev": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91")}
DIVISION = {"11": "Ag", "12": "Turf", "13": "CWP"}
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")


def onelake(ws_lh, table):
    return f"delta_scan('abfss://{ws_lh[0]}@onelake.dfs.fabric.microsoft.com/{ws_lh[1]}/Tables/{table}')"


def share(table):
    return onelake(SHARE, f"EXTERNAL_049694_ddp_{table}")


def connect():
    con = duckdb.connect()
    # Share timestamps are real instants; Equip's are wall clock stored as UTC. Read both in UTC and convert
    # share timestamps to Central explicitly where a local date matters.
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
    con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    con.create_function("initcap", lambda s: s.title() if s else s, ["VARCHAR"], "VARCHAR")
    return con


def city_key(s):
    return re.sub(r"[^A-Z]", "", (s or "").upper())


def load_branch_map(con, tier="prod"):
    """Table jd_acct(acct_id, Division, BranchID, Store, Closed): every JD account in dealer_profile, mapped to
    our numeric branch in the same city (closed and predecessor accounts included)."""
    con.create_function("city_key", city_key, ["VARCHAR"], "VARCHAR")
    con.execute(f"""CREATE OR REPLACE TABLE jd_acct AS
        WITH ours AS (SELECT city_key(City) ck, min(BranchID) FILTER (WHERE regexp_matches(BranchID, '^[0-9]+$')) BranchID
                      FROM {onelake(DP[tier], 'dim_BranchLocation')} GROUP BY 1),
             names AS (SELECT BranchID, any_value(BranchName) BranchName FROM {onelake(DP[tier], 'dim_BranchLocation')} GROUP BY 1)
        SELECT d.acct_id, CASE d.spart WHEN '11' THEN 'Ag' WHEN '12' THEN 'Turf' WHEN '13' THEN 'CWP' ELSE 'Old' END Division,
               o.BranchID, initcap(coalesce(n.BranchName, d.phy_addr_city)) Store, d.end_date < current_date Closed,
               d.kunnr
        FROM {share('dealer_profile')} d LEFT JOIN ours o ON o.ck = city_key(d.phy_addr_city)
        LEFT JOIN names n ON n.BranchID = o.BranchID""")
    missing = con.execute("SELECT string_agg(acct_id, ', ') FROM jd_acct WHERE BranchID IS NULL").fetchone()[0]
    if missing:
        print(f"  note: JD accounts with no branch in our city list: {missing}")


def load_machine_bridge(con, tier="prod"):
    """Tables used to describe a machine by any of its serial forms:
    pin_alias(k, alias)  - every 13/17/native PIN pair JD knows for the same machine (plus k -> k)
    owner(k, ...)        - our customer per serial from WkVehFl (latest-modified record wins; others listed)
    jd_name(entity_id, contact_id, JdOwner)  - JD's name for a customer entity
    model(k, Model)      - JD model name per serial"""
    con.execute(f"""CREATE OR REPLACE TABLE pin_alias AS
        WITH p AS (SELECT upper(trim(pin_17)) p17, upper(trim(pin_13)) p13, upper(trim(ntv_pin)) pn, decal_mdl_id
                   FROM {share('product_information')}),
             pairs AS (SELECT p17 a, p13 b FROM p UNION SELECT p13, p17 FROM p UNION SELECT pn, p17 FROM p
                       UNION SELECT pn, p13 FROM p UNION SELECT p17, pn FROM p UNION SELECT p13, pn FROM p)
        SELECT DISTINCT a k, b alias FROM pairs WHERE a IS NOT NULL AND b IS NOT NULL AND length(a) > 5 AND length(b) > 5
        UNION SELECT DISTINCT k, k FROM (SELECT p17 k FROM p UNION SELECT p13 FROM p UNION SELECT pn FROM p)
        WHERE k IS NOT NULL AND length(k) > 5""")
    con.execute(f"""CREATE OR REPLACE TABLE model AS
        WITH pm AS (SELECT DISTINCT pin, decal_mdl_id FROM {share('product_information')},
                    unnest([upper(trim(pin_17)), upper(trim(pin_13)), upper(trim(ntv_pin))]) t(pin)
                    WHERE pin IS NOT NULL AND decal_mdl_id IS NOT NULL)
        SELECT a.k, string_agg(DISTINCT e.decal_model_nm, ' / ') Model
        FROM pin_alias a JOIN pm ON pm.pin = a.alias
        JOIN (SELECT DISTINCT decal_model_id, decal_model_nm FROM {share('eph')}) e ON e.decal_model_id = pm.decal_mdl_id
        GROUP BY 1""")
    # One row per serial in our records. A serial can carry several accounts (earlier owners): the most recently
    # modified record is shown as the owner and the rest are listed in OtherAccounts.
    con.execute(f"""CREATE OR REPLACE TABLE veh AS
        WITH v AS (SELECT upper(trim(VIN)) vin, AccountNumber, coalesce(ModifiedDate, DeliveryDate) seen, Registration
                   FROM {onelake(DP[tier], 'Silver_WkVehFl')} WHERE length(trim(VIN)) > 5 AND AccountNumber IS NOT NULL),
             c AS (SELECT TRY_CAST(AccountNumber AS INT) acct, CustomerName, City, State
                   FROM {onelake(DP[tier], 'dim_CustomerList')}),
             top AS (SELECT * FROM v QUALIFY row_number() OVER (PARTITION BY vin
                     ORDER BY seen DESC NULLS LAST, AccountNumber DESC, Registration) = 1),
             others AS (SELECT v.vin, string_agg(DISTINCT v.AccountNumber::VARCHAR, ', ') OtherAccounts
                        FROM v JOIN top t ON t.vin = v.vin AND v.AccountNumber <> t.AccountNumber GROUP BY 1)
        SELECT t.vin, t.seen, t.AccountNumber, c.CustomerName, c.City, c.State, o.OtherAccounts
        FROM top t LEFT JOIN c ON c.acct = t.AccountNumber LEFT JOIN others o ON o.vin = t.vin""")
    # A JD serial may be in our records under its other PIN form, so look it up through pin_alias too.
    con.execute("""CREATE OR REPLACE TABLE owner AS
        SELECT k, AccountNumber, CustomerName, City, State, OtherAccounts
        FROM (SELECT a.k, v.* FROM pin_alias a JOIN veh v ON v.vin = a.alias
              UNION ALL SELECT v.vin, v.* FROM veh v)
        QUALIFY row_number() OVER (PARTITION BY k ORDER BY seen DESC NULLS LAST, AccountNumber DESC) = 1""")
    # Our unsold stock units (VhStock with no SaleDate), so a PIP or recommendation on one is visible.
    con.execute(f"""CREATE OR REPLACE TABLE stock AS
        WITH s AS (SELECT upper(trim(VIN)) vin, StockNumber, Status FROM {onelake(DP[tier], 'Silver_VhStock')}
                   WHERE length(trim(VIN)) > 5 AND SaleDate IS NULL)
        SELECT k, StockNumber, Status StockStatus
        FROM (SELECT a.k, s.* FROM pin_alias a JOIN s ON s.vin = a.alias UNION ALL SELECT s.vin, s.* FROM s)
        QUALIFY row_number() OVER (PARTITION BY k ORDER BY StockNumber DESC) = 1""")
    con.execute(f"""CREATE OR REPLACE TABLE jd_name AS
        SELECT entity_id, contact_id,
               min(coalesce(nullif(trim(nm1_txt), ''), trim(concat_ws(' ', nullif(trim(first_nm), ''), nullif(trim(last_nm), ''))))) JdOwner,
               min(initcap(phys_city)) JdCity, min(phys_state_prov_cd) JdState
        FROM {share('customer_profile')} GROUP BY 1, 2""")
    # Tables that carry only an entity id: use the entity's own record (contact 0) when there is one.
    con.execute("""CREATE OR REPLACE TABLE jd_ent AS
        SELECT entity_id, JdOwner, JdCity, JdState FROM jd_name
        QUALIFY row_number() OVER (PARTITION BY entity_id ORDER BY contact_id <> 0, contact_id) = 1""")


def jd_date(col):
    """SQL for a share date that may be a DATE, an ISO string, a US 'MM/dd/yyyy hh:mm:ss' string or blank."""
    return (f"coalesce(TRY_CAST({col} AS DATE), TRY_CAST(try_strptime(CAST({col} AS VARCHAR), '%m/%d/%Y %H:%M:%S') AS DATE),"
            f" TRY_CAST(left(CAST({col} AS VARCHAR), 10) AS DATE))")


# ---------------------------------------------------------------- Excel
FONT = "Arial"
HDR = 4          # header row on every data tab
FMT = {"date": "mm/dd/yyyy", "int": '#,##0;(#,##0);"-"', "num": '#,##0.0;(#,##0.0);"-"', "pct": "0%",
       "money": '$#,##0.00;($#,##0.00);"-"', "text": "@"}


def font(bold=False, color="000000", size=10, italic=False):
    return Font(name=FONT, bold=bold, color=color, size=size, italic=italic)


def new_workbook():
    wb = Workbook()
    wb.remove(wb.active)
    return wb


def data_sheet(wb, name, title, subtitle, columns, rows, freeze_col=1):
    """A sheet with a title, a subtitle and an Excel table (filters, banding) from row HDR.
    columns: [(header, width, fmt)] where fmt is a key of FMT or None."""
    ws = wb.create_sheet(name)
    ws["A1"], ws["A2"] = title, subtitle
    ws["A1"].font, ws["A2"].font = font(True, size=14), font(italic=True, color="595959")
    for i, (h, w, _) in enumerate(columns, 1):
        c = ws.cell(row=HDR, column=i, value=h)
        c.font = font(True, "FFFFFF")
        c.fill = PatternFill("solid", fgColor="1F3864")
        c.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.row_dimensions[HDR].height = 30
    for r, row in enumerate(rows, HDR + 1):
        for i, v in enumerate(row, 1):
            c = ws.cell(row=r, column=i, value=v)
            c.font = font()
            fmt = columns[i - 1][2]
            if fmt:
                c.number_format = FMT[fmt]
    last = HDR + max(len(rows), 1)
    ref = f"A{HDR}:{get_column_letter(len(columns))}{last}"
    tname = re.sub(r"[^A-Za-z0-9]", "", name) or "Data"
    t = Table(displayName=tname, ref=ref)
    t.tableStyleInfo = TableStyleInfo(name="TableStyleLight9", showRowStripes=True)
    ws.add_table(t)
    ws.freeze_panes = ws.cell(row=HDR + 1, column=freeze_col + 1)
    return ws


def notes_sheet(wb, title, notes):
    ws = wb.create_sheet("Notes")
    ws.column_dimensions["A"].width = 28
    ws.column_dimensions["B"].width = 110
    ws["A1"] = title
    ws["A1"].font = font(True, size=14)
    for i, (k, v) in enumerate(notes, 3):
        a, b = ws.cell(row=i, column=1, value=k), ws.cell(row=i, column=2, value=v)
        a.font, b.font = font(True), font()
        a.alignment = b.alignment = Alignment(wrap_text=True, vertical="top")
    return ws


def save(wb, stem, out=None, as_of=None):
    path = out or os.path.join(OUT_DIR, f"{stem}_{(as_of or date.today()):%Y-%m-%d}.xlsx")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    wb.save(path)
    print(f"Wrote {path}")
    return path
