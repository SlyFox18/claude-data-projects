"""
PIN CAPTURE - ACCURACY FEASIBILITY PULL (AD HOC)
============================================================================
Request: Parts asked whether captured PIN numbers on the Pin Capture report
are actually correct - not just "present". Fact_PinTransactions today only
flags whether PinNo/Notation is non-blank; it never validates the value
against anything. Brian wants to see the underlying line-level data to
judge whether building a real "PIN accuracy" measure into the report is
worth the effort.

Source: LH_Master_Data lakehouse, queried directly via DuckDB over OneLake
(no dataflow/notebook - one-off feasibility pull).

Method:
- Population: InTrans_Incremental lines, last 24 months, Type IN ('I','C')
  (same filter Fact_PinTransactions.pq uses), where PinNo is non-blank.
- "Known PIN" pool: WKVEHFL.VIN + vhstock.VIN, combined and normalized
  (upper, strip spaces/dashes). These are genuine John Deere Product ID
  Numbers - the "VIN" column name is legacy DMS naming, not automotive VIN.
- IsKnownPin: does the normalized captured PinNo exist anywhere in that pool?
- Owner match: for lines where PinNo matched a known VIN, pull that
  equipment's registered owner (WKVEHFL.AccountNumber or
  vhstock.OwnerContactCode) and compare to the invoice's own CustomerNo.
- OwnerSource is included because vhstock.OwnerContactCode uses a different
  (name-based, alphanumeric) customer coding scheme than the AR CustomerNo
  used everywhere else - a mismatch against a vhstock-sourced owner is NOT
  reliable evidence of a wrong PIN, just two different ID systems being
  compared. WKVEHFL.AccountNumber uses the same numbering scheme as
  CustomerNo, so those mismatches are the meaningful ones. Filter/sort by
  OwnerSource in Excel before judging the "wrong customer" count.
- StockNo (a candidate join key) is 0% populated on parts lines - dropped.
- The RONumber -> wkothsub -> WKROFILE.Registration -> WKVEHFL work-order
  path was tested and found to match 0 of 13,278 pin-captured invoices -
  PIN capture happens almost entirely on plain parts-counter invoices, not
  RO-linked transactions, so that path doesn't apply to this population.

Output: "Pin Capture - Accuracy Check (Last 24 Months).xlsx"
- Summary tab: funnel counts (captured / known-PIN match / owner match)
- Detail tab: one row per pin-captured line, with match flags, so Brian can
  filter/sample in Excel and judge real-world plausibility himself before
  deciding whether to build this into the report.

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb
import pandas as pd

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

out_path = "Pin Capture - Accuracy Check (Last 24 Months).xlsx"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# ------------------------------------------------------------------
# Detail: one row per pin-captured line, with known-PIN + owner match flags
# ------------------------------------------------------------------
detail = con.execute(f"""
    WITH pin_lines AS (
        SELECT
            ROW_NUMBER() OVER () AS LineId,
            CAST(TransDatetime AS DATE) AS TransDate,
            TRIM(Branch) AS Branch,
            TRIM(CAST(RONumber AS VARCHAR)) AS RONumber,
            TRIM(CAST(CustomerNo AS VARCHAR)) AS CustomerNo,
            TRIM(CAST(BillToAcc AS VARCHAR)) AS BillToAcc,
            PartNumber,
            Description,
            SaleValue,
            TRIM(PinNo) AS PinNo,
            TRIM(Notation) AS Notation,
            UPPER(REPLACE(REPLACE(TRIM(PinNo),'-',''),' ','')) AS PinNorm
        FROM delta_scan('{base}/InTrans_Incremental')
        WHERE TransDatetime >= (CURRENT_DATE - INTERVAL 24 MONTH)
          AND Type IN ('I','C')
          AND COALESCE(TRIM(PinNo),'') <> ''
    ),
    vehfl AS (
        SELECT
            UPPER(REPLACE(REPLACE(TRIM(VIN),'-',''),' ','')) AS VinNorm,
            TRIM(CAST(AccountNumber AS VARCHAR)) AS Owner,
            'WKVEHFL' AS OwnerSource,
            Make, Model, Registration
        FROM delta_scan('{base}/WKVEHFL')
        WHERE COALESCE(TRIM(VIN),'') <> ''
    ),
    vh AS (
        SELECT
            UPPER(REPLACE(REPLACE(TRIM(VIN),'-',''),' ','')) AS VinNorm,
            TRIM(CAST(OwnerContactCode AS VARCHAR)) AS Owner,
            'vhstock' AS OwnerSource,
            Make, Model, CAST(StockNumber AS VARCHAR) AS Registration
        FROM delta_scan('{base}/vhstock')
        WHERE COALESCE(TRIM(VIN),'') <> ''
    ),
    known AS (
        SELECT * FROM vehfl
        UNION ALL
        SELECT * FROM vh
    ),
    -- a captured PIN can match more than one equipment record (rare); pick one match per line
    ranked AS (
        SELECT p.*, k.Owner, k.OwnerSource, k.Make, k.Model, k.Registration,
               ROW_NUMBER() OVER (PARTITION BY p.LineId
                                   ORDER BY (CASE WHEN k.OwnerSource = 'WKVEHFL' THEN 0 ELSE 1 END)) AS rn
        FROM pin_lines p
        LEFT JOIN known k ON p.PinNorm = k.VinNorm
    )
    SELECT
        TransDate, Branch, RONumber, CustomerNo, BillToAcc,
        PartNumber, Description, SaleValue,
        PinNo, Notation,
        CASE WHEN Owner IS NOT NULL THEN 'Y' ELSE 'N' END AS IsKnownPin,
        Make AS MatchedEquipmentMake,
        Model AS MatchedEquipmentModel,
        Registration AS MatchedEquipmentRegistration,
        OwnerSource,
        Owner AS RegisteredOwnerAccount,
        CASE
            WHEN Owner IS NULL THEN 'No Match'
            WHEN OwnerSource = 'WKVEHFL' AND CustomerNo = Owner THEN 'Match'
            WHEN OwnerSource = 'WKVEHFL' AND CustomerNo <> Owner THEN 'Mismatch'
            WHEN OwnerSource = 'vhstock' THEN 'Not Comparable (different ID scheme)'
            ELSE 'Unknown'
        END AS CustomerOwnerCheck
    FROM ranked
    WHERE rn = 1
    ORDER BY TransDate DESC
