# Fact Table Analysis - Pipeline_Facts

Cross-reference of all fact dataflows against deployed semantic models.
Used to determine which facts need daily refresh, which are unused/experimental, and how to batch the pipeline.

**Analysis Date:** February 18, 2026
**Source:** Scanned all 38 fact dataflows in `04 - Facts/` and cross-referenced against 30 semantic models across 4 workspaces.

---

## Summary

| Category | Count | Notes |
|----------|-------|-------|
| **Total Fact Dataflows** | 38 | In `04 - Facts/` folder |
| **Active (used by deployed models)** | 24 | Need pipeline scheduling |
| **Test/Experimental** | 12 | `Test Queries - Inspection Report` subfolder |
| **Stub/Not Deployed** | 1 | df_Fact_Machines_Serviced (empty) |
| **Already in Dims Pipeline** | 1 | df_CustomerLookup (in Pipeline_Dimensions) |
| **Reports with NO fact dataflow** | 6 | Use inline PQ or raw tables directly |

---

## Active Fact Dataflows - Pipeline Candidates (24 DFs)

### Customer Anatomy V2 (7 fact DFs)

| Dataflow | logicalId | Table | Est. Time | Rows |
|----------|-----------|-------|-----------|------|
| df_Fact_Service_Invoices | c0f9c628-376b-b647-4fc6-89abaf0cbcab | Fact_Service_Invoices | ~10 min | ~1.4M |
| df_Fact_Parts_Details | 4646e6fb-d290-8f89-43ed-991b04ad0b4f | Fact_Parts_Details | ~8.5 min | ~1M |
| df_Fact_Service_Detail | 5276f2ae-1954-aaf5-4843-d8ed4896ffbe | Fact_Service_Detail | ~6.5 min | ~500K |
| df_Fact_Parts_Invoices | 2cbbe331-a880-97f7-46bd-2b509149d9f6 | Fact_Parts_Invoices | ~5.5 min | ~1.4M |
| df_Fact_Service_Parts_Detail | 040b5eca-06e8-8e81-46b3-f76693460bc7 | Fact_Service_Parts_Details | ~4 min | ~500K |
| df_Fact_CustomerPerformance | dfe2053d-4e54-ba15-477e-a022cd83c668 | Fact_CustomerPerformance | ~3.5 min | ~50K |
| df_Fact_Equipment_Sales | db0e3a1c-73ec-ad06-4058-76fac17d82d1 | Fact_Equipment_Sales | ~2 min | ~10K |

**Subtotal: ~40 min sequential, ~10 min parallel (bottleneck: Service_Invoices)**

Also in this subfolder but NOT fact DFs:
- df_CustomerLookup - already in Pipeline_Dimensions daily
- df_Engaged_Acres - CSV upload to Lakehouse, not a refresh target

### Inspections V2 (3 fact DFs)

| Dataflow | logicalId | Table | Est. Time | Rows |
|----------|-----------|-------|-----------|------|
| df_Fact_WorkOrderParts | a292285c-dc64-83a6-4dc9-4ac497eacf29 | Fact_WorkOrderParts | ~18.5 min | ~2M |
| df_Fact_LaborJobSummary | 288c2351-c40b-b213-4f88-a98c5b56bdeb | Fact_LaborJobSummary | ~5 min | ~350K |
| df_Fact_PendingInspections | e76bd638-fe15-90f9-470e-e71935ada71b | Fact_PendingInspections | ~2.5 min | ~5K |

**Subtotal: ~26 min sequential, ~18.5 min parallel (bottleneck: WorkOrderParts)**

### Inventory Analysis V3 (3 fact DFs)

| Dataflow | logicalId | Table | Est. Time | Rows |
|----------|-----------|-------|-----------|------|
| df_Fact_Inventory | 6070c9ee-1a36-8856-40d2-f7c9c1fe617e | Fact_Inventory | ~6 min | ~300K |
| df_Fact_Invoice_InventoryAnalysis | 40a35d40-e778-a28b-473d-bd3af3818dfc | Fact_Invoice_InventoryAnalysis | ~2.5 min | ~469K |
| df_FactPartTransactions_Incremental | e74aeb1b-d507-b5ae-46c6-cdda72ee85ef | Fact_Part_Transactions | ~2.5 min | 10M+ |

**Note:** df_FactPartTransactions_Incremental is the incremental version of df_Fact_Part_Transactions. Use the incremental DF in the pipeline.
**Subtotal: ~11 min sequential, ~6 min parallel (bottleneck: Inventory)**

### Unique Parts Customers (2 fact DFs)

