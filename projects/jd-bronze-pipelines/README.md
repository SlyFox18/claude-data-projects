# JD Bronze Pipelines

Pipelines in workspace **JD_FabricOneLake** (`4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`) that load
EquipRDB (ODBC) into lakehouse **JD_EquipRDB_Production_Bronze** (`7348c3a6-8694-4d11-bc70-1bd55be84ea2`).
DP_Staging's Bronze tables are OneLake shortcuts into that lakehouse.

| Pipeline | ID | Table list | Connection | Schedule |
|---|---|---|---|---|
| `PL_EquipRDB_To_Fabric_Full` (JD) | `e2094bc4-2b08-4510-83db-bd0d19ec754f` | `watermarktable_full` (137) | `b062a489` (JD) | Daily 00:00 CST, runs as SPN `SPITractor_Fabric_Integration_Admin` |
| `PL_EquipRDB_To_Fabric_Incremental` (JD) | `c310aa3b-3143-49aa-b77c-a3ae13e5660b` | `watermarktable_incremental` (17) | `b062a489` (JD) | **Disabled** — leave off |
| `PL_EquipRDB_To_Fabric_Incremental_SPI` (ours) | `912552eb-4b9a-4d93-9bf3-887b03bc0373` | `watermarktable_incremental` (17) | `b00ca7c0` `dsn=EquipRDB64pipe` (SPI-Data-Gateway) | Target: daily 3:30 AM CST |

**Only one incremental pipeline may ever be scheduled** — both write the same watermark table and
Bronze tables.

## Why the SPI copy exists (2026-09-28)

The 17 incremental tables (Invoice, ArMaster, contact, WkInvReg, GlTrans, VhSalman, ArTrans,
Bin_Location, UAUDIT, INPUROHD, Barcode_Activity_Tracking, Parts_Pricing_Admin, VhStock_Notes,
VhStock_Notes_Audit, Service_Agreement_Header, RP_INVOICE_TAX_TC, Branch_Name) stopped syncing
2026-09-04. A scheduled pipeline runs as its schedule's owner; after the schedule was paused and
re-enabled it ran as Brian's user, which has no access to JD's connection `b062a489` →
`DMTS_EntityNotFoundOrUnauthorized` on every run. Fabric also refuses to create/Save as any
pipeline referencing a connection the caller can't use.

`PL_EquipRDB_To_Fabric_Incremental_SPI` is JD's definition with exactly 3 connection references
swapped (LookupNewWatermarkValue, ForceFullReload, DeltaCopy) to SPI's own connection.

## Files

- `PL_EquipRDB_To_Fabric_Incremental_SPI.pipeline-content.json` — definition of our pipeline
- `backup-2026-09-28/` — JD's original definitions, schedules and `.platform` for both pipelines