""").df()

# ------------------------------------------------------------------
# Summary: funnel counts
# ------------------------------------------------------------------
total_lines = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/InTrans_Incremental')
    WHERE TransDatetime >= (CURRENT_DATE - INTERVAL 24 MONTH) AND Type IN ('I','C')
""").fetchone()[0]

captured = len(detail)
known_pin = (detail["IsKnownPin"] == "Y").sum()
wkvehfl_comparable = (detail["OwnerSource"] == "WKVEHFL").sum()
owner_match = (detail["CustomerOwnerCheck"] == "Match").sum()
owner_mismatch = (detail["CustomerOwnerCheck"] == "Mismatch").sum()

summary = pd.DataFrame([
    ["Total parts lines (24mo, Invoice/Credit)", total_lines, ""],
    ["Lines with a PIN captured (PinNo populated)", captured, f"{captured/total_lines:.1%} of total"],
    ["  - PIN matches a known real equipment PIN", known_pin, f"{known_pin/captured:.1%} of captured"],
    ["    - of which, owner is WKVEHFL-comparable (same ID scheme as CustomerNo)", wkvehfl_comparable, f"{wkvehfl_comparable/known_pin:.1%} of known-PIN matches"],
    ["      - Customer matches registered owner (Match)", owner_match, f"{owner_match/wkvehfl_comparable:.1%} of WKVEHFL-comparable" if wkvehfl_comparable else ""],
    ["      - Customer does NOT match registered owner (Mismatch)", owner_mismatch, f"{owner_mismatch/wkvehfl_comparable:.1%} of WKVEHFL-comparable" if wkvehfl_comparable else ""],
], columns=["Metric", "Count", "% of Prior Stage"])

