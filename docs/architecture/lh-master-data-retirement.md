# LH_Master_Data Retirement Tracker

**Goal (Brian, 2026-10-09):** stop everything scheduled in LH_Master_Data once DP covers it, so CU isn't spent twice.

**Rules:**
- **Switch off schedules only.** Delete nothing without Brian's careful review.
- **Switch a schedule off only after verifying** that nothing live reads what it writes. A "reader" is any of:
  - a report or semantic model;
  - a data agent;
  - an app;
  - a Power Automate flow;
  - another LH item that is itself still needed.
- **Record the evidence here.**

**How "readers" were checked (2026-10-09):**
- Every semantic model in the 23 workspaces Brian can see: datasources pointing at the LH SQL endpoint.
- Every data agent and org app: their definitions.
- Every LH dataflow and notebook in fabric-workspace-docs: text references.
- Every lakehouse shortcut file in the repo.
- Helper scripts were throwaway; re-derive them from this description.

## Who still reads LH_Master_Data

| Reader | Reads | Plan |
|---|---|---|
| Shannon / **Aftermarket - Parts Orders** (model) | `dim_BranchLocation` (its main table is hourly ODBC, not LH) | **Moved 2026-10-09** (PRs #29, #30). The copy in **RP - Parts Reports** reads `dim_BranchLocation` from DP, and its InMaster join now includes Franchise (~3,500 duplicate rows removed). Hourly schedule (weekdays 08:00–18:00 Central) set on the new model, owned by Brian. Left for Brian: add it to the Parts org app + audience, send Shannon the link, then switch off the old "Shannon" workspace model's schedule. The ODBC main table moves to DP in the intraday project |
| RP - Dev / **Transfer App** (model) | `dim_BranchLocation`, `dim_DateTable` + a SharePoint shipment-tracking list | **Parked (Brian, 2026-10-09).** Proof of concept for reporting on the driver-transfer Power App, which was replaced by a Fabric App (RP - Fabric Apps, no Power BI report). Stays in RP - Dev as is; never refreshed, no schedule, not in the DP config. Not the live "Transfers" report, which is on DP |
| LH_Master_Data / **TopJobCode_Analysis_Model** | `Fact_Top_JobCode_Anaysis`, `Dim_JobType`, `dim_JobCode`, `dim_BranchLocation`, `dim_DateTable` | **Parked (Brian, 2026-10-09).** An experiment for the Top 50 Job Codes report; no report uses it; last refreshed 12/1/2025; no schedule. Left alone; goes with LH when the workspace is retired. The **Top 50 - Job Codes** report stays in RP - Dev as a starting point (never refreshed, no schedule) |
| RP - Data Agent / **Parts & Invoice - Data Query Agent**, **Customer Lookup - Data Agent**, **SPI Service Operations Assistant** | LH dims, `Invoice`, `InTrans_Incremental`, `jdis_Part_Information`, `wkrodesc` | **Don't block anything (Brian, 2026-10-09).** They were an experiment and stale data is fine. Brian removed all user access to the RP - Data Agent workspace on 2026-10-09. Review later whether they're needed at all |
| LH - Service_Data_Prep / **Inspections_Data_Agent** | `Invoice` (which lakehouse not yet confirmed) | Check |
| **Parts Availability** app | `df_InMaster_PartsLookup_Raw` output (hourly) | Own project; live and critical |
| Non-JD Parts Order Tool | LH raw tables | Paused since 2026-08-04 (Brian's call) |
| fabric-monitoring 6 AM scheduled task ("Post-Pipeline Monitoring") | Watched `Pipeline_Master_Orchestrator` | **Disabled 2026-10-09** with the orchestrator. The DP refresh sends its own summary email |

## Scheduled items (14 found 2026-10-09)

> **Status at end of 2026-10-09:** 9 of the 14 are off.
> - **Still on:** the PartMaster snapshots + retention notebook, the interim `jdis` schedule, `pl_Raw_PriceUpdate_History`, and `df_InMaster_PartsLookup_Raw` (Parts Availability).
> - **Check 2026-10-10:** the 1:15 `jdis` run, the 2 AM snapshot (fresh data) and the 6:15 DP refresh, on the first night without the orchestrator.

| Item | Schedule | Status / blocker |
|---|---|---|
| Pipeline_Monthly_MDInvoices_Snapshot | Monthly, 1st 05:30 | **OFF 2026-10-09.** Verified idle: the MD Invoices report reads DP's own `Fact_MDInvoices_NoFreight_Snapshot` (history copied to DP Dev and Prod); no model, agent or LH item reads the LH copy |
| Pipeline_Dimensions_Monthly | Monthly, 1st 07:30 | **OFF 2026-10-09.** Brian: `dim_BranchLocation` never changes (only with new stores); the data agents don't block anything |
| Pipeline_Master_Orchestrator | Weekdays 04:15 | **OFF 2026-10-09** (Brian, option A). Verified that no live reader needs daily-fresh LH data:<br>• Shannon's model gets its main table over ODBC; its only LH table is the static `dim_BranchLocation`.<br>• Transfer App reads SharePoint plus static LH dims.<br>• Parts Availability reads over ODBC directly.<br>• TopJobCode and the agents can go stale.<br>The only real dependency was the PartMaster snapshots, now fed by `df_JDIS_PART_INFORMATION_Raw`'s own schedule. PC task "Post-Pipeline Monitoring" **disabled** 2026-10-09 |
| df_JDIS_PART_INFORMATION_Raw | **Mon–Sat 01:15 (added by Brian 2026-10-09)** | Interim: keeps LH `jdis_Part_Information` current for the PartMaster snapshots (02:00) after the orchestrator is off. Takes 6–9 minutes. Retire with the snapshots once they're on DP |
| DF_PartMaster_Snapshot_Daily / _Weekly | Daily 02:00 / Sunday 01:00 (schedules end 12/31/2026) | **The DP replacement is live in Prod (2026-10-09; archives in Prod).** Side-by-side check from 2026-10-12, then off. Plan `docs/superpowers/plans/2026-10-09-partmaster-history-dp.md`. Originally: spec `docs/superpowers/specs/2026-10-09-partmaster-history-dp-design.md`. Change-only `Fact_PartMaster_History` on DP, all 33 columns, kept forever; the old tables become frozen archives in DP Prod. Off after a ~2-week side-by-side run |
| NB_PartMaster_Retention_Policy | Monthly, 1st | **OFF 2026-10-09** (Brian) so no snapshot history is deleted before it's archived. Daily deletes would have started around 12/1 |
| pl_Raw_PriceUpdate_History | Weekdays 02:00 | **The DP replacement is live in Prod (2026-10-09).** Off after a few clean Prod days, with Brian's OK. Also disable the PC task `\Fabric\JD Price Update Harvest` |
| Pipeline_PartsNotReordered_QuickRefresh, df_Fact_PartSales_24Hours | 11:00; 09:30 + 15:30 | **OFF 2026-10-09.** QuickRefresh disabled. The `df_Fact_PartSales_24Hours` schedule had already expired on 12/31/2025; it only ran when the orchestrator called it, and Brian deleted the expired schedule (the dataflow stays). They refreshed LH tables nobody reads, then re-import the Parts Not Re-Ordered model, which now reads DP; DP data doesn't change between 6:46 AM and the next morning. Real intraday refresh on DP is a **separate project** (Brian checking with users) |
| df_InMaster_PartsLookup_Raw | Hourly 07:50–16:50 weekdays | Parts Availability (reads over ODBC directly, not from other LH tables). **Separate project, handle with care.** ⚠ **The schedule's end date is 8/18/2027.** Fabric schedules stop silently, so extend it or replace it before then |
| df_ServiceTimeSheets_Raw, df_ServiceTimeSheet_AuditLog, df_Fact_ServiceTimeSheet_Audit | Weekdays 09:00–09:15 | **OFF 2026-10-09.** They write LH `service_time_sheets`, `AuditLog`, `Fact_ServiceTimeSheet_Audit` and `Fact_InvoiceLabor`, which no model reads. The STS report uses DP's own dataflows; Power Automate writes to the SharePoint list, not to LH |
| df_Fact_InternalWorkOrders | Weekdays 07:30 | **OFF 2026-10-09.** Built for the Stock Check report (folder `04 - Facts/Stock Check`). Stock Check is on DP and reads DP's own `Build_Gold_InternalWorkOrders` → `Fact_InternalWorkOrders`, so the LH copy was a duplicate |
| ​Pipeline_SemanticModels_V2 | (off) | Brian turned it off at cutover (2026-10-07) |
