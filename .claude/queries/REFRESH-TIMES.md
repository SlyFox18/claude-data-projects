# Dataflow Refresh Times

Track average refresh times for capacity planning and CU optimization (F4 capacity).

---

## Batched Pipeline Baselines (4:15 AM Schedule, Feb 2026)

Pipeline_Raw_Data restructured into 5 sequential batches with concurrent DFs per batch.
Baselines measured from Run 4 (Feb 12, 2026, 3:05 PM CST) after InTrans_PartsCounter optimization.
**Total Pipeline_Raw_Data: 24m 35s**

> **Note:** These baselines were measured during business hours (~3 PM). True 3:30 AM baselines
> (zero source contention) are expected to be equal or faster. Update after first production run.

### Batch 1 - Heaviest DFs (6 concurrent, 9m 14s)

| Dataflow | Table | Refresh Time | Approx Rows |
|----------|-------|-------------|-------------|
| df_JDIS_PART_INFORMATION_Raw | jdis_Part_Information | 9m 13s | 1,081,494 |
| df_InTrans_PartsCounter_Raw | InTrans_PartsCounter | 7m 43s | ~500K |
| df_Invoice_Raw | Invoice | 7m 13s | 1,402,683 |
| df_InHist_PmManage_Raw | InHist_PmManage | 4m 42s | 721,295 |
| df_GlTrans_Raw | GlTrans | 3m 43s | 208,637 |
| df_WKROFILE_Raw | WKROFILE | 3m 12s | 111,650 |

**Bottleneck:** JDIS at 9m 13s

### Batch 2 - WK Tables (5 concurrent, 3m 38s)

| Dataflow | Table | Refresh Time | Approx Rows |
|----------|-------|-------------|-------------|
| df_WKRODESC_Raw | wkrodesc | 3m 36s | 904,014 |
| df_WKMECHWK_Raw | wkmechwk | 3m 36s | 307,819 |
| df_WKVEHFL_Raw | WKVEHFL | 3m 06s | 48,316 |
| df_WKINVREG_Raw | WkInvReg | 2m 36s | 40,582 |
| df_WKOTHSUB_Raw | wkothsub | 2m 35s | 350,305 |

**Bottleneck:** WKRODESC/WKMECHWK tied at 3m 36s

### Batch 3 - Tech Detail & Short DFs (6 concurrent, 4m 10s)

| Dataflow | Table | Refresh Time | Approx Rows |
|----------|-------|-------------|-------------|
| df_TechnicianInvoiceDetail_Raw | TechnicianInvoiceDetail | 4m 07s | 330,096 |
| df_TechnicianPunchedDetail_Raw | TechnicianPunchedDetail | 3m 36s | 319,043 |
| df_InSalPar_Raw | insalpar | 3m 36s | 13,373 |
| df_VHStock_Raw | vhstock | 2m 37s | 24,469 |
| df_RepairOrderDetail_Raw | RepairOrderDetail | 2m 36s | 2,003 |
| df_Insalord_Raw | insalord | 2m 06s | 8,631 |

**Bottleneck:** TechnicianInvoiceDetail at 4m 07s

### Batch 4 - Tech Summaries & Vehicle (6 concurrent, 4m 10s)

| Dataflow | Table | Refresh Time | Approx Rows |
|----------|-------|-------------|-------------|
| df_TechnicianPunchedTime_Raw | TechnicianPunchedTime | 4m 07s | ~100K |
| df_TechnicianAttendance_Raw | TechnicianAttendance | 3m 07s | ~50K |
| df_TechnicianEfficiency_Raw | TechnicianEfficiency | 3m 07s | ~50K |
| df_VhStockAccess_Raw | VhStockAccess | 2m 37s | 683,129 |
| df_VhTrans_Raw | VhTrans | 2m 37s | ~100K |
| df_TechnicianInvoice_Raw | TechnicianInvoice | 2m 36s | ~100K |

**Bottleneck:** TechnicianPunchedTime at 4m 07s

### Batch 5 - Remaining DFs (9 concurrent, 3m 11s)

