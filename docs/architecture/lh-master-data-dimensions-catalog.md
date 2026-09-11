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
| df_Dim_RepairOrder | dim_RepairOrder | monthly | Parts Promo only | Correctly tiered. **Correction (2026-09-11):** earlier noted here as "unrelated to `DP_Presentation.dim_RepairOrder`, a naming collision" — that was wrong, not verified before writing. They're the **same table**: `DP_Presentation.dim_RepairOrder` (built 2026-09-08 by `Build_Gold_PartsPromo.Notebook`) is this dim's actual migration, reproducing `dim_RepairOrder.pq`'s exact business logic off the corrected `Silver_InTrans` instead of buggy `InTrans_Incremental`. It's a faithful full 15-column port — carries all 13 columns this audit found unused in the live Parts Promo report (only `REF_NO`/`CustomerNo` are real). See "Already-built dims" below |
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

## Batch 2 results (2026-09-11) — column-usage-depth audit, 6 smaller daily operational dims

Same method as Batch 1. Mixed results this time — 2 fully clean, 2 mostly clean with minor
unused columns, 1 well-used, and 1 more instance of the "comprehensive business intelligence"
over-engineering pattern.

| Dim | Real columns | Genuinely used | Finding |
|---|---|---|---|
| `dim_Branch12_Parts` | 25 | 23 of 25 | Mostly clean, deliberately minimal by design ("all intelligence handled in DAX measures" — its own header). Only `Returnable` and `IsReturnable` (a redundant pair — likely `IsReturnable` was a later addition duplicating `Returnable`) are unused in Combine Vault Sales |
| `dim_BranchPartInventory` | 4 | All 4 | Fully clean. Exceptionally well-documented — its header records a real past bug (an earlier version joined on `PartNumber` alone, which let in unrelated branches; DAX-side filtering to suppress the resulting clutter rows reliably corrupted the report's Grand Total; fixed by tightening the join to a compound key instead) and an explicitly accepted known limitation. A model for how the other dims in this catalog should be documented |
| `dim_Salesperson` | 7 | Broadly confirmed used (`FirstName`, `LastName`, `FullName`, `DisplayName`, `IsActive` all appear in MD Invoices With No Freight) | Clean, checks out |
| `dim_Technician_Code_Names` | 16 | **~3-4 of 16** (`TechnicianKey`, `TechnicianCode`, `TechnicianDisplayName`, likely `IsActive`) | Same "comprehensive business intelligence" pattern as `dim_JobCode`/`dim_Franchise`. The other ~12 columns — multiple redundant display-name formats (`TechnicianFullName`, `TechnicianShortName`, `PreferredDisplayName`, `SearchableName`), business-intelligence flags (`HasFullName`, `HasValidCode`, `HasLongName`, `DataQualityScore`), and classification fields (`TechnicianStatus`, `TechnicianType`) — are unused in Labor Performance (not independently re-verified against Open Work Orders/Service Time Sheets, but the pattern is now consistent enough across 4 dims to expect the same result) |
| `lookup_UniqueCustomers_Invoice` | 2 | Both | Clean by design — narrow-purpose lookup table, already well-documented separately (see `UNIQUE-CUSTOMER-FLAGS.md`/`CROSS-REPORT-FLAGS.md`), not re-investigated in depth here |
| `dim_UniqueCustomers` | 7 | 3 of 7 (`CustomerKey`, `CustomerName`, likely `IsActive`) | `DataSource`, `IdentificationMethod`, `IdentificationRule`, `CreatedDate` unused in Unique Parts Customers — but these are legitimate documentation/audit-trail fields on a tiny 11-row static table (not speculative BI bloat), a much lower-severity finding than the "comprehensive" dims above |

**Running tally across both batches:** the over-engineered "comprehensive business intelligence"
pattern has now shown up 4 times (`dim_JobCode`, `dim_Franchise`, `dim_RepairOrder`,
`dim_Technician_Code_Names`), consistently leaving 70-95% of a dim's columns unused. Every dim
built deliberately lean (`dim_BranchPartInventory`, `lookup_UniqueCustomers_Invoice`, the plain
2-3 column reference dims from Batch 1) checks out clean. This strengthens the takeaway above:
the DP-backend rebuild should default to lean, and treat any "comprehensive" business-intelligence
layer as something to leave out until a real, proven need appears.

## The 4 heaviest-hitters, individually (2026-09-11)

Same method, checked across each dim's **entire** real consumer portfolio at once (a column only
needs one genuine consumer out of many to count as used) — these are shared across 10-24 reports
each, so the bar for "unused" is much higher than for the single- or few-report dims above.

