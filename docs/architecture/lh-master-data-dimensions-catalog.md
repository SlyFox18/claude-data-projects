# LH_Master_Data Dimensions Catalog (2026-09-10)

Full re-audit of every dataflow in `LH_Master_Data / Dataflows / 03 - Dimensions`
(active folder + `Archive Dimensions/`) against real, currently-deployed report
usage. Supersedes `projects/refresh-pipeline/dimension-analysis.md` (dated
2026-02-19, now 7 months stale) as the source of truth — that doc is left in
place for historical reference but should not be trusted for current decisions.

## Methodology (read this before trusting any other dim-usage claim in this repo)

Two real blind spots were found and corrected this session, both worth keeping in
mind for any future dimension/report work:

1. **A report's local README/CLAUDE.md status label can be stale.** `open-order-parts-advisor/README.md`
   says "Status: In Development" for **Job Code Parts Advisor** — it's actually
   **live in `RP - Service Reports` production** right now. Local status docs are not
   authoritative; `fab ls` against the real workspaces is.
2. **A report can be live in Fabric with zero local git tracking.** `Key Customers`
   and `Top 50 - Job Codes` (both in `RP - Sandbox`) have no corresponding folder
   anywhere in `data-projects/projects/` — they were built directly in Desktop/Fabric
   and never committed. A pure local-repo grep silently misses these; both had to be
   `fab export`-ed directly to check their real table lists.

**Ground truth used for this catalog:** `fab ls` against all 4 relevant workspaces
(`RP - Parts Reports`, `RP - Service Reports`, `RP - Financial Reports`, `RP - Sandbox`),
2026-09-10:

| Workspace | Live semantic models |
|---|---|
| RP - Parts Reports (17) | Bin Location Report, Combine Vault Sales, First Pass Fill, Inventory Analysis, MD Invoices With No Freight, Negative On Hand-On Hand No Bin, Open Parts Tickets, Part Sales with Low Margin, Parts Adjustments, Parts Not Re-Ordered 24 Hours, Parts Promo, Physical Inventory, Pin Capture, Price Matrix, Table-Column-Names-Search, Transfers, Unique Parts Customers |
| RP - Service Reports (8) | Customer Anatomy V2, Inspections, **Job Code Parts Advisor**, Labor Performance, Open Work Orders, Planter Inspection Part Sales, Planter Inspection Part Sales - V1, Stock Check |
| RP - Financial Reports (1) | 60+ Days Past Due |
| RP - Sandbox (7) | Customer Anatomy, **Key Customers**, Parts Action Dashboard, Parts Promo, Service Time Sheets, **Top 50 - Job Codes**, Transfer App |

Local-only/retired reports found during the search (`Open Orders Parts Advisor`, `JD Price Updates`,
`Physical Inventory - V2`, `Associated Parts`, `Aftermarket - Parts Orders`) are all
genuinely in-development or exploratory — none are a tracking gap like the two above,
just not deployed yet.

## Pipeline wiring (real, verified 2026-09-10)

Every `RefreshDataflow` activity in `Pipeline_Dimensions` (daily) and
`Pipeline_Dimensions_Monthly` was resolved by its actual `dataflowId` GUID against
each dataflow's own `.platform` `logicalId` — not by trusting the pipeline
activity's label (one label, `Refresh_CustomerLookup`, actually pointed at a
dataflow filed under `04 - Facts`, not `03 - Dimensions`).

**No weekly dimension pipeline exists** — only daily and monthly. Confirmed by
listing every pipeline in the workspace.

## Full dimension matrix

