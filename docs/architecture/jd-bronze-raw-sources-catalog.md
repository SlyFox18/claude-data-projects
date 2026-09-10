# LH_Master_Data Raw Sources → JD Bronze Migration Catalog

**Date:** 2026-09-10
**Purpose:** Inventory every dataflow in `LH_Master_Data` → `Dataflows/01 - Raw Sources`
(45 items), cross-reference each against the live table list in
`JD_EquipRDB_Production_Bronze` (JD's own Fabric mirror of `dsn=EquipRDB64`, 156
tables), and sort into migration categories. This is planning input only — nothing
here has been built. See [[project_jd_bronze_data_platform_redesign]] for what's
already live.

## Method

- JD Bronze table list pulled live via `fab ls` against the actual lakehouse
  (`JD_FabricOneLake` / `EquipRDB_Production` / `JD_EquipRDB_Production_Bronze`),
  not assumed from any doc — 156 real tables.
- Each dataflow's `mashup.pq` was read directly to find its real source: either a
  `FROM <table>` in a hand-written SQL string (`Odbc.Query`), or a
  `Source{[Name = "...", Kind = "Table"|"View"]}` schema-navigation step
  (`Odbc.DataSource(..., [HierarchicalNavigation = true])`).
- Matched case-insensitively (JD Bronze and EquipRDB table casing don't always agree
  — e.g. source `armaster` vs. bronze `ArMaster`).

## Category A — Direct match, real table already in JD Bronze (shortcut candidates)

These are the "cheap win" migrations — same pattern already proven for `InTrans` and
`GlTrans`: point a shortcut at the JD Bronze table instead of re-running an ODBC pull.
No source-side redesign needed; the work is verification (row counts, grain, any
WHERE-clause filtering the current dataflow applies that a shortcut would need to
replicate downstream instead) plus rebuilding whatever silver/gold logic currently
lives in the dataflow's later steps.

| Current dataflow | Source table | JD Bronze table | Notes |
|---|---|---|---|
| `df_ARMASTER_Raw` | `armaster` | `ArMaster` | |
| `df_ArMaster_Customer_Raw` | `ArMaster_Customer` | `ArMaster_Customer` | |
| `df_CONTACT_Raw` | `contact` | `contact` | |
| `df_GlMaster_Raw` | `GLMASTER` | `GLMASTER` | |
| `df_GlTrans_Raw` | `GlTrans` | `GlTrans` | **Already shortcut into `DP_Staging`** (Parts Adjustments/Promo work) |
| `df_GlTrans_Full_Raw` | `GlTrans` | `GlTrans` | Same source table as above, just a wider 3-yr pull — redundant once `DP`'s shortcut exists |
| `df_INSALORD_Raw` | `insalord` | `InSalOrd` | |
| `df_INSALPAR_Raw` | `InSalPar` | `InSalPar` | |
| `df_InHist_PmManage_Raw` | `InHist_PmManage` | `InHist_PmManage` | |
| `df_InMaster_PartsLookup_Incremental` | `InMaster` | `InMaster` | Incremental/watermark logic — see "InMaster consolidation" below |
| `df_InMaster_PartsLookup_Raw` | `InMaster` | `InMaster` | |
| `df_InMaster_Parts_Ordering_Raw` | `InMaster` | `InMaster` | |
| `df_InMaster_Raw` | `InMaster` | `InMaster` | |
| `df_InTrans_Incremental` | `InTrans` | `InTrans` | **Already shortcut into `DP_Staging`** |
| `df_InTrans_PartsCounter_Raw` | `intrans` | `InTrans` | Redundant once `DP`'s shortcut exists |
| `df_Invoice_Raw` | `Invoice` | `Invoice` | |
| `df_TechnicianInvoiceDetail_Raw` | `TechnicianInvoiceDetail` | `TechnicianInvoiceDetail` | |
| `df_TechnicianPunchedDetail_Raw` | `TechnicianPunchedDetail` | `TechnicianPunchedDetail` | |
| `df_VHSTOCK_Raw` | `VhStock` | `VhStock` | |
| `df_VhStockAccess_Raw` | `vhstockaccess` | `VhStockAccess` | |
| `df_VhTrans_Raw` | `VhTrans` | `VhTrans` | |
| `df_WARSUBCI_LABOUR_Raw` | `WarSubCl_Labour` | `WarSubCl_Labour` | |
| `df_WKINVREG_Raw` | `WkInvReg` | `WkInvReg` | |
| `df_WKMECHWK_Raw` | `wkmechwk` | `WKMECHWK` | |
| `df_WKOTHSUB_Raw` | `wkothsub` | `WKOTHSUB` | |
| `df_WKRODESC_Raw` | `wkrodesc` | `WKRODESC` | |
| `df_WKROFILE_Raw` | `wkrofile` | `WkRoFile` | |
| `df_WKVEHFL_Raw` | `wkvehfl` | `WkVehFl` | |
| `df_WarClaim_Raw` | `WarClaim` | `WarClaim` | |
| `df_Branch_Name_Raw` | `Branch_Name` | `Branch_Name` | Confirmed `Kind = "Table"`, not a view |

**27 dataflows, ~21 distinct source tables** — the largest single category, and the
most direct extension of the already-proven pattern.

### InMaster consolidation opportunity