| Dataflow | logicalId | Table | Est. Time | Rows |
|----------|-----------|-------|-----------|------|
| df_Fact_InTrans_UniqueCustomers | 6f6674d0-2551-942d-446f-c5cba101a36a | Fact_InTrans_UniqueCustomers | ~2.5 min | ~54K |
| df_Fact_Invoice_UniqueCustomers | 4ad5cd94-8d59-bbcd-4230-ce77882712b7 | Fact_Invoice_UniqueCustomers | ~2.5 min | ~6K |

### Single-Fact Reports (9 DFs)

| Dataflow | logicalId | Table | Report | Est. Time | Rows |
|----------|-----------|-------|--------|-----------|------|
| df_Fact_First_Pass_Fill | 6a738c5f-9ffe-ad61-49e2-f021fa540802 | Fact_FirstPassFill | First Pass Fill | ~5 min | ~734K |
| df_Fact_PartSales_24Hours | 0a2af750-026b-a4e7-4748-a3191c5666ee | Fact_PartsNotReordered | Parts Not Re-Ordered | ~3.5 min | ~8K |
| df_Fact_Branch12_Transactions | 8bac8d09-8952-a458-45b7-628e00f5fd1b | Fact_Branch12_Transactions | Combine Vault Sales | ~3 min | ~5K |
| df_Fact_Parts_With_Open_Orders | 87e02f99-3200-a606-422b-c7718acc22e2 | Fact_Parts_Open_Tickets | Open Parts Tickets | ~2.5 min | ~1K |
| df_Fact_PartsAdjustments | 1cc6c648-f824-896e-4a3f-bef52144ca39 | Fact_PartsAdjustments | Parts Adjustments | ~2.5 min | ~239K |
| df_Fact_PartsPromo | bd8714d5-be36-af44-4a9b-8f578310b7c3 | Fact_PartsPromo | Parts Promo | ~1.75 min | ~5K |
| df_Fact_InSalOrd_InSalPar | 8bbbd53b-a2d7-a137-414a-b874b77e8d7e | Fact_InSalOrd_InSalPar | 60+ Days Past Due | ~1.5 min | ~1.4K |
| df_Fact_NegativeOnHand_OnHandNoBin | bca48ac6-a6df-8abc-4a19-ddcc67f5355a | Fact_NegativeOnHand | Negative On Hand | ~1.5 min | ~1.4K |
| df_Fact_Top50_JobCodes | e32c753d-416b-b644-44a6-cf6616324bfe | Fact_Top50_JobCodes | Top 50 Job Codes | ~2.75 min | TBD |

---

## Reports with NO Fact Dataflow (Inline Power Query or Raw Tables)

These reports build their fact tables at the semantic model level - no Fabric dataflow to schedule.
They refresh when their semantic model refreshes (Phase 5 of the pipeline).

| Report | Workspace | How Facts Are Built | Raw Tables Used |
|--------|-----------|--------------------|-----------------|
| Part Sales Low Margin | RP - Parts Reports | Power Query in SM (Fact_Intrans, dim_Parts_LowMargin) | InTrans_Incremental, InMaster, jdis_Part_Information |
| Pin Capture | RP - Parts Reports | Power Query in SM (Fact_PinTransactions) | InTrans_Incremental, wkothsub |
| Physical Inventory | RP - Parts Reports | Power Query in SM (Physical Inventory) | jdis_Part_Information |
| Bin Location | RP - Parts Reports | Direct raw table reference | jdis_Part_Information |
| Labor Performance V2 | RP - Service Reports | Direct raw table references | TechnicianAttendance, TechnicianEfficiency, TechnicianPunchedTime |
| Open Work Orders | RP - Service Reports | Power Query in SM from raw tables | wkothsub, WKROFILE, wkrodesc |

**Impact:** These reports only need the raw tables refreshed (Phase 1) + semantic model refresh (Phase 5). No Phase 4 pipeline activity needed.

---

## Unused / Archive Candidates

### Test Queries - Inspection Report (12 DFs)

Experimental dataflows from Inspections report development. NOT referenced by any deployed semantic model.

| Dataflow | logicalId | Notes |
|----------|-----------|-------|
| df_Fact_InvoiceHeader | 1bd7bead-cbdc-aa7a-4dbc-8572edd703b0 | Test/experimental |
| df_Fact_LaborInvoiced | b2abc768-f09f-8854-4f3f-d3aa8c8c56a5 | Test/experimental |
| df_Fact_LaborJobs | 66eb4a1e-2ac2-a5b1-49b6-a2e315112239 | Test/experimental |
| df_Fact_LaborPunches | 8a114fc9-995f-84d2-4e79-c7ed89307c3a | Test/experimental |
| df_Fact_LaborWIP | 9ff3fc3d-f39e-8161-4683-ee9650fa4848 | Test/experimental |
| df_Fact_PartTransactions | 0541f396-7e8d-ac26-4a1b-862261ed78f7 | Test/experimental |
| df_Fact_WarrantyClaims | a4192303-d784-8a3f-4b1e-edc7b7b22140 | Test/experimental |
| df_Fact_WorkOrderComprehensive | 6903bf18-5709-9c23-44c1-c878378288bb | Test/experimental |
| df_Fact_WorkOrderHeader | d641e928-ec08-a2ad-45af-93e5e6775018 | Test/experimental |
| df_Fact_WorkOrderJobs | bf44e582-5a3c-895b-4911-c24c3186cdc0 | Test/experimental |
| df_Fact_WorkOrderLabor | 9f6ab90c-4fb3-9c67-4cc1-365a160c213f | Test/experimental |
| df_Fact_Machines_Serviced | 925827e3-9296-914a-4d5f-2e4528af004d | Stub (no actual query) |

