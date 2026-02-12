# Phase 1: Raw Data Refresh

**Pipeline Name:** `Pipeline_Raw_Data`  
**Phase:** 1 of 4  
**Purpose:** Load source data from Dealer Management System  
**Strategy:** Parallel full refresh of 21 tables  
**Duration:** ~8 minutes  
**Author:** Brian Fox  
**Last Updated:** November 21, 2025

---

## Table of Contents
- [Overview](#overview)
- [Pipeline Architecture](#pipeline-architecture)
- [Dataflow List](#dataflow-list)
- [Execution Strategy](#execution-strategy)
- [Weekday-Only Logic](#weekday-only-logic)
- [Connection Management](#connection-management)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)

---

## Overview

Phase 1 is the foundation of the entire data refresh process. It connects to the Dealer Management System via ODBC and loads 21 raw tables in parallel into the Lakehouse using Delta Lake format.

### Key Characteristics
- **Execution Mode**: Parallel (all 21 dataflows run simultaneously)
- **Refresh Type**: Full refresh (replaces all data each time)
- **Storage Format**: Delta Lake (optimized for analytics)
- **Connection Type**: ODBC to source database
- **Scheduling**: Weekday-only (conditional logic)

### Success Criteria
- All 21 dataflows complete successfully
- Data written to Lakehouse tables
- No timeout or connection errors
- Duration stays under 10 minutes

---

## Pipeline Architecture

### High-Level Flow

```
Pipeline_Raw_Data
│
├─ Conditional Check: Is today a weekday?
│  └─ If NO: Skip entire pipeline
│  └─ If YES: Continue
│
├─ 21 Dataflow Activities (Parallel Execution)
│  ├─ df_RAW_wkothsub
│  ├─ df_RAW_wkmechwk
│  ├─ df_RAW_WKROFILE
│  ├─ df_RAW_wkrodesc
│  ├─ df_RAW_InTrans
│  ├─ df_RAW_RepairOrderDetail
│  ├─ df_RAW_TechnicianPunchedDetail
│  ├─ df_RAW_Technician
│  ├─ df_RAW_TechnicianInvoiceDetail
│  ├─ df_RAW_vhstock
│  ├─ df_RAW_VhStockAccess
│  ├─ df_RAW_WarClaim
│  ├─ df_RAW_WarsubCLLabour
│  ├─ df_RAW_wkinvreg
│  ├─ df_RAW_wkmechwk
│  ├─ df_RAW_wkothsub
│  ├─ df_RAW_WKROFILE
│  ├─ df_RAW_wkrodesc
│  ├─ df_RAW_SlicerTable
│  ├─ df_RAW_idls_Part_Information
│  └─ df_RAW_InHist_PmManage
│
└─ All complete → Success
   Any failure → Failure Alert (Master Orchestrator handles)
```

### Execution Timeline

```
Start: 00:00
│
├─ 00:00-00:30: Fast dataflows complete (30-45 seconds each)
│  └─ Technician, SlicerTable, etc.
│
├─ 00:30-02:00: Medium dataflows complete (1-2 minutes each)
│  └─ RepairOrderDetail, TechnicianPunchedDetail, etc.
│
├─ 02:00-08:00: Slow dataflows complete (2-8 minutes each)
│  └─ wkothsub, InTrans, wkmechwk (largest tables)
│
End: ~08:00 (limited by slowest dataflow)
```

**Note**: Total time is determined by the *slowest* dataflow, not the sum of all dataflows, because they run in parallel.

---

## Dataflow List

### Complete Table Inventory

| Dataflow Name | Source Table | Destination | Avg Duration | Row Count | Purpose |
|--------------|--------------|-------------|--------------|-----------|---------|
| df_RAW_wkothsub | wkothsub | Raw_wkothsub | 6-8 min | ~2M | Work order job lines (inspection codes) |
| df_RAW_wkmechwk | wkmechwk | Raw_wkmechwk | 5-7 min | ~1.5M | Labor entries by technician |
| df_RAW_WKROFILE | WKROFILE | Raw_WKROFILE | 4-6 min | ~800K | Work order headers |
| df_RAW_wkrodesc | wkrodesc | Raw_wkrodesc | 3-4 min | ~500K | Work order descriptions |
| df_RAW_InTrans | InTrans | Raw_InTrans | 2-3 min | ~8.3M | Parts transactions (source for Phase 2) |
| df_RAW_RepairOrderDetail | RepairOrderDetail | Raw_RepairOrderDetail | 2-3 min | ~600K | RO detail records |
| df_RAW_TechnicianPunchedDetail | TechnicianPunchedDetail | Raw_TechnicianPunchedDetail | 1-2 min | ~400K | Technician time punches |
| df_RAW_Technician | Technician | Raw_Technician | 30-45 sec | ~200 | Technician master |
| df_RAW_TechnicianInvoiceDetail | TechnicianInvoiceDetail | Raw_TechnicianInvoiceDetail | 1-2 min | ~300K | Tech invoice details |
| df_RAW_vhstock | vhstock | Raw_vhstock | 1-2 min | ~100K | Vehicle/equipment stock |
| df_RAW_VhStockAccess | VhStockAccess | Raw_VhStockAccess | 30-45 sec | ~50K | Stock access control |
| df_RAW_WarClaim | WarClaim | Raw_WarClaim | 2-3 min | ~200K | Warranty claims |
| df_RAW_WarsubCLLabour | WarsubCLLabour | Raw_WarsubCLLabour | 1-2 min | ~150K | Warranty labor details |
| df_RAW_wkinvreg | wkinvreg | Raw_wkinvreg | 1-2 min | ~100K | Invoice register |
| df_RAW_SlicerTable | SlicerTable | Raw_SlicerTable | 30 sec | ~10 | Branch slicer lookup |
| df_RAW_idls_Part_Information | idls_Part_Information | Raw_idls_Part_Information | 2-3 min | ~250K | Parts master data |
| df_RAW_InHist_PmManage | InHist_PmManage | Raw_InHist_PmManage | 1-2 min | ~100K | PM management history |
| ... | ... | ... | ... | ... | (21 total dataflows) |

### Table Categories

#### Critical for Inspections Report
- **wkothsub**: Contains inspection job codes
- **wkmechwk**: Labor hours by technician
- **WKROFILE**: Work order metadata
- **InTrans**: Parts transactions (feeds Phase 2)
- **RepairOrderDetail**: Repair order details
- **TechnicianPunchedDetail**: Time tracking

#### Supporting Tables
- **Technician**: Technician roster
- **vhstock**: Equipment inventory
- **WarClaim**: Warranty information
- **idls_Part_Information**: Parts catalog

---

## Execution Strategy

### Parallel Execution

All 21 dataflows execute simultaneously, not sequentially. This dramatically reduces total time:

**Sequential Execution (if we did this - we don't):**
```
Total Time = Sum of all dataflows
= 6 min + 5 min + 4 min + ... (21 dataflows)
= ~60-80 minutes
```

**Parallel Execution (what we actually do):**
```
Total Time = Longest single dataflow
= MAX(6 min, 5 min, 4 min, ...)
= ~8 minutes
```

**CU Efficiency:**
- Parallel execution uses more CU *simultaneously*
- But total CU consumption is roughly the same
- Massive time savings justify the simultaneous CU usage

### Why Full Refresh?

For Phase 1 raw tables, we use full refresh (not incremental) because:

1. **Source System Limitations**: ODBC source doesn't have reliable change tracking
2. **Data Volume**: Most raw tables are small enough (<1M rows) for fast full refresh
3. **Simplicity**: No watermark logic needed at raw layer
4. **Data Quality**: Ensures source and destination stay in sync

**Exception**: InTrans is loaded as full refresh here, but Phase 2 implements incremental refresh for the optimized version.

---

## Weekday-Only Logic

### Business Justification

Raw data only needs refreshing on business days (Monday-Friday) because:
- Source system is only updated during business hours
- Weekend refreshes waste CU capacity
- Stakeholders don't need weekend data updates
- Reduces overall CU consumption by ~28% (skipping 2 of 7 days)

### Implementation

The pipeline uses conditional logic to check the current day:

```
IF @formatDateTime(utcNow(), 'dddd') NOT IN ('Saturday', 'Sunday')
THEN
    Execute all 21 dataflows
ELSE
    Skip pipeline (exit successfully)
END IF
```

**PowerQuery Expression:**
```powerquery
@not(
    or(
        equals(dayOfWeek(utcNow()), 0),  // Sunday = 0
        equals(dayOfWeek(utcNow()), 6)   // Saturday = 6
    )
)
```

### Override Option

To manually run on weekends for testing or special needs:
1. Temporarily disable the conditional check
2. Run the pipeline manually
3. Re-enable the conditional check

---

## Connection Management

### ODBC Connection

**Connection String Components:**
- **Driver**: SQL Server ODBC Driver
- **Server**: [Dealer Management System Server]
- **Database**: [Production Database]
- **Authentication**: Windows Authentication (service account)

### Connection Best Practices

1. **Use Service Account**: Not individual user credentials
2. **Read-Only Access**: Raw dataflows only need SELECT permissions
3. **Connection Timeout**: Set to 300 seconds (5 minutes)
4. **Query Timeout**: Set to 600 seconds (10 minutes)
5. **Connection Pooling**: Enabled for efficiency

### Security Considerations

- **Credentials Stored Securely**: In Fabric gateway/connection
- **Least Privilege**: Service account has minimal permissions
- **Audit Trail**: All connections logged in source system
- **No Direct User Access**: Users query Lakehouse, not source

---

## Performance Optimization

### Current Optimizations

1. **Parallel Execution**: All 21 dataflows run simultaneously
2. **Delta Lake Format**: Optimized columnar storage in Lakehouse
3. **Full Refresh Strategy**: Simpler and faster for small-medium tables
4. **ODBC Optimization**: Batch inserts and connection pooling
5. **Weekday-Only**: Reduces unnecessary refreshes

### Dataflow-Specific Optimizations

**For slow dataflows (6+ minutes):**
- Minimize transformations in dataflow
- Push complex logic to downstream fact tables
- Consider adding indexes on source system (if possible)

**For fast dataflows (< 1 minute):**
- No optimization needed
- Current performance acceptable

### Monitoring Metrics

Track these metrics over time:
- **Total Phase 1 duration** (should stay under 10 minutes)
- **Individual dataflow duration** (flag if >2x normal)
- **Failure rate** (should be <5%)
- **CU consumption** (baseline for comparison)

---

## Troubleshooting

### Common Issues

#### Issue 1: One or More Dataflows Fail

**Symptoms:**
- Pipeline_Raw_Data shows failure
- Specific dataflow(s) marked as failed
- Error message mentions connection or timeout

**Common Causes:**
1. Source system unavailable (maintenance, network issue)
2. ODBC connection timeout
3. Source table schema change
4. Insufficient Fabric capacity

**Resolution Steps:**
1. Check source system availability
2. Verify ODBC connection in Fabric gateway
3. Review dataflow error details
4. Check if source table schema changed
5. Retry failed dataflow manually
6. If timeout: Increase query timeout setting

#### Issue 2: Pipeline Takes Longer Than Expected

**Symptoms:**
- Phase 1 duration exceeds 15 minutes
- All dataflows succeed but very slow
- CU usage appears normal

**Common Causes:**
1. Source system performance degradation
2. Network latency between source and Fabric
3. Large data volume increase
4. Fabric capacity constraints

**Resolution Steps:**
1. Identify which dataflow(s) are slow
2. Query source table directly to check size
3. Check Fabric capacity metrics for throttling
4. Consider moving to higher Fabric capacity if consistent

#### Issue 3: Data Quality Issues

**Symptoms:**
- Data arrives but doesn't match source
- Row counts don't match
- Missing records

**Common Causes:**
1. Source system changes during refresh
2. Timezone issues in datetime filters
3. ODBC driver version mismatch

**Resolution Steps:**
1. Compare row counts: Source vs Lakehouse
2. Check for duplicates in Lakehouse
3. Verify ODBC driver version matches source database
4. Review any transformation logic in dataflows

#### Issue 4: Weekend Execution When It Shouldn't

**Symptoms:**
- Pipeline runs on Saturday or Sunday
- Weekday-only logic not working

**Common Causes:**
1. Conditional check expression error
2. Timezone differences (UTC vs local)
3. Manual override still enabled

**Resolution Steps:**
1. Review conditional expression syntax
2. Verify timezone used in dayOfWeek() function
3. Check if manual override was left enabled

---

## Related Documentation

- [[architecture-overview|Architecture Overview]] - Complete system architecture
- [[phase-2-intrans-incremental|Phase 2: InTrans Incremental]] - Next phase after raw data
- [[troubleshooting-guide|Troubleshooting Guide]] - Detailed troubleshooting steps

---

## Maintenance Tasks

### Weekly
- ✅ Review Phase 1 execution times
- ✅ Check for any failures in past week
- ✅ Monitor CU consumption trends

### Monthly
- ✅ Review dataflow performance metrics
- ✅ Identify slow-performing dataflows
- ✅ Check source system for schema changes
- ✅ Update documentation if changes made

### Quarterly
- ✅ Review ODBC connection settings
- ✅ Evaluate need for optimization
- ✅ Update dataflow list if tables added/removed

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-21 | Brian Fox | Initial documentation |

---

*This document is part of the Inspections Report pipeline documentation maintained in the South Plains Implement DATA-PROJECTS repository.*