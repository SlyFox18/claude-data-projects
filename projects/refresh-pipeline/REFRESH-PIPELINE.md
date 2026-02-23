# Fabric Refresh Pipeline - Master Documentation

**Owner:** Brian Fox
**Capacity:** F4 (4 CU sustained)
**Schedule:** 3:30 AM CST, Monday-Friday
**Target Completion:** Before 5:30 AM (3+ hour buffer before 8 AM)

---

## Pipeline Architecture

### Overview

A 6-phase sequential pipeline refreshes all dataflows and semantic models daily. Phases run sequentially to respect data dependencies (Raw → Dims → Facts → Reports). Within each phase, dataflows run in parallel waves of 4-5 concurrent to stay under F4 CU limits.

```
3:30 AM  Pipeline_Master_Orchestrator
         │
         ├── Phase 1: Pipeline_Raw_Data (~14-16 min)
         │   ├── Batch 1 (5 concurrent): heaviest DFs (~8 min)
         │   ├── Batch 2 (5 concurrent): WK tables (~2.5 min)
         │   ├── Batch 3 (5 concurrent): tech & short (~2 min)
         │   └── Batch 4 (6 concurrent): remaining + inactive (~1 min)
         │
         ├── Phase 2: Pipeline_InTrans (~3 min)
         │   └── InTrans_Incremental + watermark update
         │
         ├── Phase 3: Pipeline_Dimensions (~10-12 min)
         │   └── 14+ dimension dataflows, all parallel
         │
         ├── Phase 4: Fact Tables (~32-35 min)
         │   ├── Wave A (5 concurrent): longest-running facts
         │   ├── Wave B (5 concurrent): medium facts
         │   ├── Wave C (5 concurrent): short facts
         │   ├── Wave D (5 concurrent): remaining facts
         │   └── Wave E (5 concurrent): final facts
         │
         ├── Phase 5: Semantic Model Refreshes (~10-12 min)
         │   ├── Wave A (3 concurrent): heaviest SMs
         │   ├── Wave B (5 concurrent): light SMs
         │   └── Wave C (5 concurrent): light SMs
         │
         └── Phase 6: Tier 2 Reports (~2-3 min)
             └── 4 semantic model refreshes

         ~4:50-5:05 AM complete
```

### Why 3:30 AM?

The previous 7:30 AM pipeline caused 200-600% performance degradation due to:
1. Source system (ODBC/EquipRDB64) under business load
2. Too many concurrent dataflows (20+) spiking CU to 214%

At 3:30 AM: zero source system contention, no competing workloads, baseline refresh times.

### Why Sequential Phases?

Data flows downstream: Raw Tables → Dimensions → Fact Tables → Semantic Models. Each phase depends on the previous one completing. Running facts before dims finish would use stale data.

### Why Wave-Based Facts?

24 fact dataflows running simultaneously would spike CU past F4 limits. Waves of 5 concurrent keep peak CU at ~3.5 (under the 4 CU sustained limit) while still achieving significant parallelism (102 min sequential → 32-35 min in waves).

---

## Phase Details

### Phase 1: Raw Data (~19-22 min)

**Pipeline:** Pipeline_Raw_Data (existing, restructured Feb 2026)
**Total DFs:** 32 (all active)
**Concurrency:** 5 sequential batches of 5-6 concurrent DFs each
**Why batched:** Running all DFs in parallel caused 4-7x performance degradation on F4 capacity (proven by test: ArMaster_Contact solo 1:46 vs 7:45 in 21-parallel). Batches of 5-6 keep CU under limits.

#### Batch 1 - Heaviest DFs (6 concurrent, ~8 min)

| Dataflow | Table | Solo Time |
|----------|-------|-----------|
| df_JDIS_PART_INFORMATION_Raw | jdis_Part_Information | ~8:44 |
| df_InTrans_PartsCounter_Raw | InTrans_PartsCounter | ~7:07 |
| df_Invoice_Raw | Invoice | ~6:13 |
| df_InHist_PmManage_Raw | InHist_PmManage | ~4:15 |
| df_GlTrans_Raw | GlTrans | ~3:58 |
| df_WKROFILE_Raw | WKROFILE | ~3:13 |