| Dataflow | Table | Refresh Time | Approx Rows |
|----------|-------|-------------|-------------|
| df_CONTACT_Raw | contact | 3m 08s | 81,648 |
| df_ArMaster_Contact_Raw | ArMaster_Contact | 3m 07s | 53,470 |
| df_ARMASTER_Raw | armaster | 3m 07s | 53,470 |
| df_WarClaim_Raw | WarClaim | 3m 07s | 10,801 |
| df_ArMaster_Customer_Raw | ArMaster_Customer | 2m 38s | 53,470 |
| df_BranchOperational_Raw | BranchOperational | 2m 38s | 99 |
| df_WARSUBCI_LABOR_Raw | WARSUBCI_LABOR | 2m 37s | 65,741 |
| df_Branch_Name_Raw | Branch_Name | 2m 36s | 99 |
| df_Technician_Raw | Technician | 2m 35s | 1,424 |

**Bottleneck:** CONTACT at 3m 08s

### Batch Duration Summary

| Batch | DFs | Duration | Bottleneck |
|-------|-----|----------|------------|
| Batch 1 | 6 | 9m 14s | JDIS (9m 13s) |
| Batch 2 | 5 | 3m 38s | WKRODESC (3m 36s) |
| Batch 3 | 6 | 4m 10s | TechInvoiceDetail (4m 07s) |
| Batch 4 | 6 | 4m 10s | TechPunchedTime (4m 07s) |
| Batch 5 | 9 | 3m 11s | CONTACT (3m 08s) |
| **Total** | **32** | **24m 35s** | |

### Optimization History

| Change | Before | After | Saved |
|--------|--------|-------|-------|
| Move InTrans_PartsCounter to Batch 1 | 27m 41s (Run 3) | 24m 35s (Run 4) | ~3 min |
| Split dims: 9 daily + 13 monthly, 2 batches | 9m 46s (15 concurrent) | 8m 26s (9 batched) | ~1m 20s + healthier DF times |

---

## Historical: 7:30 AM Pipeline (Deprecated)

> The 7:30 AM pipeline was disabled due to 200-600% performance degradation caused by
> source system contention + 20+ concurrent dataflows overwhelming F4 capacity.
> These times are preserved for reference only.

### Raw Tables at 7:30 AM (Degraded Performance)

| Table | Dataflow | Rows | 7:30 AM Time | Baseline | Degradation |
|-------|----------|------|-------------|----------|-------------|
| jdis_Part_Information | df_jdis_Part_Information_Raw | 1,081,494 | ~8 min | ~8 min | ~1x (large table masks it) |
| ArMaster_Contact | df_ArMaster_Contact_Raw | 53,470 | ~6-8 min | ~1-2 min | 300-400% |
| ArMaster_Customer | df_ArMaster_Customer_Raw | 53,470 | ~6-8 min | ~1-2 min | 300-400% |
| armaster | df_armaster_Raw | 53,470 | ~6-7 min | ~1-2 min | 300-350% |
| contact | df_CONTACT_Raw | 81,648 | ~6-8 min | ~1:30-2 min | 300-400% |
| GlTrans | df_GlTrans_Raw | 208,637 | ~6-8 min | ~2-3 min | 200-300% |
| InHist_PmManage | df_InHist_PmManage_Raw | 721,295 | ~8-9 min | ~3 min | 200-300% |
| insalord | df_INSALORD_Raw | 8,631 | ~6-7 min | ~1 min | 600% |
| insalpar | df_INSALPAR_Raw | 13,373 | ~6-7 min | ~1-1:30 min | 400-600% |
| Invoice | df_Invoice_Raw | 1,402,683 | ~10-12 min | ~4-5 min | 200-250% |
| RepairOrderDetail | df_RepairOrderDetail_Raw | 2,003 | ~6-7 min | ~1-1:30 min | 400-600% |
| Technician | df_Technician_Raw | 1,424 | ~6-7 min | ~1-1:30 min | 400-600% |
| TechnicianInvoiceDetail | df_TechnicianInvoiceDetail_Raw | 330,096 | ~6-7 min | ~1:30-2 min | 300-400% |
| TechnicianPunchedDetail | df_TechnicianPunchedDetail_Raw | 319,043 | ~7-8 min | ~1:30-3 min | 200-400% |
| vhstock | df_VHSTOCK_Raw | 24,469 | ~6-7 min | ~1-1:30 min | 400-600% |
| WkInvReg | df_WKINVREG_Raw | 40,582 | ~8-9 min | ~1-2 min | 400-700% |
| wkmechwk | df_WKMECHWK_Raw | 307,819 | ~6-8 min | ~1-2 min | 300-400% |
| wkothsub | df_WKOTHSUB_Raw | 350,305 | ~6-7 min | ~2 min | 300-350% |
| wkrodesc | df_WKRODESC_Raw | 904,014 | ~6-8 min | ~1:30-3 min | 200-400% |
| WKROFILE | df_WKROFILE_Raw | 111,650 | ~7-8 min | ~1-2 min | 400-700% |
| WKVEHFL | df_WKVEHFL_Raw | 48,316 | ~7-8 min | ~1-2 min | 400-700% |