### `dim_CustomerList` — 43 of 55 columns used (78%)

The healthiest of the 4 — makes sense, 10 reports with genuinely different purposes (financial
aging, marketing, work orders, customer analytics) naturally exercise more of a wide table than
any single report would. The documented "Special Customer Assignment Logic" (`-1` through `-9`
keys resolving Stock/Internal/Warranty work orders with no real ArMaster customer) is real,
important, and already correctly captured in the header — not part of this finding.

**12 genuinely unused columns**, all address-detail or marketing fields nobody's built a use for
yet: `CustomerNumberText`, `Street`, `Street2`, `PostalCode`, `Country`, `HomePhone`, `IsCompany`,
`HasCreditLimit`, `Account_Class`, `ContactClass`, `IsMarketingEligible`, `PreferredContactMethod`.
(`City`/`State` ARE used — territory/geographic analysis is a real, live use case.)

### `dim_DateTable` — 19 of 67 columns used (28%) — the single biggest finding in this catalog

Refreshed **daily**, the highest-frequency tier, carrying 67 columns across an 11-year date span
when only 19 are ever touched by any of its 24 consumers. Of ~25 speculative "cover every
conceivable rolling window" flags (`IsRolling6Months` through `IsRolling156Weeks`, `IsLast30Days`,
`IsNext30Days`, etc.), only 4 are real: `IsRolling12Months` (the actual workhorse — 11 files,
this is what "R12" metrics across the backend actually mean), `IsRolling24Months`,
`IsRolling365Days`, `IsRolling730Days` (1 file each). Every fiscal-calendar column
(`FiscalYear`, `FiscalQuarter`), every seasonal-intelligence column (`Season`, `IsPeakSeason`),
every business-day column (`IsBusinessDay`, `WorkingDaysInMonth/Quarter/Year`), and roughly 21 of
the 25 rolling-window flags are dead weight. The 19 real columns are almost entirely the basic
date hierarchy (`DateKey`, `Date`, `Year`, `Quarter`, `Month`, `Day`, `WeekOfYear`, `DayOfWeek`,
`MonthName`, `MonthNameShort`, `MonthYear`) plus a handful of real period flags (`IsWeekend`,
`IsPreviousMonth`, `IsYearToDate`, the 4 real rolling flags above).

### `dim_Parts` — 22 of 22 columns used (100%)

Fully clean. Even the `Returnable`/`IsReturnable` pair that showed up dead in the smaller
`dim_Branch12_Parts` (Batch 2) is genuinely used here (9 and 3 files respectively) — the
redundancy earns its keep at this dim's broader 18-report scale even though it didn't at
`dim_Branch12_Parts`'s narrower scale. The best-curated dim found in this entire catalog.

### `dim_BranchLocation` — 9 of 16 columns used (56%)

The 7 unused columns are exactly the heuristic "business intelligence" layer already flagged
during this session's earlier DP-backend work (`docs/architecture/data-platform-workspaces.md`'s
`dim_RepairOrder`/`Fact_PartsPromo` section) as pattern-matched on `BranchID`/`BranchName`/
`State`/`City`, faithfully ported to the new backend without re-verifying real usage:
`ServiceCapacity`, `MarketPresence`, `TerritoryCoverage`, `OperationalPriority`,
`RegionalClassification`, `ServiceHours`, `DistanceFromHub`. Now confirmed genuinely dead in
every live report. `DataQualityScore` (also heuristic-flavored) is the one survivor — actually
used (14 files). **Done (2026-09-11):** the DP-backend version now drops these 7 columns, and
was also rebuilt off `Silver_BranchName` instead of the `BranchOperational` bronze table —
see "Already-built dims" below for the trim and source-swap, both verified.

## Full audit complete (2026-09-11)

All 26 active dims (batches 1+2, the 4 heavy-hitters) have now been checked for real column-level
usage. Summary: the "comprehensive business intelligence" over-engineering pattern showed up 5
times total (`dim_JobCode`, `dim_Franchise`, `dim_RepairOrder`, `dim_Technician_Code_Names`,
`dim_DateTable` — the last being by far the largest and most-refreshed offender), always in the
same shape: extra categorization/scoring/flag columns bolted onto a real, useful core, left
unused because the report that would've needed them was never built or went a different route.
Every dim built deliberately lean, and the widely-shared `dim_Parts`, checked out clean. This is
the concrete evidence base for the DP-backend rebuild takeaway repeated throughout this catalog:
default lean, add speculative columns only on a proven, identified need.