→ **Wait_Batch1_Gate** (all 6 must succeed)

#### Batch 2 - WK Tables (5 concurrent, ~3.5 min)

| Dataflow | Table | Solo Time |
|----------|-------|-----------|
| df_WKMECHWK_Raw | wkmechwk | ~2 min |
| df_WKOTHSUB_Raw | wkothsub | ~2 min |
| df_WKVEHFL_Raw | WKVEHFL | ~2 min |
| df_WKRODESC_Raw | wkrodesc | ~2 min |
| df_WKINVREG_Raw | WkInvReg | ~1 min |

→ **Wait_Batch2_Gate** (all 5 must succeed)

#### Batch 3 - Tech Detail & Short DFs (6 concurrent, ~3.5 min)

| Dataflow | Table | Solo Time |
|----------|-------|-----------|
| df_TechnicianInvoiceDetail_Raw | TechnicianInvoiceDetail | ~2 min |
| df_TechnicianPunchedDetail_Raw | TechnicianPunchedDetail | ~2 min |
| df_VHStock_Raw | vhstock | ~1 min |
| df_RepairOrderDetail_Raw | RepairOrderDetail | ~1 min |
| df_Insalord_Raw | insalord | ~1 min |
| df_InSalPar_Raw | insalpar | ~1 min |

→ **Wait_Batch3_Gate** (all 6 must succeed)

#### Batch 4 - Tech Summaries & Vehicle (6 concurrent, ~2-3 min)

| Dataflow | Table | Solo Time |
|----------|-------|-----------|
| df_TechnicianAttendance_Raw | TechnicianAttendance | ~1-2 min |
| df_TechnicianEfficiency_Raw | TechnicianEfficiency | ~1-2 min |
| df_TechnicianInvoice_Raw | TechnicianInvoice | ~1-2 min |
| df_TechnicianPunchedTime_Raw | TechnicianPunchedTime | ~1-2 min |
| df_VhStockAccess_Raw | VhStockAccess | ~1 min |
| df_VhTrans_Raw | VhTrans | ~1-2 min |

→ **Wait_Batch4_Gate** (all 6 must succeed)

#### Batch 5 - Remaining DFs (9 concurrent, ~3 min)

| Dataflow | Table | Solo Time |
|----------|-------|-----------|
| df_WarClaim_Raw | WarClaim | ~2:36 |
| df_WARSUBCI_LABOR_Raw | WARSUBCI_LABOR | ~2:36 |
| df_Branch_Name_Raw | Branch_Name | ~2:36 |
| df_BranchOperational_Raw | BranchOperational | ~2:36 |
| df_ArMaster_Contact_Raw | ArMaster_Contact | ~2:37 |
| df_ArMaster_Customer_Raw | ArMaster_Customer | ~3:06 |
| df_ARMASTER_Raw | armaster | ~2:36 |
| df_CONTACT_Raw | contact | ~3:06 |
| df_Technician_Raw | Technician | ~3:07 |

→ **Wait_For_All_Dataflows** → Email notifications

**All timeouts:** 15 minutes (increased from 10 min for safety margin)
**Retry policy:** 2 retries, 30 second interval

**Phase duration limited by:** Batch 1 bottleneck: df_JDIS_PART_INFORMATION_Raw (~7:27)

### Phase 2: InTrans Incremental (~3 min)

**Pipeline:** Pipeline_InTrans (existing)
- InTrans_Incremental watermark-based refresh
- 10.2M+ rows, only loads new/changed records
- Gold standard pattern: 2-3 min for 10M+ rows

### Phase 3: Dimensions (~10-12 min)

**Pipeline:** Pipeline_Dimensions (existing, add df_CustomerLookup)
**Concurrency:** All parallel