# ------------------------------------------------------------------
# By Branch: same funnel, broken out per branch
# ------------------------------------------------------------------
lines_by_branch = con.execute(f"""
    SELECT TRIM(Branch) AS Branch, COUNT(*) AS TotalLines
    FROM delta_scan('{base}/InTrans_Incremental')
    WHERE TransDatetime >= (CURRENT_DATE - INTERVAL 24 MONTH) AND Type IN ('I','C')
    GROUP BY TRIM(Branch)
""").df()

branch_names = con.execute(f"""
    SELECT DISTINCT TRIM(BranchID) AS Branch, MAX(Branch) AS BranchDisplayName
    FROM delta_scan('{base}/dim_BranchLocation')
    GROUP BY TRIM(BranchID)
""").df()

by_branch = (
    detail.groupby("Branch")
    .agg(
        PinCaptured=("Branch", "size"),
        KnownPinMatch=("IsKnownPin", lambda s: (s == "Y").sum()),
        WKVEHFLComparable=("OwnerSource", lambda s: (s == "WKVEHFL").sum()),
        OwnerMatch=("CustomerOwnerCheck", lambda s: (s == "Match").sum()),
        OwnerMismatch=("CustomerOwnerCheck", lambda s: (s == "Mismatch").sum()),
    )
    .reset_index()
)

by_branch = lines_by_branch.merge(by_branch, on="Branch", how="left").fillna(0)
by_branch = by_branch.merge(branch_names, on="Branch", how="left")

for col in ["PinCaptured", "KnownPinMatch", "WKVEHFLComparable", "OwnerMatch", "OwnerMismatch"]:
    by_branch[col] = by_branch[col].astype(int)

by_branch["PinCaptureRate"] = by_branch["PinCaptured"] / by_branch["TotalLines"]
by_branch["KnownPinMatchRate"] = by_branch.apply(
    lambda r: r["KnownPinMatch"] / r["PinCaptured"] if r["PinCaptured"] else None, axis=1)
by_branch["OwnerMatchRate"] = by_branch.apply(
    lambda r: r["OwnerMatch"] / r["WKVEHFLComparable"] if r["WKVEHFLComparable"] else None, axis=1)
by_branch["EndToEndAccuracyRate"] = by_branch.apply(
    lambda r: r["OwnerMatch"] / r["PinCaptured"] if r["PinCaptured"] else None, axis=1)

by_branch = by_branch[[
    "Branch", "BranchDisplayName", "TotalLines", "PinCaptured", "PinCaptureRate",
    "KnownPinMatch", "KnownPinMatchRate", "WKVEHFLComparable", "OwnerMatch", "OwnerMismatch",
    "OwnerMatchRate", "EndToEndAccuracyRate"
]].sort_values("PinCaptured", ascending=False)

with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
    summary.to_excel(writer, sheet_name="Summary", index=False)
    by_branch.to_excel(writer, sheet_name="By Branch", index=False)
    detail.to_excel(writer, sheet_name="Detail - PIN Captures", index=False)

print(f"Total lines (24mo, I/C): {total_lines:,}")
print(f"Pin-captured lines: {captured:,}")
print(f"Known-PIN matches: {known_pin:,} ({known_pin/captured:.1%})")
print(f"WKVEHFL-comparable: {wkvehfl_comparable:,}")
print(f"Owner match: {owner_match:,} | Owner mismatch: {owner_mismatch:,}")
print(f"Branches: {len(by_branch)}")
print(f"Saved: {out_path}")