**Root cause:** Source system (ODBC/EquipRDB64) under business load at 7:30 AM + 20+ concurrent DFs spiking CU to 214%.

### Standalone Baselines (No Contention)

| Table | Dataflow | Rows | Solo Time | Notes |
|-------|----------|------|-----------|-------|
| InTrans_Incremental | df_InTrans_Incremental | 10,245,764 | ~2-3 min | Gold standard incremental pattern |
| InMaster | df_InMaster_Raw | 1,081,485 | ~4-5 min | 1M+ rows at baseline proves timing was the issue |
| VhStockAccess | df_VhStockAccess_Raw | 683,129 | ~2 min | Large table at baseline |
| WarClaim | df_WarClaim_Raw | 10,801 | ~1:10 | Same size as insalord but 5-6x faster than 7:30 AM |
| WarsubCl_Labour | df_WARSUBCI_LABOUR_Raw | 65,741 | ~1:30 | Same as ArMaster size but 4-5x faster than 7:30 AM |

---

## Pipeline_Dimensions - Daily (9 DFs, 2 Batches)

Baselines measured Feb 19, 2026, 12:16 PM CST.
**Total Pipeline_Dimensions: ~8m 26s**

> **Note:** Measured during business hours (~12 PM). Expect faster at 3:30 AM.

### Batch 1 (5 concurrent, 5m 44s)

| Dataflow | Table | Refresh Time | Notes |
|----------|-------|-------------|-------|
| df_Dim_Part | dim_Parts | 5m 43s | Bottleneck, ~5-6 min solo baseline |
| df_UniqueCustomer_Lookup | lookup_UniqueCustomers_Invoice | 4m 43s | New addition, Customer Anatomy |
| df_Dim_Customer | dim_CustomerList | 3m 42s | |
| df_CustomerLookup | CustomerLookup | 2m 42s | Fact-building helper |
| df_Dim_Date | dim_DateTable | 2m 42s | Should be <15s solo; CU contention |

### Batch 2 (4 concurrent, 2m 38s)

| Dataflow | Table | Refresh Time | Notes |
|----------|-------|-------------|-------|
| df_Dim_Branch12_Parts | dim_Branch12_Parts | 2m 37s | |
| df_Dim_JobCode | dim_JobCode | 2m 36s | New addition |
| df_Dim_UniqueCustomers | dim_UniqueCustomers | 2m 6s | |
| df_Dim_Technicans | dim_Technician_Code_Names | 2m 6s | |

### Daily Batch Summary

| Batch | DFs | Duration | Bottleneck |
|-------|-----|----------|------------|
| Batch 1 | 5 | 5m 44s | dim_Parts (5m 43s) |
| Batch 2 | 4 | 2m 38s | Branch12Parts (2m 37s) |
| **Total** | **9** | **~8m 26s** | |

### Optimization History

| Change | Before | After | Saved |
|--------|--------|-------|-------|
| Batch 9 DFs (2 batches) vs 15 all-parallel | 9m 46s (15 concurrent) | 8m 26s (batched) | ~1m 20s total, individual DFs 42-60% faster |

