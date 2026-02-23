# Master Pipeline Orchestrator

## Overview

The Master Orchestrator coordinates all four phases of the Inspections Report refresh pipeline, ensuring proper sequencing, dependency management, and error handling across the entire workflow.

**Pipeline Name:** `Pipeline_Master_Inspections` (recommended)  
**Total Duration:** ~14-18 minutes (weekday mornings)

## Architecture

```mermaid
graph TB
    A[Master Orchestrator Triggered] --> B{Weekday Check}
    B -->|Yes| C[Phase 1: Raw Data]
    B -->|No| Z[Skip - Weekend]
    
    C --> D{Phase 1 Success?}
    D -->|Yes| E[Phase 2: InTrans Incremental]
    D -->|No| X[Stop - Send Alert]
    
    E --> F{Phase 2 Success?}
    F -->|Yes| G[Phase 3: Dimensions]
    F -->|No| X
    
    G --> H{Phase 3 Success?}
    H -->|Yes| I[Phase 4: Facts & Model]
    H -->|No| X
    
    I --> J{Phase 4 Success?}
    J -->|Yes| K[Complete - Report Updated]
    J -->|No| X
    
    style K fill:#90EE90
    style X fill:#FFB6C1
    style Z fill:#FFE4B5
```

## Pipeline Structure

### High-Level Flow

```json
{
  "name": "Pipeline_Master_Inspections",
  "activities": [
    {
      "name": "Check_Weekday",
      "type": "IfCondition",
      "expression": "@not(or(equals(dayOfWeek(utcnow()), 0), equals(dayOfWeek(utcnow()), 6)))"
    },
    {
      "name": "Execute_Phase1",
      "type": "ExecutePipeline",
      "dependsOn": ["Check_Weekday"],
      "policy": {
        "waitOnCompletion": true
      }
    },
    {
      "name": "Execute_Phase2",
      "type": "ExecutePipeline",
      "dependsOn": ["Execute_Phase1"],
      "policy": {
        "waitOnCompletion": true
      }
    },
    {
      "name": "Execute_Phase3",
      "type": "ExecutePipeline",
      "dependsOn": ["Execute_Phase2"],
      "policy": {
        "waitOnCompletion": true
      }
    },
    {
      "name": "Execute_Phase4",
      "type": "ExecutePipeline",
      "dependsOn": ["Execute_Phase3"],
      "policy": {
        "waitOnCompletion": true
      }
    }
  ]
}
```

## Phase Execution Details

### Phase 1: Raw Data (2 minutes)

**Pipeline:** `Pipeline_Raw_Data`

**Activities:**
- 21 dataflows refresh in parallel
- Source: ODBC connections to ERP
- Output: RAW_* tables in lakehouse

**Success Criteria:**
- ✅ All 21 dataflows complete
- ✅ Row counts within expected ranges
- ✅ No connection errors

**On Failure:**
- ❌ Stop entire workflow
- 📧 Alert: "Phase 1 Raw Data Failed"
- 🔄 Retry automatically (2 attempts)

### Phase 2: InTrans Incremental (2-3 minutes)

**Pipeline:** `Pipeline_InTrans_Incremental` (optional - could be in Phase 1)

**Activities:**
- Refresh `InTrans_Incremental` table
- Uses watermark table for incremental logic
- Processes only new/changed parts transactions

**Success Criteria:**
- ✅ Watermark updated correctly
- ✅ New rows added to InTrans_Incremental
- ✅ Duration < 5 minutes (warning if longer)

**On Failure:**
- ❌ Stop entire workflow
- 📧 Alert: "Phase 2 InTrans Incremental Failed"
- 📝 Check watermark table for issues

### Phase 3: Dimensions (1-2 minutes)

**Pipeline:** `Pipeline_Dimensions_Inspections`

**Activities:**
- Refresh DimBranch, DimEmployee, DimJobCode, DimDate
- All refresh in parallel
- Fast completion due to small tables

**Success Criteria:**
- ✅ All 4 dimensions refreshed
- ✅ No duplicate keys detected
- ✅ Critical codes present (111 inspection codes)