| Dataflow | Dimension | Est. Time |
|----------|-----------|-----------|
| df_dim_BranchLocation | dim_BranchLocation | ~1 min |
| df_dim_CustomerList | dim_CustomerList | ~2 min |
| df_dim_DateTable | dim_DateTable | ~1 min |
| df_dim_Parts | dim_Parts | ~5-6 min |
| df_dim_DealerGroupCode | dim_DealerGroupCode | ~1 min |
| df_dim_Franchise | dim_Franchise | ~1 min |
| df_dim_ModuleType | dim_ModuleType | ~1 min |
| df_dim_SLC | dim_SLC | ~1 min |
| df_dim_Source | dim_Source | ~1 min |
| df_dim_VendorCode | dim_VendorCode | ~1 min |
| df_dim_Technicians | dim_Technician_Code_Names | ~1 min |
| df_dim_Vehicle | dim_Vehicle | ~1 min |
| df_dim_UniqueCustomers | dim_UniqueCustomers | ~1 min |
| df_dim_Branch12Parts | dim_Branch12_Parts | ~1 min |
| df_CustomerLookup | lookup_UniqueCustomers_Invoice | ~1:30 |

**Phase duration limited by:** df_dim_Parts (~5-6 min)

### Phase 4: Fact Table Waves (~32-35 min)

See wave composition in plan file. Key points:
- Wave A limited by Fact_WorkOrderParts at 18.5 min (optimization target)
- Waves B-E complete in ~14 min combined
- After Fact_WorkOrderParts optimization: Phase 4 drops to ~20-25 min

### Phase 5: Semantic Model Refreshes (~10-12 min)

Refreshes all Tier 1 report semantic models using TridentNotebook activities.

**Wave A (3 concurrent, ~6 min):** Inventory Analysis (6m), Inspections (5m), Customer Anatomy V2 (2.5m)
**Wave B (5 concurrent, ~2 min):** Part Sales Low Margin, First Pass Fill, 60+ Past Due, Parts on Open Orders, Parts Adjustments
**Wave C (5 concurrent, ~1 min):** Negative On Hand, Parts Not Re-Ordered, Open Work Orders, Parts Promo, Combine Vault Sales

### Phase 6: Tier 2 Reports (~2-3 min)

**4 concurrent:** Labor Performance (1m), Unique Parts Customers (1m), Pin Capture (1.5m), Physical Inventory (1m)

---

## Report Tiers

### Tier 1: Daily - Fresh by 8 AM
| # | Report | Workspace | Fact DFs | SM Refresh |
|---|--------|-----------|----------|------------|
| 1 | Customer Anatomy V2 | RP - Sandbox → Parts | 8 | ~2.5 min |
| 2 | Inspections | RP - Service Reports | 3 | ~5 min |
| 3 | Inventory Analysis V3 | RP - Sandbox → Parts | 3 | ~6 min |
| 4 | 60+ Days Past Due | RP - Financial Reports | 1 | ~1 min |
| 5 | Open Work Orders | RP - Service Reports | 0 | ~1 min |
| 6 | Parts on Open Orders | RP - Parts Reports | 2 | ~1 min |
| 7 | First Pass Fill | RP - Parts Reports | 1 | ~1 min |
| 8 | Negative On Hand | RP - Parts Reports | 1 | ~1 min |
| 9 | Parts Adjustments | RP - Parts Reports | 1 | ~1 min |
| 10 | Part Sales Low Margin | RP - Parts Reports | 0 | ~2 min |
| 11 | Parts Promo | RP - Parts Reports | 1 | ~1 min |
| 12 | Parts Not Re-Ordered | RP - Parts Reports | 1 | ~1 min |

### Tier 2: Daily - Can Finish After 8 AM
| # | Report | Workspace | Fact DFs | SM Refresh |
|---|--------|-----------|----------|------------|
| 13 | Labor Performance | RP - Service Reports | 0 | ~1 min |
| 14 | Unique Parts Customers | RP - Parts Reports | 2 | ~1 min |
| 15 | Combine Vault Sales | RP - Parts Reports | 1 | ~1 min |
| 16 | Pin Capture | RP - Parts Reports | 0 | ~1.5 min |
| 17 | Physical Inventory | RP - Parts Reports | 0 | ~1 min |

### Tier 3: Weekly (Separate Pipeline - Monday 5:00 AM)
| # | Report | Workspace | Notes |
|---|--------|-----------|-------|
| 18 | Price Matrix | RP - Parts Reports | Shares Inventory Analysis facts |
| 19 | Bin Location | RP - Parts Reports | Uses raw jdis table directly |