---

## Pipeline_Dimensions_Monthly (13 DFs, 3 Batches)

Baselines measured Feb 19, 2026, 12:48 PM CST. Run manually or on monthly schedule.
**Total Pipeline_Dimensions_Monthly: ~13m 17s**

### Batch 1 (5 concurrent, 3m 14s)

| Dataflow | Table | Refresh Time | Notes |
|----------|-------|-------------|-------|
| df_Dim_DealerGroupCode | dim_DealerGroupCode | 3m 12s | Bottleneck |
| df_Dim_SLC | dim_SLC | 2m 43s | |
| df_Dim_Location | dim_BranchLocation | 2m 42s | Used by 22 reports |
| df_Dim_Source | dim_Source | 2m 42s | |
| df_Dim_Franchise | dim_Franchise | 2m 42s | |

### Batch 2 (5 concurrent, ~5m 16s)

| Dataflow | Table | Refresh Time | Notes |
|----------|-------|-------------|-------|
| df_Dim_AdjustmentType | dim_AdjustmentType | 2m 6s | |
| df_Dim_CommodityCode | dim_CommodityCode | 2m 35s | |
| df_Dim_VendorCode | dim_VendorCode | 2m 35s + retry | Failed once, succeeded on retry |
| df_Dim_ModuleType | dim_ModuleType | 2m 5s | |
| df_Dim_PaymentMethod | dim_PaymentMethod | 1m 36s | Fastest dimension |

### Batch 3 (3 concurrent, 4m 42s)

| Dataflow | Table | Refresh Time | Notes |
|----------|-------|-------------|-------|
| df_Dim_PromoType | dim_PromoType | 4m 37s | Surprisingly slow for small table |
| df_Dim_RepairOrder | dim_RepairOrder | 3m 7s | |
| df_Dim_JobType | Dim_JobType | 2m 5s | |

### Monthly Batch Summary

| Batch | DFs | Duration | Bottleneck |
|-------|-----|----------|------------|
| Batch 1 | 5 | 3m 14s | DealerGroupCode (3m 12s) |
| Batch 2 | 5 | ~5m 16s | VendorCode retry |
| Batch 3 | 3 | 4m 42s | PromoType (4m 37s) |
| **Total** | **13** | **~13m 17s** | |

**Phase 3 bottleneck:** dim_Parts at 5m 43s (daily pipeline)

---

## Pipeline_Facts - Daily (24 DFs, 5 Waves)

Run 1: Feb 19, 2026, ~4:08 PM CST. All succeeded. **Total: ~39m 10s**
Run 2: Feb 23, 2026, ~9:50 AM CST. 3 transient failures (all retried successfully). **Total: ~65m** (inflated by retries at business hours).
Run 3: Feb 23, 2026, ~11:07 AM CST. All 24 succeeded, no retries. **Total: ~41m 12s** ✅ Clean business-hours run.

> **Note:** All runs were during business hours with ODBC contention. Expect significantly faster times at 3:30 AM.

### Wave A (6 concurrent)

| Dataflow | Run 1 | Run 2 | Run 3 | Notes |
|----------|-------|-------|-------|-------|
| Refresh_Fact_WorkOrderParts | 16m 46s | 21m 46s (retry) | 22m 21s | Run 2 hit gateway timeout on attempt 1 |
| Refresh_Fact_Service_Invoices | 8m 43s | 11m 16s | 10m 16s | |
| Refresh_Fact_Parts_Details | 8m 43s | 10m 17s | 9m 15s | |
| Refresh_Fact_Inventory | 8m 13s | 9m 16s | 9m 17s | |
| Refresh_Fact_Service_Detail | 6m 44s | 8m 15s | 14m 19s | Run 3 slower - unexplained |
| Refresh_FactPartTransactions_Incremental | 9m 7s | 13m 41s (retry) | 13m 48s | Timeout raised to 25m after Run 2 |

**Wave A duration: Run 1 ~16m 48s / Run 2 ~40m (WorkOrderParts retry) / Run 3 ~22m 23s**

### Wave B (6 concurrent)