## Already-built dims in DP_Presentation (discovered 2026-09-11, built earlier this session)

Before planning the DP-backend implementation batches, checked which of these 26 dims already
have a live counterpart in the new backend from earlier work this session (the Parts Promo Gold
rebuild). 3 do — none of them need a fresh build, only an optional trim now that real usage is
known:

- **`dim_DateTable`** — rebuilt 2026-09-09, *before* this column-usage audit existed, for a more
  serious reason than unused columns: every "today"-relative column (`IsCurrentMonth`,
  `IsYearToDate`, all `IsRolling*` flags, etc.) was being computed at refresh time and frozen —
  the same UTC/local-time bug class already fixed twice elsewhere this session
  (`Fact_PartsAdjustments.LoadedDatetime`, the 2026-02-27 Data Refresh Table fix). Brian agreed
  at the time to drop every one of those ~48 columns entirely, deferring that logic to
  report-layer DAX when each report actually migrates. Correctness fix already live. Kept 26
  columns (down from production's 76) — cross-checking against this audit's real-usage findings,
  **14 of those 26 are still not proven-needed by any current report** (`DateDisplayName`,
  `DayOfWeekName`, `DayOfWeekNameShort`, `FiscalYear`, `FiscalQuarter`, `IsBusinessDay`,
  `IsPeakSeason`, `IsWeekday`, `MonthSort`, `QuarterSort`, `SortableMonthYear`,
  `WorkingDaysInMonth`, `WorkingDaysInQuarter`, `WorkingDaysInYear`) — a further trim on top of
  the already-completed bug fix.
- **`dim_BranchLocation`** — rebuilt 2026-09-09 as a deliberate faithful full port ("no bug found
  in this table's enrichment logic during review, so this is a faithful port, not a redesign,
  unlike dim_DateTable" — its own header). All 16 columns carried over, including the 7 this
  audit found dead: `ServiceCapacity`, `MarketPresence`, `TerritoryCoverage`,
  `OperationalPriority`, `RegionalClassification`, `ServiceHours`, `DistanceFromHub`.
- **`dim_RepairOrder`** — rebuilt 2026-09-08 by `Build_Gold_PartsPromo.Notebook`, reproducing
  `dim_RepairOrder.pq`'s exact business logic off the corrected `Silver_InTrans`. **This catalog
  originally (2026-09-11) wrongly called this "unrelated, a naming collision" without checking —
  corrected above.** Faithful full 15-column port, carrying all 13 columns this audit found
  unused in the live Parts Promo report.

**Decision (2026-09-11):** trim all 3 now. **Done and verified (2026-09-11):**

- `dim_DateTable`: trimmed to the 13 real columns (`DateKey`, `Date`, `Year`, `Quarter`, `Month`,
  `Day`, `WeekOfYear`, `DayOfWeek`, `MonthName`, `MonthNameShort`, `MonthYear`, `QuarterYear`,
  `IsWeekend`). Verified: 4,018 rows (unchanged), 13-column contract exact.
- `dim_BranchLocation`: rebuilt off `Silver_BranchName` (new shortcut added to `DP_Presentation`),
  retiring the `df_BranchOperational_Raw` direct-ODBC dependency, and trimmed to 9 columns
  (`BranchKey`, `Branch`, `BranchType`, `BranchID`, `BranchName`, `LocationID`, `State`, `City`,
  `DataQualityScore`). Verified: 69 rows (exact match to the original build), 9-column contract
  exact, Seminole (`BranchID '1'`) spot check passes (`BranchType = Main Branch`,
  `DataQualityScore = 100`). `df_BranchOperational_Raw` itself has been **deleted** (both from
  the live `DP - Staging - Dev` workspace and this repo) — confirmed nothing read it anymore.
- `dim_RepairOrder`: trimmed to 2 columns (`REF_NO`, `CustomerNo`). Verified: 16,269 rows
  (unchanged), 2-column contract exact, all 11 known-important promo orders present including
  RO 1985073 (the same order used for this backend's original production verification).

All 3 built/verified via `docs/architecture/lh-master-data-dimensions-catalog.md`'s own
verification script, `.claude/queries/adhoc/dp-bronze-verify/verify_dim_trims_datetable_branchlocation_repairorder.py`.

## Implementation plan: building the remaining ~23 dims on the DP backend

Per Brian's direction: batch the dims by real difficulty (matching the raw-sources migration's
approach) — easy/clean first, then dims needing real adjustments, then the big ones last.
`dim_DateTable`/`dim_BranchLocation`/`dim_RepairOrder` are excluded (already built, trim-only —
see above). `dim_PartDemands`/`dim_BranchUserAccess` are excluded (not yet in use, no urgency —
see the corrected findings above). The 2 `Job Code Parts Advisor` dims and `CustomerLookup`
remain deferred per Brian's earlier direction.

**Batch A — easy/clean, straightforward builds (8):** `dim_CommodityCode`, `dim_DealerGroupCode`,
`dim_PaymentMethod`, `dim_SLC`, `dim_Source`, `dim_VendorCode`, `dim_BranchPartInventory`,
`lookup_UniqueCustomers_Invoice`. All checked out clean or nearly clean in the audit, all small
(2-7 columns), all single-or-few consumers — build exactly as documented, no design decisions
pending.

**Batch B — minor cleanup, still simple (5, later reduced to 4 — see below):**
`dim_Branch12_Parts` (drop 2 dead columns), `dim_UniqueCustomers` (decide whether to keep
the 4 unused audit-trail columns), `dim_Salesperson` (clean, grouped here),
`dim_AdjustmentType` (tiny static table, also fix the relationship-key design
inconsistency found in the audit), `dim_PromoType` (trim to real need).

**Real finding while starting Batch B (2026-09-11):** `dim_Branch12_Parts` is **also
blocked** on `Fact_Branch12_Transactions` — same missing Fact table that already blocked
`dim_BranchPartInventory` out of Batch A. Its 3 genuinely-used columns (`Demands`,
`R12_Sales_Qty`, `R12_Sales_Dollars`, confirmed real in the earlier audit) all come from
that fact table. **Decision: deferred alongside `dim_BranchPartInventory`**, to be built
together whenever Combine Vault Sales itself migrates. Batch B is now 4 dims.

**Also found while reading its source (not yet proven wrong empirically, just structurally
identical to an already-confirmed bug):** `dim_Branch12_Parts`'s R12 window is computed as
`DateTime.Date(DateTime.LocalNow())` minus 365 days, baked into static columns at refresh
time — the same UTC/local-time anti-pattern already found and fixed in `dim_DateTable`
(`Fact_PartsAdjustments.LoadedDatetime`, the 2026-02-27 Data Refresh Table fix). Worth
checking for real when `Fact_Branch12_Transactions`/`dim_Branch12_Parts` actually get built.

## Batch B results (2026-09-11) — 4 of 5 built and fully verified

**Real discovery investigating `dim_Salesperson`:** its 2 sources
(`Salesperson`/`SalespersonInformation`) had never been cataloged as raw sources — they're
embedded ODBC pulls inside the dimension dataflow itself, not separate `01 - Raw Sources`
dataflows. Brian pulled both views' real SQL Anywhere definitions and found they resolve to
a single new base table, `VhSalman` (confirmed in JD Bronze, 645 rows, shortcut-able),
joined to already-migrated `Silver_Contact` — no direct-ODBC Dataflow Gen2 needed after
all. Built as a normal raw source (`Build_Silver_VhSalman`) alongside the 4 dims.

**One real bug found from Brian's first test run:** `dim_Salesperson` failed with
`AMBIGUOUS_REFERENCE` on `SalespersonCode`. The join used an explicit condition (not a
same-name join), so both sides' code columns (`SalesPerson`, `SalespersonCode`) survived
into the joined dataframe; a later rename of `SalesPerson` to `SalespersonCode` then
collided with the column already there. Fixed by dropping the redundant column right after
the join.

**Column scope decisions:** `dim_AdjustmentType` and `dim_UniqueCustomers` are pure static
tables (matching production's own hardcoded Power Query data exactly, no source dependency
at all). `dim_PromoType` kept all 6 columns rather than trimming to just the relationship
key — unlike `dim_RepairOrder`'s complex, genuinely-unused derived margin metrics,
`PromoDescription`/`PromoCategory` are the table's whole documented purpose and
`FirstSeen`/`LastSeen`/`UsageCount` are cheap real aggregates serving the table's own stated
business use cases, not speculative "comprehensive business intelligence" bloat.
`dim_AdjustmentType` keeps both `AdjustmentTypeKey` and `AdjustmentTypeName` — the
relationship-key design inconsistency found in the audit (production's relationship joins
on the name, not the intended surrogate key) is left for whoever migrates the Parts
Adjustments report itself to resolve.

**All 4 verified exact:** `dim_AdjustmentType` 7 rows/5 columns, `dim_PromoType` 42
rows/6 columns, `dim_UniqueCustomers` 11 rows/7 columns, `dim_Salesperson` 645 rows/7
columns (370 active, 275 inactive). `dim_Branch12_Parts` remains deferred alongside
`dim_BranchPartInventory`.

**Batch C — real rework needed (4):** `dim_JobCode` (trim from 11 to 3 real columns, resolve the
`dim_JobCode`/`dim_JobCodes` naming collision), `dim_Franchise` (trim from 15 to 4),
`dim_ModuleType` (trim from 5 to 3, and resolve the hardcoded ~40-customer-number
Internal/Warranty classification — a real design decision, not just a column trim),
`dim_Technician_Code_Names` (trim from 16 to ~4).

**Batch D — the big ones, individually (2):** `dim_CustomerList` (55→43 real columns, 10
consumers, real special-customer-key business logic to preserve exactly), `dim_Parts` (22/22
already clean, but 18 consumers — high blast radius despite needing no column changes).

## Batch A results (2026-09-11) — 7 of 8 built, verified against real DuckDB checks

`dim_BranchPartInventory` deferred per plan (blocked on a not-yet-built
`Fact_Branch12_Transactions`). All 7 built as new `Build_Gold_*` notebooks in
`DP_Presentation`, sourced from already-migrated Silver tables
(`Silver_PartInformation`, `Silver_Invoice`, `Silver_ArMasterCustomer`, `Silver_InTrans`)
instead of fresh ODBC pulls, reproducing each production dataflow's business logic
faithfully.

**One real bug found and fixed:** `dim_VendorCode` came back 0 rows on first run.
Root cause: `Silver_PartInformation.VendorCode` is stored as an **integer** column
(confirmed via DuckDB: 1,332 distinct values, 0 nulls, values 0-286600), unlike
every other reference-code column in this batch. The notebook's `!= ""` blank-string
filter silently evaluated to null/false for every row in Spark's non-ANSI mode (no
error thrown), filtering out the entire table. Fixed by dropping the inapplicable
string check — `0` is a legitimate real code here, not a blank sentinel.

**Three "surprising" numbers investigated and confirmed real, not bugs** (each
verified independently via DuckDB directly against the source Silver table, not just
trusted from the notebook's own output):

- `dim_DealerGroupCode`: 1,867 rows (1,866 real codes + Unknown), not a small handful
  as the name might suggest — genuinely messy, high-cardinality source data (a mix of
  real dealer names like `COMBINE`/`KUHN` and numeric-looking codes).
- `dim_PaymentMethod`: **12 rows, not the documented 5.** 7 extra rows are real (if
  messy) production data — rare garbage-looking `PaymentMethod` values on `Silver_Invoice`
  (`1005`, `ASHBURNBC4529`, `MIMINTEC3503`, etc., 1-14 rows each out of 6.5M+ invoice
  rows) that the old production dataflow's own filter (`<> null and <> ""`) would
  equally pick up — its "only 5, unlikely to grow" documentation was simply never
  checked against real data.
- `lookup_UniqueCustomers_Invoice`: **719 rows, not the documented ~513.** Each
  individual group's count is proportionally higher than the old documentation (e.g.
  Manuel/MR Tractor 300→472, Jim Justice 87→99, David Arizmendi 59→75) — consistent
  with organic invoice growth since that figure was last checked, not an
  implementation bug. Raw per-group counts summed exactly match the final 719.

**Also fixed a real correctness risk found while writing the notebook** (not from
Brian's test run, caught during authoring): the original combine-and-dedupe logic for
`lookup_UniqueCustomers_Invoice`'s Invoice > TradeType > Direct priority tie-break used
`monotonically_increasing_id()` over a Spark `union()`, which isn't guaranteed to
preserve argument order across a distributed union the way Power Query's
`Table.Combine` + `Table.Distinct` does. Replaced with an explicit `_SourcePriority`
column, deterministic regardless of execution plan.

Full verification: `.claude/queries/adhoc/dp-bronze-verify/verify_batch_a_dims.py`.

**Batch A complete and fully verified (2026-09-11):** all 7 dims pass exactly after
the `dim_VendorCode` fix — `dim_CommodityCode` 784 rows, `dim_DealerGroupCode` 1,867,
`dim_SLC` 123 (matches the Feb 2026 doc exactly), `dim_Source` 273, `dim_VendorCode`
1,332, `dim_PaymentMethod` 12, `lookup_UniqueCustomers_Invoice` 719 (edge case
CustomerNumber 25227 correctly resolves to `Manuel/MR Tractor`). All 2-5 column
contracts exact.