| Dataflow | Landed table | Pipeline tier | Real live usage (2026-09-10) | Status |
|---|---|---|---|---|
| df_Dim_Part | dim_Parts | daily | 18 reports (Customer Anatomy V2, Inspections, Inventory Analysis, Job Code Parts Advisor, and 14 more, all `RP - Parts/Service Reports`) | Correctly tiered, heavily used |
| df_Dim_Customer | dim_CustomerList | daily | 10 reports (60+ Days Past Due, Customer Anatomy V2, Inspections, MD Invoices, Open Work Orders, Part Sales w/ Low Margin, Parts Promo, Pin Capture, Planter Inspection, Unique Parts Customers) | Correctly tiered |
| df_Dim_Date | dim_DateTable | daily | 24 reports across all 4 workspaces, including Job Code Parts Advisor and Parts Action Dashboard | Correctly tiered, most-used dim |
| df_UniqueCustomer_Lookup | lookup_UniqueCustomers_Invoice | daily | Customer Anatomy V2 only | Correctly tiered |
| df_dim_UniqueCustomers | dim_UniqueCustomers | daily | Unique Parts Customers only | Correctly tiered |
| df_Dim_Branch12_Parts | dim_Branch12_Parts | daily | Combine Vault Sales only | Correctly tiered |
| df_Dim_BranchPartInventory | dim_BranchPartInventory | daily | Combine Vault Sales only | Correctly tiered |
| df_Dim_Technicans | dim_Technician_Code_Names | daily | Labor Performance, Open Work Orders, Service Time Sheets (Sandbox) | Correctly tiered (2026-02 doc suggested weekly, never implemented — daily is fine, table is small) |
| df_Dim_JobCode | dim_JobCode | daily | First Pass Fill only | Correctly tiered |
| df_Dim_RepairOrder | dim_RepairOrder | monthly | Parts Promo only | Correctly tiered. **Naming collision to be aware of:** unrelated to the new `DP_Presentation.dim_RepairOrder` built this session in the JD Bronze redesign — same name, completely different system/lineage, don't confuse the two |
| df_Dim_Salesperson | dim_Salesperson | daily | MD Invoices With No Freight, Stock Check | Correctly tiered |
| df_Dim_Location | dim_BranchLocation | monthly | 22+ reports, nearly every live report | Correctly tiered (static reference data) |
| df_Dim_DealerGroupCode | dim_DealerGroupCode | monthly | Bin Location Report, Inventory Analysis, Price Matrix | Correctly tiered |
| df_Dim_Franchise | dim_Franchise | monthly | Bin Location Report, Inventory Analysis, MD Invoices, Price Matrix | Correctly tiered |
| df_Dim_SLC | dim_SLC | monthly | Inventory Analysis, Price Matrix | Correctly tiered |
| df_Dim_Source | dim_Source | monthly | Inventory Analysis, Price Matrix | Correctly tiered |
| df_Dim_VendorCode | dim_VendorCode | monthly | Inventory Analysis, Price Matrix | Correctly tiered (see known `VendorCode` branch-variance limitation, `project_dim_parts_vendorcode_limitation.md`) |
| df_Dim_ModuleType | dim_ModuleType | monthly | Inventory Analysis only | Correctly tiered |
| df_Dim_CommodityCode | dim_CommodityCode | monthly | Inventory Analysis only | Correctly tiered |
| df_Dim_PaymentMethod | dim_PaymentMethod | monthly | Inventory Analysis only | Correctly tiered |
| df_Dim_AdjustmentType | dim_AdjustmentType | monthly | Parts Adjustments only | Correctly tiered |
| df_Dim_PromoType | dim_PromoType | monthly | Parts Promo only | Correctly tiered |
| df_Dim_JobType | Dim_JobType | monthly | **`Top 50 - Job Codes` only** (RP - Sandbox, untracked locally — confirmed via direct `fab export`, invisible to a local-repo grep) | Used by a deliberately dormant report (Brian: "worth holding on to... not actively being used, but may in the future") — leave the monthly refresh as-is, cheap and correct given the report may return |
| **df_Dim_BranchUserAccess** | dim_BranchUserAccess | **NONE — not wired into any pipeline** | Parts Action Dashboard (RP - Sandbox, not live in production yet) | **Real gap.** RLS-mapping table (branch security) for a report not yet live — needs pipeline wiring before that report goes live |
| **df_Dim_WKCDPART** | dim_WkcdPart | **NONE — not wired into any pipeline** | **Job Code Parts Advisor — LIVE IN PRODUCTION** (`RP - Service Reports`) | **Real, active production bug.** Serving frozen/never-refreshed data since deployment. Noted with Brian 2026-09-10, deferred to fix together with the item below rather than as an emergency patch |
| **df_Dim_WkCodeFl** | dim_JobCodes | **NONE — not wired into any pipeline** | **Job Code Parts Advisor — LIVE IN PRODUCTION** (`RP - Service Reports`) | Same as above. **Naming collision to fix while wiring this in:** `dim_JobCodes` (this table) vs `dim_JobCode` (df_Dim_JobCode, a completely different dataflow, daily-refreshed) — easy to confuse, worth a clearer name |
| **df_Dim_PartDemands** | dim_PartDemands | **NONE — not wired into any pipeline** | **Zero live usage anywhere** — not referenced by any current report, tracked or untracked | **True dead code.** Real archive candidate |
| df_CustomerLookup | CustomerLookup | daily (misfiled under `04 - Facts/Customer Anatomy Queries/`, not `03 - Dimensions`) | **Ambiguous** — zero direct TMDL table references found, but the Feb 2026 doc describes it as "Fact-building helper, refreshes with dims for ordering" for Customer Anatomy V2, meaning it may feed that report's own Fact dataflow as an intermediate step rather than being loaded into the semantic model directly | Needs verification before any action — don't assume dead from a TMDL grep alone, since it may not be a report-facing table at all |