| Dataflow | Run 1 | Run 2 | Run 3 | Notes |
|----------|-------|-------|-------|-------|
| Refresh_Fact_Invoice_UniqueCustomers | 7m 37s | 8m 10s | 8m 11s | Moved from Wave D after Run 1 |
| Refresh_Fact_Parts_Invoices | 5m 37s | 7m 12s | 7m 39s | |
| Refresh_Fact_FirstPassFill | 5m 7s | 6m 10s | 6m 9s | |
| Refresh_Fact_LaborJobSummary | 5m 9s | 5m 44s | 6m 9s | |
| Refresh_Fact_CustomerPerformance | 4m 6s | 5m 8s | 4m 39s | |
| Refresh_Fact_Service_Parts_Detail | 3m 36s | 5m 11s | 4m 8s | |

**Wave B duration: Run 1 ~5m 39s / Run 2 ~8m 19s / Run 3 ~8m 13s**

### Wave C (5 concurrent)

| Dataflow | Run 1 | Run 2 | Run 3 | Notes |
|----------|-------|-------|-------|-------|
| Refresh_Fact_PartSales_24Hours | 4m 6s | 4m 41s (retry) | 4m 8s | Transient fail in Run 2, clean in Run 3 |
| Refresh_Fact_Invoice_InventoryAnalysis | 3m 7s | 3m 42s | 3m 37s | |
| Refresh_Fact_PartsAdjustments | 3m 7s | 3m 12s | 3m 7s | |
| Refresh_Fact_Parts_Open_Orders | 2m 36s | 3m 11s | 2m 37s | |
| Refresh_Fact_Branch12_Transactions | 2m 6s | 2m 41s | 2m 37s | |

**Wave C duration: Run 1 ~4m 8s / Run 2 ~7m 37s (PartSales retry) / Run 3 ~4m 11s**

### Wave D (3 concurrent)

| Dataflow | Run 1 | Run 2 | Run 3 | Notes |
|----------|-------|-------|-------|-------|
| Refresh_Fact_PendingInspections | 2m 7s | 3m 41s | 2m 40s | |
| Refresh_Fact_InTrans_UniqueCustomers | 2m 37s | 3m 12s | 2m 37s | |
| Refresh_Fact_Equipment_Sales | 2m 37s | 2m 42s | 2m 38s | |

**Wave D duration: Run 1 ~9m 10s (5 DFs) / Run 2 ~3m 57s (3 DFs after rebalance) / Run 3 ~2m 43s**

### Wave E (4 concurrent)

| Dataflow | Run 1 | Run 2 | Run 3 | Notes |
|----------|-------|-------|-------|-------|
| Refresh_Fact_Top50_JobCodes | 3m 7s | 3m 45s | 3m 16s | |
| Refresh_Fact_PartsPromo | 2m 7s | 2m 13s | 2m 8s | |
| Refresh_Fact_NegativeOnHand | 2m 7s | 2m 13s | 2m 8s | |
| Refresh_Fact_InSalOrd_InSalPar | 2m 6s | 2m 13s | 2m 10s | |

**Wave E duration: Run 1 ~3m 10s / Run 2 ~4m 4s / Run 3 ~3m 20s**

### Pipeline_Facts Wave Summary

| Wave | DFs | Run 1 | Run 2 | Run 3 | Bottleneck |
|------|-----|-------|-------|-------|------------|
| A | 6 | 16m 48s | ~40m (retry) | 22m 23s | WorkOrderParts |
| B | 6 | 5m 39s | 8m 19s | 8m 13s | Invoice_UniqueCustomers |
| C | 5 | 4m 8s | 7m 37s | 4m 11s | PartSales_24Hours |
| D | 3 | 9m 10s* | 3m 57s | 2m 43s | PendingInspections |
| E | 4 | 3m 10s | 4m 4s | 3m 20s | Top50_JobCodes |
| **Total** | **24** | **~39m 10s** | **~65m** | **~41m 12s** ✅ | |

*Wave D was 5 DFs in Run 1, restructured to 3 DFs after that run.

### Optimization History (Pipeline_Facts)

