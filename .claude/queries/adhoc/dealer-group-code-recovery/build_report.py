"""
DEALER GROUP CODE RECOVERY - BRANCH 2 & 4 (AD HOC)
============================================================================
Request: Curt made an accidental mass update in the EquipRDB source system
on 2026-09-15 that set DealerGroupCode to 'COTTON' for parts at Branch 2
and Branch 4. Brian needs the pre-change DealerGroupCode values so Curt can
manually fix the records. Delivered as an Excel workbook.

Source: LH_Master_Data lakehouse, Fact_PartMaster_Snapshot_Weekly, queried
directly via DuckDB over OneLake (no Fabric notebook/dataflow needed - this
is a one-off ad hoc pull).

Table: Fact_PartMaster_Snapshot_Weekly is an append-only weekly snapshot of
jdis_Part_Information (24-month retention). The 2026-09-13 snapshot (a
Sunday, before Curt's 2026-09-15 mistake) is the most recent snapshot taken
BEFORE the mass change, so its DealerGroupCode values are the pre-corruption
values to restore.

Branch scope: Branch is stored as text. Plain '2' and '4' are the main
branch codes; '2C' and '4B'/'4C'/'4I'/'4S' are small sub-location suffix
codes under those branches (a handful of rows each in the 2026-09-13
snapshot) - included since the same source-side mass update could plausibly
have touched them too.

Output: "Branch 2 and 4 - DealerGroupCode Pre-Change (2026-09-13 Snapshot).xlsx"
- One row per PartNumber x Branch, with PartNumber, Description, Branch,
  Franchise, CommodityCode, DealerGroupCode as of the 2026-09-13 snapshot.
- Sorted by Branch, then PartNumber.

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

SNAPSHOT_DATE = "2026-09-13"
out_path = "Branch 2 and 4 - DealerGroupCode Pre-Change (2026-09-13 Snapshot).xlsx"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

result = con.execute(f"""
    SELECT
        Branch,
        PartNumber,
        Description,
        Franchise,
        CommodityCode,
        DealerGroupCode,
        QuantityOnHand
    FROM delta_scan('{base}/Fact_PartMaster_Snapshot_Weekly')
    WHERE SnapshotDate = DATE '{SNAPSHOT_DATE}'
      AND (Branch LIKE '2%' OR Branch LIKE '4%')
    ORDER BY Branch, PartNumber
""").df()

print(f"Rows pulled: {len(result):,}")
print("\nBranch breakdown:")
print(result["Branch"].value_counts().sort_index())
print("\nDealerGroupCode distribution (pre-change, should NOT be all 'COTTON'):")
print(result["DealerGroupCode"].value_counts())

result.to_excel(out_path, sheet_name="DealerGroupCode Pre-Change", index=False)
print(f"\nSaved: {out_path}")
