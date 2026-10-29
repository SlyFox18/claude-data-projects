"""Customer account export for Casey (account linking). One row per ArMaster account.

Sensitive ID columns are replaced with HMAC-SHA256 codes: equal values give equal codes,
the raw value is never written. The key lives in casey_hash_key.txt next to this script.
"""
import hashlib, hmac, os, re, secrets, sys
import duckdb
import pandas as pd

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
WS = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"; LH = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
p = lambda t: f"delta_scan('abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Tables/{t}')"

key_file = os.path.join(HERE, "casey_hash_key.txt")
if not os.path.exists(key_file):
    open(key_file, "w").write(secrets.token_hex(32))
KEY = bytes.fromhex(open(key_file).read().strip())


def hash_id(v):
    s = re.sub(r"[^0-9A-Z]", "", str(v or "").upper())
    # blanks, "999999999", "TAXABLE"/"EXEMPT" etc. would create false matches
    if sum(ch.isdigit() for ch in s) < 4 or len(set(s)) == 1 or s.count("0") >= len(s) - 1:
        return None
    return hmac.new(KEY, s.encode(), hashlib.sha256).hexdigest()[:16].upper()


con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
# One contact_code is duplicated in contact; keep its most recently modified row.
df = con.sql(f"""
WITH c AS (
  SELECT *, row_number() OVER (PARTITION BY upper(trim(contact_code))
                               ORDER BY Last_Modified_Date DESC NULLS LAST, Creation_Date DESC NULLS LAST) rn
  FROM {p('contact')})
SELECT trim(cast(a.ACC_NO AS varchar))                         AS "Account #",
       nullif(trim(cast(c.company_name AS varchar)),'')        AS "Company Name",
       nullif(trim(cast(c.name AS varchar)),'')                AS "First Name",
       nullif(trim(cast(c.surname AS varchar)),'')             AS "Last Name",
       nullif(trim(cast(c.Doing_Business_As AS varchar)),'')   AS "Doing Business As",
       nullif(trim(cast(c.Familiar_Name AS varchar)),'')       AS "Familiar Name",
       CASE upper(trim(cast(c.Business_Individual AS varchar))) WHEN 'I' THEN 'Individual' WHEN 'C' THEN 'Company'
            WHEN 'B' THEN 'Business' END      AS "Business/Individual",
       nullif(trim(cast(c.street AS varchar)),'')              AS "Physical Street",
       nullif(trim(cast(c.street_2 AS varchar)),'')            AS "Physical Street 2",
       nullif(trim(cast(c.city AS varchar)),'')                AS "Physical City",
       nullif(trim(cast(c.state AS varchar)),'')               AS "Physical State",
       nullif(trim(cast(c.pcode AS varchar)),'')               AS "Physical Zip",
       nullif(trim(cast(c.postal_street_1 AS varchar)),'')     AS "Mailing Street",
       nullif(trim(cast(c.postal_street_2 AS varchar)),'')     AS "Mailing Street 2",
       nullif(trim(cast(c.postal_city AS varchar)),'')         AS "Mailing City",
       nullif(trim(cast(c.postal_state AS varchar)),'')        AS "Mailing State",
       nullif(trim(cast(c.postal_pcode AS varchar)),'')        AS "Mailing Zip",
       nullif(trim(cast(c.bus_phone AS varchar)),'')           AS "Work Phone",
       nullif(trim(cast(c.prv_phone AS varchar)),'')           AS "Home Phone",
       nullif(trim(cast(c.mob_phone AS varchar)),'')           AS "Mobile Phone",
       nullif(trim(cast(c.fax_no AS varchar)),'')              AS "Fax",
       nullif(trim(cast(c.email_address AS varchar)),'')       AS "Email",
       nullif(trim(cast(c.Email_Address_2 AS varchar)),'')     AS "Email 2",
       nullif(trim(cast(ac.BILL_TO_ACC AS varchar)),'') AS "Bill-To Account",
       CASE upper(trim(cast(c.Inactive_Indicator AS varchar))) WHEN 'A' THEN 'Active' WHEN 'I' THEN 'Inactive' END AS "Active/Inactive",
       nullif(trim(cast(c.Inactive_Reason AS varchar)),'')     AS "Inactive Reason",
       cast(c.Inactive_Effect_Date AS date)   AS "Inactive Date",
       cast(a.Creation_Date AS date)          AS "Date Opened",
       cast(a.DATE_LAST_PAY AS date)          AS "Last Payment Date",
       c.Social_Security_No AS _ssn, ac.TAX_EXEMPT_NO AS _taxex, c.abn AS _abn, c.company_acn AS _acn
FROM {p('ArMaster')} a
JOIN {p('ArMaster_Customer')} ac ON upper(trim(cast(ac.contact_code AS varchar))) = upper(trim(cast(a.contact_code AS varchar)))
LEFT JOIN c ON upper(trim(cast(c.contact_code AS varchar))) = upper(trim(cast(a.contact_code AS varchar))) AND c.rn = 1
""").df()