**Recommendation:** Move all 12 to an "Archive Facts" folder, same pattern as archived dimensions.

### Already Handled Elsewhere

| Dataflow | Where | Notes |
|----------|-------|-------|
| df_CustomerLookup | Pipeline_Dimensions (daily) | Fact-building helper, refreshes with dims |
| df_Engaged_Acres | Manual CSV upload | Not a scheduled dataflow |
| df_Fact_Part_Transactions | Superseded by df_FactPartTransactions_Incremental | Full refresh version, use incremental instead |

---

## Proposed Pipeline_Facts - Daily (24 DFs, 5 Waves)

Sorted by estimated refresh time (longest first). 5 concurrent per wave to stay within F4 CU limits.

### Wave A - Heaviest Facts (5 concurrent, ~18.5 min bottleneck)

| Dataflow | logicalId | Report | Est. Time |
|----------|-----------|--------|-----------|
| df_Fact_WorkOrderParts | a292285c-dc64-83a6-4dc9-4ac497eacf29 | Inspections | ~18.5 min |
| df_Fact_Service_Invoices | c0f9c628-376b-b647-4fc6-89abaf0cbcab | Customer Anatomy | ~10 min |
| df_Fact_Parts_Details | 4646e6fb-d290-8f89-43ed-991b04ad0b4f | Customer Anatomy | ~8.5 min |
| df_Fact_Service_Detail | 5276f2ae-1954-aaf5-4843-d8ed4896ffbe | Customer Anatomy | ~6.5 min |
| df_Fact_Inventory | 6070c9ee-1a36-8856-40d2-f7c9c1fe617e | Inventory Analysis | ~6 min |

### Wave B - Medium Facts (5 concurrent, ~5.5 min bottleneck)

| Dataflow | logicalId | Report | Est. Time |
|----------|-----------|--------|-----------|
| df_Fact_Parts_Invoices | 2cbbe331-a880-97f7-46bd-2b509149d9f6 | Customer Anatomy | ~5.5 min |
| df_Fact_First_Pass_Fill | 6a738c5f-9ffe-ad61-49e2-f021fa540802 | First Pass Fill | ~5 min |
| df_Fact_LaborJobSummary | 288c2351-c40b-b213-4f88-a98c5b56bdeb | Inspections | ~5 min |
| df_Fact_Service_Parts_Detail | 040b5eca-06e8-8e81-46b3-f76693460bc7 | Customer Anatomy | ~4 min |
| df_Fact_CustomerPerformance | dfe2053d-4e54-ba15-477e-a022cd83c668 | Customer Anatomy | ~3.5 min |

### Wave C - Standard Facts (5 concurrent, ~3.5 min bottleneck)

| Dataflow | logicalId | Report | Est. Time |
|----------|-----------|--------|-----------|
| df_Fact_PartSales_24Hours | 0a2af750-026b-a4e7-4748-a3191c5666ee | Parts Not Re-Ordered | ~3.5 min |
| df_Fact_Branch12_Transactions | 8bac8d09-8952-a458-45b7-628e00f5fd1b | Combine Vault Sales | ~3 min |
| df_Fact_Parts_With_Open_Orders | 87e02f99-3200-a606-422b-c7718acc22e2 | Open Parts Tickets | ~2.5 min |
| df_Fact_Invoice_InventoryAnalysis | 40a35d40-e778-a28b-473d-bd3af3818dfc | Inventory Analysis | ~2.5 min |
| df_Fact_PartsAdjustments | 1cc6c648-f824-896e-4a3f-bef52144ca39 | Parts Adjustments | ~2.5 min |

### Wave D - Light Facts (5 concurrent, ~2.5 min bottleneck)

| Dataflow | logicalId | Report | Est. Time |
|----------|-----------|--------|-----------|
| df_Fact_PendingInspections | e76bd638-fe15-90f9-470e-e71935ada71b | Inspections | ~2.5 min |
| df_FactPartTransactions_Incremental | e74aeb1b-d507-b5ae-46c6-cdda72ee85ef | Inventory Analysis | ~2.5 min |
| df_Fact_InTrans_UniqueCustomers | 6f6674d0-2551-942d-446f-c5cba101a36a | Unique Customers | ~2.5 min |
| df_Fact_Invoice_UniqueCustomers | 4ad5cd94-8d59-bbcd-4230-ce77882712b7 | Unique Customers | ~2.5 min |
| df_Fact_Equipment_Sales | db0e3a1c-73ec-ad06-4058-76fac17d82d1 | Customer Anatomy | ~2 min |