| Change | Before | After | Saved |
|--------|--------|-------|-------|
| Move FactPartTransactions (Wave D→A), Invoice_UniqueCustomers (Wave D→B) | Run 1 Wave D: 9m 10s | Run 2 Wave D: 3m 57s | ~5m in Wave D |
| Raise FactPartTransactions timeout 15m→25m, retry interval 30s→60s | Timed out in Run 2 | Applied for Run 3 | Prevents dedup retry chain |

---

## Pipeline_SemanticModels - Daily (17 SMs, 6 Waves of 3)

Run 1 (Successful): Feb 23, 2026, ~2:01 PM CST. 16/16 active SMs succeeded. InventoryAnalysis V3 inactive (OOM). **Total: ~43m 6s**

> **Note:** Measured during business hours (2 PM). CustomerAnatomy was unusually fast (3m 28s) due to warm Spark from prior testing.
> At 3:30 AM cold-start, expect Spark startup overhead (~2-4 min per session vs ~6-8 min mid-day), but overall total may be comparable or faster due to less contention.
> Inventory Analysis V3 requires incremental refresh implementation before it can be re-enabled (model is 1404 MB; F4 refresh limit ~1667 MB).

### Wave A1 - Heaviest Tier 1 SMs (3 concurrent, ~9m 18s)

| Semantic Model | Workspace | Refresh Time | Timeout | Notes |
|----------------|-----------|-------------|---------|-------|
| Customer Anatomy V2 | RP - Sandbox | 3m 28s | 40m | Unusually fast - warm Spark from prior testing |
| Inspections V2 | RP - Service | 9m 16s | 30m | Bottleneck for this wave |
| Inventory Analysis V3 | RP - Sandbox | **Inactive** | 20m | OOM: needs 1690 MB, F4 limit 1667 MB |

### Wave A2 - Tier 1 SMs (3 concurrent, ~5m 43s)

| Semantic Model | Workspace | Refresh Time | Notes |
|----------------|-----------|-------------|-------|
| 60+ Days Past Due | RP - Financial | 5m 40s | Bottleneck |
| Open Work Orders | RP - Service | 3m 41s | |
| Open Parts Tickets | RP - Parts | 1m 52s | Fastest wave member |

### Wave A3 - Tier 1 SMs (3 concurrent, ~7m 13s)

| Semantic Model | Workspace | Refresh Time | Notes |
|----------------|-----------|-------------|-------|
| First Pass Fill | RP - Parts | 5m 09s | |
| Negative On Hand | RP - Parts | 7m 11s | Bottleneck |
| Parts Adjustments | RP - Parts | 1m 53s | |

### Wave A4 - Tier 1 SMs (3 concurrent, ~9m 43s)

| Semantic Model | Workspace | Refresh Time | Notes |
|----------------|-----------|-------------|-------|
| Part Sales Low Margin | RP - Parts | 3m 37s | |
| Parts Promo V2 | RP - Sandbox | 9m 41s | Bottleneck - surprisingly slow for small model |
| Parts Not Re-Ordered | RP - Parts | 5m 39s | |

### Wave B1 - Tier 2 SMs (3 concurrent, ~4m 42s)

| Semantic Model | Workspace | Refresh Time | Notes |
|----------------|-----------|-------------|-------|
| Labor Performance V2 | RP - Service | 0m 51s | Very fast |
| Unique Parts Customers | RP - Parts | 3m 08s | |
| Combine Vault Sales | RP - Parts | 4m 40s | Bottleneck |

### Wave B2 - Tier 2 SMs (2 concurrent, ~6m 12s)

| Semantic Model | Workspace | Refresh Time | Notes |
|----------------|-----------|-------------|-------|
| Pin Capture | RP - Parts | 6m 10s | Bottleneck - slow for small model |
| Physical Inventory | RP - Parts | 1m 27s | |

### Pipeline_SemanticModels Wave Summary