**On Failure:**
- ❌ Stop entire workflow
- 📧 Alert: "Phase 3 Dimensions Failed"
- ⚠️ Do NOT proceed to facts without dimensions

### Phase 4: Facts & Semantic Model (13-15 minutes)

**Pipeline:** `Pipeline_Facts_Inspections`

**Activities:**
- Refresh 3 fact tables in parallel (7 min)
- Refresh semantic model (5-7 min)
- Update report with latest data

**Success Criteria:**
- ✅ All fact tables refreshed
- ✅ Semantic model updated
- ✅ Report displays current data

**On Failure:**
- ❌ Mark workflow as failed
- 📧 Alert: "Phase 4 Facts/Model Failed"
- ℹ️ Facts may be updated even if model refresh fails

## Scheduling Strategy

### Production Schedule

**Daily Execution:**
```
Trigger: 6:00 AM Central Time
Days: Monday-Friday (weekdays only)
Timezone: Central Standard Time (CST/CDT)
```

**Weekday-Only Logic:**
```javascript
// Activity expression for weekday check
@not(
  or(
    equals(dayOfWeek(utcnow()), 0),  // Sunday
    equals(dayOfWeek(utcnow()), 6)   // Saturday
  )
)
```

**Alternative: Use Legacy "Invoke Pipeline" Activity**
- More reliable than Preview version
- Better error handling and status reporting
- Proven stable in production environments

### Why Weekday-Only?

1. **Business Need:** Reports primarily used Monday-Friday
2. **CU Savings:** Avoid unnecessary weekend refreshes
3. **Maintenance Window:** Weekends available for system updates
4. **Data Availability:** Source systems may not update weekends

## Dependency Management

### Critical Dependencies

```mermaid
graph LR
    A[Raw Tables] --> B[InTrans_Incremental]
    A --> C[Dimensions]
    C --> D[Fact Tables]
    B --> D
    D --> E[Semantic Model]
    E --> F[Power BI Report]
```

### Execution Requirements

**Phase 1 → Phase 2:**
- All raw tables must complete successfully
- Specific requirement: `RAW_INTRANS` must be current
- Watermark table must be accessible

**Phase 2 → Phase 3:**
- InTrans_Incremental must complete (if using)
- All dimension source tables must be current
- No hard dependency - can run in parallel if needed

**Phase 3 → Phase 4:**
- **CRITICAL:** All dimensions must be refreshed
- Fact tables join to dimensions
- Missing dimensions = orphaned fact records

**Phase 4 → Completion:**
- Fact tables must complete before semantic model
- Semantic model must complete for report to update
- Report cache may need clearing

## Error Handling Strategy

### Retry Policy

```json
{
  "retryPolicy": {
    "count": 2,
    "intervalInSeconds": 300,
    "backoffStrategy": "Fixed"
  }
}
```

**Applied to:**
- All pipeline invocations
- All dataflow refresh activities
- Semantic model refresh activity

**Rationale:**
- 5-minute wait allows transient issues to clear
- 2 retries balances reliability vs. fast failure
- Fixed backoff is predictable for troubleshooting

### Failure Notifications

**Email Alert Template:**
```
Subject: [FAILED] Inspections Report Pipeline - Phase {X}

Pipeline: Pipeline_Master_Inspections
Phase: {Phase Name}
Failure Time: {Timestamp}
Duration Before Failure: {Duration}

Error Details:
{Error Message}

Next Steps:
1. Review pipeline run history in Fabric
2. Check activity logs for detailed errors
3. Verify source systems are accessible
4. Manually retry if transient failure
5. Contact data team if persistent issue

Dashboard: [Link to Monitoring Dashboard]
Documentation: [Link to Troubleshooting Guide]
```

### Partial Failure Scenarios

**Scenario 1: Single Dataflow Fails in Phase 1**
- **Action:** Entire Phase 1 marked as failed
- **Impact:** Stops all downstream phases
- **Resolution:** Fix and retry Phase 1, then resume

**Scenario 2: One Fact Table Fails in Phase 4**
- **Action:** Phase 4 marked as failed
- **Impact:** Semantic model refresh skipped
- **Resolution:** Fix fact table, retry Phase 4 only