df["Tax ID Hash"] = df.pop("_ssn").map(hash_id)
df["Tax Exempt # Hash"] = df.pop("_taxex").map(hash_id)
# abn / company_acn are near-empty legacy ID fields; fold them into one hash column
other = [hash_id(a) or hash_id(b) for a, b in zip(df.pop("_abn"), df.pop("_acn"))]
df["Other Business ID Hash"] = other
# Tax IDs sometimes get typed into free-text fields (an EIN in a Last Name, for one); blank them there.
TAX_ID_SHAPE = r"^\s*(\d{3}-?\d{2}-?\d{4}|\d{2}-\d{7})\s*$"
for c in ["Company Name", "First Name", "Last Name", "Doing Business As", "Familiar Name", "Physical Street",
          "Physical Street 2", "Mailing Street", "Mailing Street 2", "Inactive Reason"]:
    hit = df[c].fillna("").str.match(TAX_ID_SHAPE)
    if hit.any():
        print(f"blanked {hit.sum()} tax-ID-shaped value(s) in {c}")
    df.loc[hit, c] = None
df["Bill-To Account"] = df["Bill-To Account"].where(df["Bill-To Account"] != df["Account #"])
df = df.sort_values("Account #", key=lambda s: pd.to_numeric(s, errors="coerce")).reset_index(drop=True)

assert df["Account #"].is_unique, "duplicate account numbers"
print(f"rows: {len(df):,}")
for c in ["Tax ID Hash", "Tax Exempt # Hash", "Other Business ID Hash", "Bill-To Account"]:
    filled = df[c].notna().sum()
    shared = df[c].dropna().duplicated(keep=False).sum()
    print(f"{c:24s} filled {filled:6,}   on accounts sharing a value {shared:6,}")

notes = pd.DataFrame({"Column": [
    "Account #", "Bill-To Account", "Active/Inactive", "Date Opened", "Tax ID Hash",
    "Tax Exempt # Hash", "Other Business ID Hash", "Source"], "Notes": [
    "DBS account number (ArMaster.ACC_NO); matches the parts and work order files.",
    "Only filled when DBS bills this account to a different account (rare).",
    "From the contact's Inactive Indicator. Inactive Date is when it was set, where recorded.",
    "Date the account was created in DBS.",
    "Coded version of the tax ID / SSN field. Same code = same number. The number itself is not included and cannot be recovered from the code.",
    "Coded version of the sales tax exemption certificate number. Same code = same certificate.",
    "Coded version of two rarely used legacy business ID fields.",
    f"DBS (Equip) customer tables via the JD Fabric copy, pulled {pd.Timestamp.now():%Y-%m-%d}. One row per account."]})

out = os.path.join(HERE, f"DBS Customer Accounts {pd.Timestamp.now():%Y-%m-%d}.xlsx")
with pd.ExcelWriter(out, engine="openpyxl") as xw:
    df.to_excel(xw, sheet_name="Accounts", index=False)
    notes.to_excel(xw, sheet_name="Notes", index=False)
    for name, w in (("Accounts", None), ("Notes", None)):
        ws = xw.sheets[name]
        ws.freeze_panes = "A2"
        # openpyxl writes any "=..." string as a formula; DBS has names like "= 4 TEAM ROPING"
        for row in ws.iter_rows(min_row=2):
            for cell in row:
                if cell.data_type == "f":
                    cell.data_type = "s"
        if name == "Accounts":
            ws.auto_filter.ref = ws.dimensions
        for col in ws.columns:
            width = max(len(str(c.value or "")) for c in col[:500])
            ws.column_dimensions[col[0].column_letter].width = min(max(width + 2, 10), 60 if name == "Accounts" else 120)
print(out)