| Wave | SMs | Duration | Bottleneck |
|------|-----|----------|------------|
| A1 | 3 (1 inactive) | ~9m 18s | Inspections (9m 16s) |
| A2 | 3 | ~5m 43s | 60+ Past Due (5m 40s) |
| A3 | 3 | ~7m 13s | Negative On Hand (7m 11s) |
| A4 | 3 | ~9m 43s | Parts Promo (9m 41s) |
| B1 | 3 | ~4m 42s | Combine Vault (4m 40s) |
| B2 | 2 | ~6m 12s | Pin Capture (6m 10s) |
| **Total** | **16 active** | **~43m 6s** ✅ | |

### Architecture Notes
- **3 concurrent max per wave** - F4 can only handle ~4 concurrent Spark/Livy sessions before HTTP 430 throttling
- Each notebook activity has ~2-8 min Spark cold-start overhead (less at 3:30 AM off-peak)
- Waves are gated by 1-second Wait activities; failure of a wave gate triggers failure alert email
- InventoryAnalysis disabled via `"state": "Inactive"` - re-enable after incremental refresh implementation

### Projected End-to-End Timeline (3:30 AM)

| Phase | Expected | Estimated Faster at 3:30 AM |
|-------|----------|-----------------------------|
| Raw Data | 24m 35s | ~20-22m (less ODBC contention) |
| InTrans | ~3m | ~2-3m |
| Dimensions | ~8m 26s | ~7-8m |
| Facts | ~41m | ~28-33m (less ODBC contention) |
| Semantic Models | ~43m | ~35-40m (less Spark competition) |
| **Total** | **~2h** | **~1h 35-45m** → **~5:05-5:15 AM** |

---

## CU Optimization Notes

### Pipeline_Raw_Data Performance (Batched, Feb 2026)
- **Total:** 24m 35s with 5 batches of 5-9 concurrent DFs
- **Peak CU:** ~2 CU (well within F4 limit of 4 CU sustained)
- **Batch balance:** Excellent - 9m / 3.5m / 4m / 4m / 3m

### Top Optimization Targets
1. **Fact_WorkOrderParts** (18.5 min) - Implement watermark-based incremental (target: 3-5 min)
2. **Fact_Service_Invoices** (10 min) - Query optimization or incremental refresh
3. **JDIS_PART_INFORMATION** (9m 13s) - Largest raw table bottleneck (Batch 1)

### Refresh Schedule Strategy
- **Raw tables:** 3:30 AM in Pipeline_Raw_Data (5 sequential batches)
- **InTrans:** After raw tables (incremental, ~3 min)
- **Dimensions:** After InTrans (all parallel, ~10-12 min)
- **Facts:** After dimensions (5 waves of 5 concurrent, ~32-35 min)
- **Semantic Models:** After facts (6 waves of 3 concurrent, ~17-20 min) - limited to 3/wave by F4 Spark session cap
- **Tier 2:** After Tier 1 SMs (~2-3 min)

### Total Daily CU Consumption
- **Estimated:** ~215 CU-minutes (3.7% of F4 daily budget of 5,760)
- **Target:** Stay under 75% sustained CU per phase

---

## How to Update This Document

1. **After test runs** - Update batch times with measured values
2. **After 3:30 AM production run** - Replace "3 PM baseline" note with true off-peak baselines
3. **When optimizing facts** - Document before/after times
4. **When adding new tables** - Add row to appropriate section

---

**Last Updated:** February 23, 2026
**F4 Capacity:** 4 CU sustained, 5,760 CU-min/day; ~4 concurrent Spark sessions max
**Pipeline_Raw_Data:** 24m 35s (32 DFs, 5 batches) - measured Feb 12 ~3 PM
**Pipeline_Dimensions:** 8m 26s (9 DFs, 2 batches) - measured Feb 19 ~12 PM
**Pipeline_Dimensions_Monthly:** 13m 17s (13 DFs, 3 batches) - measured Feb 19 ~12 PM
**Pipeline_Facts:** ~41m clean (Run 3, Feb 23 ~11 AM) - WorkOrderParts 22m is consistent bottleneck
**Pipeline_SemanticModels:** ~43m (Run 1, Feb 23 ~2 PM, 16/16 active SMs) - 6 waves of 3; InventoryAnalysis V3 disabled (OOM)