## Archived dims (`Archive Dimensions/`, 9 total) — sanity-checked, still correctly archived

`df_Dim_Branch`, `df_Dim_BranchFranchise`, `df_Dim_InvoiceLookup`, `df_Dim_InvoiceType`,
`df_Dim_SlicerControl`, `df_Dim_Vehicle`, `df_Dim_WorkOrderLookup`, `df_Dim_WorkOrderMaster`,
`df_Dim_WorkOrderType` — none wired into any pipeline (confirmed), and every local TMDL
reference to any of their landed tables lives inside an `archive`/`old report` folder.

**One real finding during the sanity check:** `df_Dim_Branch` (`Dim_Branch`) is still
referenced by a genuinely **live** report — `Key Customers` (`RP - Sandbox`, untracked
locally). Brian confirmed 2026-09-10 this report has been **replaced by Customer Anatomy**
(which folds in the Key Customer functionality) — `Key Customers` itself is retired even
though it's still technically deployed. No action needed on the archived `df_Dim_Branch`
dataflow; `Key Customers` itself is a cleanup candidate (delete the live Sandbox item)
whenever Brian wants to do that housekeeping — not urgent, not addressed by this catalog.

## Summary of real findings

1. **Real, active production bug:** `Job Code Parts Advisor` is live in `RP - Service Reports`
   but its 2 dimension tables (`dim_WkcdPart`, `dim_JobCodes`) have never been refreshed —
   noted with Brian, deferred to fix alongside the other pipeline-wiring gaps below rather
   than patched immediately.
2. **`dim_PartDemands` is true dead code** — zero pipeline wiring, zero live usage anywhere. Archive candidate.
3. **`dim_BranchUserAccess` needs pipeline wiring before Parts Action Dashboard goes live** (RLS-critical table).
4. **Naming collision, `dim_JobCode` vs `dim_JobCodes`** — worth a clearer name for the latter when it gets wired in.
5. **`CustomerLookup` is misfiled** under `04 - Facts/Customer Anatomy Queries/` instead of `03 - Dimensions`, and its real usage is ambiguous (may be a Fact-building intermediate, not a report-facing table) — needs verification before any action.
6. **Two live Sandbox reports (`Key Customers`, `Top 50 - Job Codes`) are completely untracked in git** — a process gap distinct from the dimension audit itself, worth deciding whether to pull them into the repo.
7. Every other actively-refreshed dim (23 of the 26 in the active folder) checked out as **correctly tiered and genuinely used** — the Feb 2026 doc's daily/monthly assignments still hold up against current real usage.
8. The 9 already-archived dims are correctly archived — no live production dependency found on any of them, aside from the retired `Key Customers` report noted above.

**Not yet decided / needs Brian's direction:**
- Whether to fix the `Job Code Parts Advisor` pipeline-wiring gap now or bundle it with other fixes
- Whether to archive `dim_PartDemands`
- Whether to rename `dim_JobCodes` while wiring it in
- What `CustomerLookup` actually feeds, before deciding whether to relocate/keep/retire it
- Whether to pull `Key Customers`/`Top 50 - Job Codes` into the local repo, and whether to delete the retired `Key Customers` Sandbox item