### Not Scheduled
| Report | Reason |
|--------|--------|
| Table-Column-Names Search | Utility tool, on-demand only |

---

## Separate Pipelines (Independent of Daily)

| Pipeline | Schedule | Purpose |
|----------|----------|---------|
| DF_PartMaster_Snapshot_Daily | 2:00 AM daily | Daily parts snapshot |
| DF_PartMaster_Snapshot_Weekly | 1:00 AM Sunday | Weekly parts snapshot |
| NB_PartMaster_Retention_Policy | 1st of month, midnight | Snapshot cleanup |

### Future Multi-Refresh (Pluggable)
| Pipeline | Schedule | Prerequisites |
|----------|----------|---------------|
| Pipeline_PartsNotReordered_QuickRefresh | 9:30 AM + 4:00 PM | jdis + InTrans |
| Pipeline_InTrans (standalone) | 9:30 AM + 4:00 PM | None |
| Pipeline_JDIS_Refresh (new) | 9:30 AM + 4:00 PM | None |

---

## CU Budget

| Phase | Duration | Peak CU | CU-Minutes |
|-------|----------|---------|------------|
| Raw Data (4 batches) | ~15 min | ~2 CU | ~30 |
| InTrans | ~3 min | ~1 CU | ~3 |
| Dimensions | ~12 min | ~2.5 CU | ~30 |
| Facts | ~35 min | ~3.5 CU | ~123 |
| Semantic Models | ~10 min | ~2.5 CU | ~25 |
| Tier 2 | ~2 min | ~2 CU | ~4 |
| **Total** | **~77 min** | **Peak 3.5** | **~215** |

**F4 daily budget:** 5,760 CU-minutes
**Pipeline uses:** 3.7% of daily capacity
**Remaining for future:** 96.3% available

---

## Optimization Targets

### Fact_WorkOrderParts (18.5 min → 3-5 min target)
- Single largest bottleneck in entire pipeline
- Implement watermark-based incremental refresh (same as InTrans_Incremental)
- Saves ~15 min/day, drops Phase 4 from ~35 min to ~20 min
- **Priority:** After Week 4 (pipeline stable)

### df_Fact_Service_Invoices (10 min)
- Second longest Customer Anatomy fact
- Investigate query optimization or incremental refresh
- **Priority:** After Fact_WorkOrderParts

---

## Workspace Reference

| Workspace | Type | Reports |
|-----------|------|---------|
| LH_Master_Data | Lakehouse | All dataflows, pipelines, notebooks |
| RP - Parts Reports | Production | Most reports (Parts, Inventory, etc.) |
| RP - Service Reports | Production | Inspections, Open Work Orders, Labor Performance |
| RP - Financial Reports | Production | 60+ Days Past Due |
| RP - Sandbox | Testing | Customer Anatomy V2, Inventory Analysis V3, Parts Promo |
| RP - Service Sandbox | Testing | Empty currently |

### Sandbox Promotion Checklist
When moving a report from sandbox to production:
1. Rename report (remove "V2"/"V3" suffix)
2. Move to target production workspace
3. Update SM refresh notebook with new dataset ID
4. Update this documentation
5. Test first morning refresh

---

## Notifications

### Email (via Office365Email pipeline activities)
- **Success:** Daily summary after pipeline completes
- **Failure:** Immediate alert per failed phase
- **Recipient:** bfox@spitractor.com

### Teams (Future)
- Power Automate webhook for daily summary
- Failure alerts to dedicated channel

---

## Monitoring

### Daily Checks (Automated)
- Pipeline run history in Fabric Monitor
- CU utilization via Monitor-CUUsage.ps1
- Data freshness via Monitor-DataFreshness.ps1

### Weekly Review
- Compare refresh times to baselines (REFRESH-TIMES.md)
- Check for new CU spikes or throttling
- Review any failed runs from the week

### Key Metrics
| Metric | Target | Action if Exceeded |
|--------|--------|--------------------|
| Pipeline total duration | <95 min | Review wave composition |
| Phase 4 duration | <40 min | Check individual fact DFs |
| CU peak utilization | <75% sustained | Reduce wave concurrency |
| Success rate | >95% weekly | Investigate root cause |

---

*Created: February 2026*
*Last Updated: February 2026*