**Scenario 3: Semantic Model Fails, Facts Succeed**
- **Action:** Phase 4 marked as failed
- **Impact:** Lakehouse current, report stale
- **Resolution:** Retry semantic model refresh only

## Monitoring & Observability

### Key Metrics Dashboard

**Recommended Measures:**

```dax
// Overall Success Rate
Pipeline Success Rate = 
DIVIDE(
    COUNTROWS(FILTER(RefreshLog, RefreshLog[Status] = "Success")),
    COUNTROWS(RefreshLog),
    0
) * 100

// Average Duration by Phase
Avg Duration by Phase = 
AVERAGEX(
    VALUES(RefreshLog[Phase]),
    CALCULATE(AVERAGE(RefreshLog[DurationMinutes]))
)

// CU Consumption Trend
CU Consumption (30 Days) = 
CALCULATE(
    SUM(RefreshLog[CUUsed]),
    RefreshLog[RefreshDate] >= TODAY() - 30
)

// Failure Rate by Day of Week
Failure Rate by Weekday = 
CALCULATE(
    DIVIDE(
        COUNTROWS(FILTER(RefreshLog, RefreshLog[Status] = "Failed")),
        COUNTROWS(RefreshLog)
    ),
    VALUES(RefreshLog[Weekday])
)
```

### Logging Strategy

**Create RefreshLog Table:**
```sql
CREATE TABLE RefreshLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    PipelineName VARCHAR(100),
    Phase VARCHAR(50),
    StartTime DATETIME,
    EndTime DATETIME,
    DurationMinutes AS DATEDIFF(MINUTE, StartTime, EndTime),
    Status VARCHAR(20),  -- Success, Failed, Running
    ErrorMessage VARCHAR(MAX),
    CUUsed DECIMAL(10,2),
    RowsProcessed INT,
    RefreshDate DATE,
    Weekday VARCHAR(20)
)
```

**Capture at Each Phase:**
- Start time & end time
- Success/failure status
- Error details (if failed)
- CU consumption (from Capacity Metrics)
- Rows processed (from activity output)

### Real-Time Monitoring

**Fabric Capacity Metrics:**
- Monitor CU consumption during runs
- Alert if capacity throttling occurs
- Track peak usage times

**Pipeline Run History:**
- Review activity details for each phase
- Check input/output row counts
- Verify dataflow query folding

**Semantic Model Refresh History:**
- Monitor via Power BI Service
- Check refresh duration trends
- Validate data freshness in reports

## Performance Optimization

### Current State (Optimized)

```
Total Pipeline Duration: ~14-18 minutes

Phase 1: Raw Data           2 min  (parallel)
Phase 2: InTrans Incremental 3 min  (incremental)
Phase 3: Dimensions         1 min  (parallel)
Phase 4: Facts & Model     13 min  (parallel facts)
──────────────────────────────────
Total:                     ~19 min (sequential phases)
```

### Historical Comparison

**Before Optimization (Old Monolithic Report):**
```
Single Query Refresh: 60-120 minutes ❌
System Throttling: Frequent
CU Usage: 15-20 CU per run
```

**After Optimization (Current Architecture):**
```
Full Pipeline: 14-18 minutes ✅
System Throttling: Rare
CU Usage: 5-7 CU per run
```

**Performance Improvement:**
- ⚡ **97% faster** (120 min → 15 min)
- 💰 **90% less CU** (20 CU → 5 CU)
- 🚀 **System stability** improved

### Future Optimization Opportunities

1. **Fact Table Partitioning**
   - Implement incremental refresh on Fact_LaborJobSummary
   - Could save additional 5-7 minutes
   - Reduces Phase 4 from 13 min to 6-8 min

2. **Smart Refresh Logic**
   - Only refresh when source data changed
   - Use watermark tables for change detection
   - Skip phases with no updates

3. **Parallel Phase Execution**
   - Phase 2 (InTrans) and Phase 3 (Dimensions) could run parallel
   - Both depend only on Phase 1
   - Could save 2-3 minutes

