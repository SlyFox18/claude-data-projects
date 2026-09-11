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
| df_Dim_JobCode | dim_JobCode | daily | First Pass Fill only | **Real finding (2026-09-11):** loaded into First Pass Fill's live model, but only 3 of its ~11 columns (`JobCode`, `JobCodeDisplayName`, `JobCodeShortDesc`) are referenced anywhere in that report (visuals, measures, relationships). The other 8 — the whole "intelligent business categorization" layer (`JobCodeCategory`, `EquipmentType`, `EquipmentCategory`, `ServiceComplexity`, `IsInspection`, `IsWarrantyWork`, `IsSeasonalWork`, `IsUrgentWork`), built via text-pattern-matching heuristics — are imported but touched by nothing downstream. Matches Brian's own memory: built for Inspections, "didn't work right," Inspections went a different route, dead weight rode along into First Pass Fill's model instead. Real simplification opportunity for the DP-backend rebuild — likely just needs the 3 real columns |
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
| df_Dim_BranchUserAccess | dim_BranchUserAccess | NONE — not wired into any pipeline | Parts Action Dashboard (RP - Sandbox) — but that report ended up going a different route (Power Automate email to parts managers, since they don't have Power BI access yet) | **Not dead — built ahead of need.** Brian: worth holding onto for future RLS access once parts managers get Power BI access. No action needed now |
| df_Dim_WKCDPART | dim_WkcdPart | NONE — not wired into any pipeline | Job Code Parts Advisor — live in `RP - Service Reports`, but usage is low right now and the report may evolve | Serving frozen data, but Brian: not a priority at this point — **note for when we work through reports/refresh scheduling on the new (DP) system**, not an emergency patch |
| df_Dim_WkCodeFl | dim_JobCodes | NONE — not wired into any pipeline | Job Code Parts Advisor — same as above | Same as above. **Naming collision confirmed real** by Brian (didn't remember which dataflow built `dim_JobCodes` until this catalog resolved it) — worth a clearer name whenever this gets wired in |
| df_Dim_PartDemands | dim_PartDemands | NONE — not wired into any pipeline | Zero live usage anywhere yet | **Not dead — built recently, ahead of use.** Brian: may be valuable in the future, just hasn't been put into use yet. No action needed now |
| df_CustomerLookup | CustomerLookup | daily (misfiled under `04 - Facts/Customer Anatomy Queries/`, not `03 - Dimensions`) | Used in building Customer Anatomy V2's fact tables, not as a report-facing dim (confirmed by Brian) | Deferred — Brian: address this when we get to the facts/report side of this work, not now |

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

## Summary of findings (updated 2026-09-11 with Brian's corrections)

1. **`Job Code Parts Advisor`'s 2 unrefreshed dims** (`dim_WkcdPart`, `dim_JobCodes`) — real,
   but not a priority right now (low current usage, report may evolve). **Noted for later:**
   address when working through reports/refresh scheduling on the new (DP) system.
2. **`dim_PartDemands` and `dim_BranchUserAccess` are NOT dead** — both built ahead of need,
   intentionally not yet in use, kept for future value. No action needed on either.
3. **`dim_JobCode` vs `dim_JobCodes` naming collision confirmed real** — worth a clearer name
   for `dim_JobCodes` whenever it gets wired in (not urgent, bundled with item 1).
4. **`dim_JobCode` (First Pass Fill) has a real, concrete quality finding:** 8 of its ~11
   columns — an entire speculative "intelligent business categorization" layer — are loaded
   into the live model but touched by nothing downstream. See the matrix row above. First
   confirmed example of the "loaded but not really used" pattern this catalog is now hunting
   for systematically (see next section).
5. **`CustomerLookup`** feeds Customer Anatomy V2's fact-table build, not the report directly —
   deferred to the facts/report phase of this work, not a dimensions-catalog concern.
6. **`Key Customers`/`Top 50 - Job Codes`** are live-but-untracked Sandbox reports — noted,
   revisit later, not a priority right now.
7. The 9 already-archived dims are correctly archived — no live production dependency on any
   of them, aside from the retired `Key Customers` report (already accounted for above).

## Next phase: column-usage-depth audit (started 2026-09-11)

**Goal, per Brian's direction:** for every dim genuinely in current use, don't just confirm
"is the table used" (this catalog's first pass) — check **which of its columns are actually
referenced by anything downstream** (report visuals, measures, relationships), the same method
that found `dim_JobCode`'s 8 dead columns. This is prep work for rebuilding each dim on the new
DP backend: know exactly what's real before deciding what the rebuilt version should carry.

**Scope:** the 21 dims confirmed in real current use (excludes `dim_JobCode`, already done;
excludes `dim_PartDemands`/`dim_BranchUserAccess`, not yet in use; excludes the 2 `Job Code
Parts Advisor` dims and `CustomerLookup`, both explicitly deferred above).

Broken into batches, same approach as the raw-sources migration:

**Batch 1 — simple monthly reference-code dims (11):** `dim_AdjustmentType`, `dim_CommodityCode`,
`dim_DealerGroupCode`, `dim_Franchise`, `dim_ModuleType`, `dim_PaymentMethod`, `dim_PromoType`,
`dim_RepairOrder`, `dim_SLC`, `dim_Source`, `dim_VendorCode` — each used by 1-4 reports, small
static code tables. Likely quick, mechanical checks.

**Batch 2 — smaller daily operational dims (6):** `dim_Branch12_Parts`, `dim_BranchPartInventory`,
`dim_Salesperson`, `dim_Technician_Code_Names`, `lookup_UniqueCustomers_Invoice`, `dim_UniqueCustomers`
— each used by 1-3 reports, more behavioral/operational than the reference codes above.

**Individually — the 4 heaviest-hitters (10-24 reports each, highest blast radius):**
`dim_CustomerList`, `dim_DateTable`, `dim_Parts`, `dim_BranchLocation` — same treatment `Invoice`
got in the raw-sources work, one at a time, given their complexity and how many reports touch each.

## Batch 1 results (2026-09-11) — column-usage-depth audit, 11 simple reference dims

**A clear, repeatable pattern emerged:** every dim with only 2-3 columns (a surrogate key plus
1-2 plain lookup fields) checks out completely clean. Every dim with an elaborate,
"comprehensive business intelligence"-style header — extra categorization/scoring/flag columns
beyond the basic key+description — has most of that elaboration sitting unused in every live
report that touches it. Same shape as the `dim_JobCode` finding that kicked this phase off.

| Dim | Real columns | Genuinely used (visuals/measures/relationships) | Finding |
|---|---|---|---|
| `dim_AdjustmentType` | 5 | **0 of 5** (relationship exists but on `AdjustmentTypeName`, not the `AdjustmentTypeKey` surrogate the dataflow's own header describes) | Table is never actually surfaced in any Parts Adjustments visual. Relationship joins on a text field instead of the intended surrogate key — fragile if names ever change |
| `dim_CommodityCode` | 2 (`CommodityCodeKey`, `CommodityCode`) | Both | Clean. A 3rd column (`CommodityGroup`) is planned but explicitly not yet applied to production — already tracked in `project_commodity_code_groups.md`, not a new finding |
| `dim_DealerGroupCode` | 2 | Both | Clean, simple, no issues |
| `dim_Franchise` | 15 | **4 of 15** (`FranchiseKey`, `Franchise`, `FranchiseCode`, `FranchiseDisplayName`) | The other 10 — an entire "comprehensive brand intelligence" layer (`FranchiseType`, `FranchiseCategory`, `MarketPosition`, `ServiceComplexity`, `FranchiseSortOrder`, `BusinessPriority`, `FranchiseStatus`, `IsPrimaryBrand`, `IsAgriculturalBrand`, `IsMajorBrand`) — are unused across all 4 live consuming reports (Bin Location, Inventory Analysis, MD Invoices, Price Matrix) |
| `dim_ModuleType` | 5 | 3 of 5 (`ModuleTypeKey`, `ModuleTypeDescription`, `SortOrder`) | `BusinessGrouping` (a documented "business requirement") and `RecordCount` (a dev validation field) unused in Inventory Analysis. Separately, the classification logic hardcodes ~40 specific customer numbers into 2 arrays (`InternalCustomers`, `WarrantyCustomers`) to override standard ModuleType mapping — a new Internal/Warranty customer added to the source system won't be classified correctly until someone remembers to update this M code by hand |
| `dim_PaymentMethod` | 5 | All 5 | Clean, genuinely used in Inventory Analysis |
| `dim_PromoType` | 6 (3 documented + 3 undocumented: `FirstSeen`, `LastSeen`, `UsageCount`) | **0 of 6 displayed** (only the relationship key, `PromoPartNo`, is wired) | Entire table imported and related in Parts Promo but contributes zero visible columns — not even the 2 columns the dataflow's own header describes as the point of the table |
| `dim_RepairOrder` | 15 (14 documented + 1 undocumented: `DiscountAmount`) | **1 of 15** (`CustomerNo`, plus the `REF_NO` relationship key) | The pre-aggregated order-level metrics (`TotalPartsSales`, `NetOrderValue`, `OriginalMargin`, `NetMargin`, `DiscountPercent`, etc.) are well-designed — genuinely good pre-aggregation logic that replaced a runtime self-join — but none of it is surfaced in Parts Promo today. "Good bones, unused," not badly built |
| `dim_SLC` | 2 | Both | Clean, simple, no issues |
| `dim_Source` | 2 | Both | Clean, simple, no issues |
| `dim_VendorCode` | 2 | Both | Clean, simple, no issues. **Not** the same table as the known `VendorCode` branch-variance limitation (`project_dim_parts_vendorcode_limitation.md`) — that issue is on `dim_Parts.VendorCode` (a part-level attribute), this is a separate flat reference-code lookup |

**Takeaway for the DP-backend rebuild:** build what's proven needed (matching the discipline
already used for raw sources — e.g. `InMaster`'s `IN_TRANSIT_QTY` addition was a specific,
proven need, not speculative). For every dim rebuilt going forward, carry over only the columns
confirmed genuinely used here; anything speculative can be added later if a real, identified
need shows up (same as the raw-sources precedent), rather than rebuilding unused categorization
layers by default.