Four separate dataflows (`df_InMaster_Raw`, `df_InMaster_PartsLookup_Raw`,
`df_InMaster_PartsLookup_Incremental`, `df_InMaster_Parts_Ordering_Raw`) all pull the
same `InMaster` table, each with its own column subset/rename/filter. A single
`DP_Staging` shortcut plus one silver notebook producing whatever column shapes each
downstream consumer needs would collapse 4 ODBC pulls into 1 shortcut — real CU
savings, not just a tidiness win. `df_InMaster_PartsLookup_Incremental`'s
watermark/incremental logic in particular may no longer be needed at all once sourced
from a live-updating JD mirror instead of a point-in-time ODBC pull, matching what
happened to `InTrans`/`GlTrans` (the "reused-reference-number" bugs in those tables'
old incremental logic went away entirely once the design moved off ODBC pulls) — worth
confirming, not assuming, before dropping the incremental logic.

## Category B — Source is a source-side VIEW, not mirrored by JD (needs rebuild, not a shortcut)

JD's mirror only replicates physical tables — it does not mirror source-side SQL
Anywhere views. Five dataflows pull from views; JD Bronze does have the *detail*
tables those views appear to aggregate, so the aggregation logic itself would need to
be rebuilt (likely a Spark notebook, matching this backend's established silver-layer
pattern) rather than simply shortcut in.

| Current dataflow | Source view | JD Bronze has (underlying detail) |
|---|---|---|
| `df_BranchOperational_Raw` | `BranchOperational` (View) | — (no obvious underlying detail table found) |
| `df_Technician_Raw` | `Technician` (View) | — |
| `df_TechnicianAttendance_Raw` | `TechnicianAttendance` (View, "aggregated view (not detail table)" per its own header) | `TechnicianAttendanceDetail` |
| `df_TechnicianEfficiency_Raw` | `TechnicianEfficiency` (View) | derived from `TechnicianAttendanceDetail` + `TechnicianPunchedDetail` + `TechnicianInvoiceDetail` |
| `df_TechnicianInvoice_Raw` | `TechnicianInvoice` (View) | `TechnicianInvoiceDetail` |
| `df_TechnicianPunchedTime_Raw` | `TechnicianPunchedTime` (View) | `TechnicianPunchedDetail` |

`BranchOperational` is already handled (built via direct `Dataflow Gen2` pull this
session, since it has no JD Bronze equivalent at all — same finding, independently
reconfirmed here). The four Technician-family views are a real, undone design
question: JD's mirror gives us the three *Detail tables already migrated in Category
A, but the view logic that turns them into `TechnicianAttendance` /
`TechnicianInvoice` / `TechnicianPunchedTime` / `TechnicianEfficiency` would need to
be re-derived from scratch in a notebook. Not a cheap win — flagging it here so it's
catalogued, not attempting it now.

## Category C — Real table, genuinely excluded from JD's mirror (same pattern as `jdis_Part_Information`)

Confirmed real, queryable tables on `dsn=EquipRDB64` (not views — same `Odbc.Query`
pattern as everything in Category A) that simply don't appear anywhere in JD's 156-
table Bronze mirror. Same handling as `jdis_Part_Information` and
`BranchOperational` before it: continue pulling these directly via Dataflow Gen2, no
shortcut is possible.

| Current dataflow | Source table |
|---|---|
| `df_JDIS_PART_INFORMATION_Raw` / `df_NonJD_Parts_Ordering_Raw` | `jdis_Part_Information` — **already migrated this session** (tiered Active/Dead split) |
| `df_ArMaster_Contact` | `ArMaster_Contact` |
| `df_Insalpar_Audit_Raw` | `InSalPar_Audit` |
| `df_Parts_InterbranchTransfer_Raw` | `Parts_InterbranchTransfers` |
| `df_RepairOrderDetail_Raw` | `RepairOrderDetail` |

No obvious common thread across these four (not all high-volatility like
`jdis_Part_Information`) — worth asking JD/Ben about at some point, but not blocking;
they just stay on direct ODBC pulls like today.

## Category D — Not a database source at all (out of scope for this comparison)

| Dataflow | What it actually is |
|---|---|
| `df_Raw_PriceUpdate_History` | Parses JD-supplied `PriceUpdate_*.txt` files landed in the Lakehouse Files folder — no ODBC/database source at all. **This is the "price update stuff" flagged as needing different handling** — there's no JD Bronze equivalent to compare against because it was never a database pull; it's JD's own external file drop. Leave alone / handle separately from the rest of this migration. |
| `df_Raw_JDNationalChangeReport_History` | Same category — file-based history parsing, not a database table. |
| `df_ServiceTimeSheets_Raw` | Parses uploaded Excel timesheets, not a database source. |
| `df_PartsLookup_Sync` | Downstream sync step (pushes `InMaster_PartsLookup_Raw` into the Parts Availability Fabric App's own SQL database) — not a raw source pull, filed under "01 - Raw Sources" but functionally belongs with the Facts/App layer. |

## Summary

| Category | Count | Migration path |
|---|---|---|
| A — direct shortcut match | 27 dataflows (~21 tables) | Cheap win, proven pattern (`InTrans`/`GlTrans` precedent) |
| B — view, needs rebuild | 5 dataflows | Real design work — notebook rebuild of view logic, not a shortcut |
| C — genuinely excluded from JD mirror | 4 dataflows (+ `jdis_Part_Information`, already done) | Stays on direct ODBC pull, same as today |
| D — not a DB source | 4 dataflows | Out of scope for this migration entirely |

**Not covered here:** `02 - Analysis`, `03 - Dimensions`, `04 - Facts`, `05 -
Snapshots`, `99 - Utilities` folders in `LH_Master_Data` — this catalog is Raw
Sources only, the layer everything else depends on.