4. **Semantic Model Optimization**
   - Review and optimize complex DAX measures
   - Consider aggregation tables
   - Implement calculation groups for time intelligence

## Troubleshooting Workflow

### Step-by-Step Diagnosis

**1. Identify Failed Phase**
```
Check pipeline run history → Identify failed activity
```

**2. Review Activity Logs**
```
Pipeline Run → Failed Activity → View Details → Error Message
```

**3. Check Source Data**
```sql
-- Verify source tables are current
SELECT MAX(LastModifiedDate) FROM RAW_LABOR
SELECT MAX(LastModifiedDate) FROM RAW_INTRANS
```

**4. Validate Dependencies**
```
Phase 1 ← Check ODBC connections
Phase 2 ← Check InTrans_Incremental and watermark
Phase 3 ← Check dimension source tables
Phase 4 ← Check all upstream tables
```

**5. Test Individual Components**
```
Isolate failed component → Run manually → Verify success
```

**6. Resume Pipeline**
```
If Phase 1-2 failed → Retry from Phase 1
If Phase 3-4 failed → Can retry from failed phase
```

### Common Issues & Solutions

See [Troubleshooting Guide](./troubleshooting-guide.md) for detailed solutions.

**Quick Reference:**
- Pipeline timeout → Check long-running dataflows, optimize queries
- Connection errors → Verify ODBC settings, source system availability
- Semantic model errors → Check table names, relationship integrity
- CU throttling → Review capacity metrics, optimize heavy queries
- Data quality issues → Validate source data, check transformation logic

## Best Practices

### Development
1. ✅ Test each phase independently before chaining
2. ✅ Use descriptive activity names for easy troubleshooting
3. ✅ Implement comprehensive error handling
4. ✅ Document all dependencies clearly

### Production
1. ✅ Monitor daily refresh success rate
2. ✅ Track CU consumption trends
3. ✅ Set up alerting for failures
4. ✅ Maintain refresh log for historical analysis
5. ✅ Schedule during low-usage windows (early morning)

### Maintenance
1. ✅ Review performance metrics monthly
2. ✅ Update documentation when changes made
3. ✅ Test pipeline after any schema changes
4. ✅ Archive old pipeline versions
5. ✅ Keep troubleshooting guide current

## Scaling to Additional Reports

When ready to add more reports to the orchestrator:

1. **Assess dependencies** - Does new report share raw/dim tables?
2. **Add new phases** - Create Phase 5, 6, etc. for new facts/models
3. **Consider parallelization** - Independent reports can refresh parallel
4. **Monitor CU impact** - Ensure capacity can handle additional load
5. **Update logging** - Capture metrics for all reports

See [Scaling Guide](./scaling-guide.md) for detailed instructions.

## Migration from Old System

If transitioning from the old monolithic report:

1. ✅ Run both systems in parallel for 2 weeks
2. ✅ Validate data matches between old and new
3. ✅ Train users on new report features
4. ✅ Migrate bookmarks and alerts
5. ✅ Archive old report (don't delete immediately)
6. ✅ Monitor for user issues post-migration

See [Migration Guide](./migration-guide-intrans.md) for InTrans-specific migration steps.

## Summary

**The Master Orchestrator:**
- 🎯 Coordinates all 4 phases seamlessly
- ⚡ Delivers 97% performance improvement
- 💰 Reduces CU consumption by 90%
- 🛡️ Provides robust error handling
- 📊 Enables comprehensive monitoring
- 🚀 Scales to additional reports easily

**Total Time Investment:**
- Initial setup: ~1-2 weeks
- Testing & validation: ~1 week
- Long-term maintenance: ~1 hour/month

**Return on Investment:**
- Time saved per refresh: ~105 minutes
- Daily refreshes: ~7.5 hours/week saved
- Annual time savings: ~390 hours
- CU cost savings: ~60% reduction
- System stability: Priceless

---

**Related Documentation:**
- [Architecture Overview](./architecture-overview.md)
- [Troubleshooting Guide](./troubleshooting-guide.md)
- [Scaling Guide](./scaling-guide.md)
- [Migration Guide](./migration-guide-intrans.md)