### Wave E - Final Facts (4 concurrent, ~2 min bottleneck)

| Dataflow | logicalId | Report | Est. Time |
|----------|-----------|--------|-----------|
| df_Fact_PartsPromo | bd8714d5-be36-af44-4a9b-8f578310b7c3 | Parts Promo | ~1.75 min |
| df_Fact_InSalOrd_InSalPar | 8bbbd53b-a2d7-a137-414a-b874b77e8d7e | 60+ Days Past Due | ~1.5 min |
| df_Fact_NegativeOnHand_OnHandNoBin | bca48ac6-a6df-8abc-4a19-ddcc67f5355a | Negative On Hand | ~1.5 min |
| df_Fact_Top50_JobCodes | e32c753d-416b-b644-44a6-cf6616324bfe | Top 50 Job Codes | ~2.75 min |

### Wave Duration Estimates

| Wave | DFs | Bottleneck | Est. Duration |
|------|-----|-----------|---------------|
| Wave A | 5 | WorkOrderParts (18.5m) | ~18.5 min |
| Wave B | 5 | Parts_Invoices (5.5m) | ~5.5 min |
| Wave C | 5 | PartSales_24Hours (3.5m) | ~3.5 min |
| Wave D | 5 | Several at ~2.5m | ~2.5 min |
| Wave E | 4 | PartsPromo (1.75m) | ~2 min |
| **Total** | **24** | | **~32 min** |

**After WorkOrderParts optimization (target 3-5 min):** Total drops to ~18-20 min.

---

## Optimization Targets

### Priority 1: df_Fact_WorkOrderParts (18.5 min)

- **Impact:** Single biggest bottleneck. Saves ~15 min/day when optimized.
- **Approach:** Watermark-based incremental refresh (same pattern as InTrans_Incremental/FactPartTransactions_Incremental)
- **Target:** 3-5 min (matching Fact_Part_Transactions pattern for similar data volumes)
- **When:** After daily pipeline is stable (Week 5+)

### Priority 2: df_Fact_Service_Invoices (10 min)

- **Impact:** Second longest fact. Currently hidden behind WorkOrderParts in Wave A.
- **Approach:** Query optimization, potential incremental refresh
- **When:** After WorkOrderParts optimization (becomes the new bottleneck)

---

## Fact Usage by Report

| Report | Tier | Fact Dataflows | Inline PQ | Total Fact Sources |
|--------|------|---------------|-----------|-------------------|
| Customer Anatomy V2 | 1 | 7 | 0 | 7 |
| Inspections V2 | 1 | 3 | 0 | 3 |
| Inventory Analysis V3 | 1 | 3 | 0 | 3 |
| Unique Parts Customers | 2 | 2 | 0 | 2 |
| First Pass Fill | 1 | 1 | 0 | 1 |
| Parts Not Re-Ordered | 1 | 1 | 0 | 1 |
| Combine Vault Sales | 2 | 1 | 0 | 1 |
| Open Parts Tickets | 1 | 1 | 0 | 1 |
| Parts Adjustments | 1 | 1 | 0 | 1 |
| Parts Promo | 1 | 1 | 0 | 1 |
| 60+ Days Past Due | 1 | 1 | 0 | 1 |
| Negative On Hand | 1 | 1 | 0 | 1 |
| Top 50 Job Codes | 2 | 1 | 0 | 1 |
| Part Sales Low Margin | 1 | 0 | 2 | 2 |
| Pin Capture | 2 | 0 | 1 | 1 |
| Physical Inventory | 2 | 0 | 1 | 1 |
| Bin Location | 3 | 0 | 1 | 1 |
| Labor Performance V2 | 2 | 0 | 3 | 3 |
| Open Work Orders | 1 | 0 | 3 | 3 |
| Price Matrix | 3 | 0 (shared) | 0 | 0 (uses IA facts) |
| Sparc Inventory Health | - | 0 | 1 | 1 |

---

## Shared Facts

| Fact Table | Primary Report | Also Used By | Notes |
|------------|---------------|-------------|-------|
| Fact_Inventory | Inventory Analysis V3 | Price Matrix | Same Lakehouse table |
| Fact_Part_Transactions | Inventory Analysis V3 | Price Matrix | Same Lakehouse table |

**Implication:** Refreshing Inventory Analysis facts automatically makes Price Matrix data current too. No separate fact pipeline needed for Price Matrix.

---

**Last Updated:** February 18, 2026
