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
| Shannon / **Aftermarket - Parts Orders** (model) | `dim_BranchLocation` + its own tables | **High priority**: move to DP. Shannon uses it daily |
| RP - Dev / **Transfer App** (model) | `dim_BranchLocation`, `dim_DateTable` | Research what it is (see [[project_transfer_app_bin_data_source]]) |
| LH_Master_Data / **TopJobCode_Analysis_Model** | `Fact_Top_JobCode_Anaysis`, `Dim_JobType`, `dim_JobCode`, `dim_BranchLocation`, `dim_DateTable` | Low priority: research whether it's still needed |
| RP - Data Agent / **Parts & Invoice - Data Query Agent**, **Customer Lookup - Data Agent** | Lists every LH dim, `Invoice`, `InTrans_Incremental`, `jdis_Part_Information`, `wkrodesc`, `BranchOperational` | Repoint to DP (Customer Lookup repoint was already on the list) |
| RP - Data Agent / **SPI Service Operations Assistant** | `dim_BranchLocation`, `Invoice` | Repoint to DP |
| LH - Service_Data_Prep / **Inspections_Data_Agent** | `Invoice` (which lakehouse not yet confirmed) | Check |
| **Parts Availability** app | `df_InMaster_PartsLookup_Raw` output (hourly) | Own project; live and critical |
| Non-JD Parts Order Tool | LH raw tables | Paused since 2026-08-04 (Brian's call) |
| fabric-monitoring 6 AM scheduled task | Watches `Pipeline_Master_Orchestrator` | Retire or repoint with the orchestrator |

## Scheduled items (14 found 2026-10-09)

| Item | Schedule | Status / blocker |
|---|---|---|
| Pipeline_Monthly_MDInvoices_Snapshot | Monthly, 1st 05:30 | **OFF 2026-10-09.** Verified idle: the MD Invoices report reads DP's own `Fact_MDInvoices_NoFreight_Snapshot` (history copied to DP Dev and Prod); no model, agent or LH item reads the LH copy |
| Pipeline_Dimensions_Monthly | Monthly, 1st 07:30 | **Keep for now.** `dim_BranchLocation` feeds Shannon's model, Transfer App, TopJobCode and 3 data agents; `Dim_JobType` feeds TopJobCode; the agents list every dim. Next run 11/1. Off once those readers move |
| Pipeline_Master_Orchestrator | Weekdays 04:15 | **Biggest CU cost.** Refreshes the raw/dim/fact tables the readers above use. Off once they move; retire the monitoring task with it |
| DF_PartMaster_Snapshot_Daily / _Weekly + NB_PartMaster_Retention_Policy | Daily 02:00 / Sunday 01:00 / monthly | **Important; next to design.** The only history of the `jdis_Part_Information` view, which has answered past-date questions several times. Rebuild on DP from JD Bronze and **carry the existing history over** |
| pl_Raw_PriceUpdate_History | Weekdays 02:00 | Off after the JD price backend reaches DP Prod (plan `2026-10-08-jd-price-data-dp.md` Task 9–10). Also disable the PC task `\Fabric\JD Price Update Harvest` |
| Pipeline_PartsNotReordered_QuickRefresh, df_Fact_PartSales_24Hours | 11:00; 09:30 + 15:30 | The old intraday refresh. Parts Not Re-Ordered is on DP with a daily refresh only. **Separate intraday project** (Brian checking with users); may apply to other reports |
| df_InMaster_PartsLookup_Raw | Hourly 07:50–16:50 weekdays | Parts Availability. **Separate project, handle with care** |
| df_ServiceTimeSheets_Raw, df_ServiceTimeSheet_AuditLog, df_Fact_ServiceTimeSheet_Audit | Weekdays 09:00–09:15 | Old Service Time Sheets feeds (DP has its own `df_ServiceTimeSheets_Raw` and `df_ServiceTimeSheet_AuditLog`). Research the readers, including the Power Automate audit flow |
| df_Fact_InternalWorkOrders | Weekdays 07:30 | Unknown reader. Research |
| ​Pipeline_SemanticModels_V2 | (off) | Brian turned it off at cutover (2026-10-07) |
