# Refresh Pipeline - Operational Runbook

## Daily Operations

### Morning Check (8:00 AM)
1. Open Fabric Monitor > Pipeline runs
2. Verify Pipeline_Master_Orchestrator completed successfully
3. If failed: check which phase failed, review error, see troubleshooting below
4. Check email for daily summary notification

### Quick Verification
To confirm data is fresh, check the latest dates in key tables:
- Open any Tier 1 report in Power BI Service
- Check date slicers or last-updated timestamps
- Data should reflect yesterday's transactions

---

## Week 1 Setup (Foundation)

### Step 1: Update Master Orchestrator Schedule
1. In Fabric, navigate to **LH_Master_Data** workspace
2. Find **Pipeline_Master_Orchestrator**
3. Click **... > Settings > Schedule**
4. Change time from `07:30` to `03:30`
5. Verify weekdays: Monday through Friday
6. Set timezone: Central Standard Time
7. Set end date: `2026-12-31`
8. Save

**Alternative (Git sync):** Copy the `.schedules` JSON from `pipeline-schedule.md` into the pipeline's `.schedules` file in the fabric-workspace-docs repo, commit, and sync.

### Step 2: Disable Fact/SM Phases (Week 1 Only)
1. Open Pipeline_Master_Orchestrator in edit mode
2. Find activities that invoke Pipeline_Facts_Inspections and Pipeline_Facts_PartsReports
3. Set each to **Inactive** (right-click > Set as Inactive)
4. The `onInactiveMarkAs: "Succeeded"` setting means the pipeline continues past them
5. Save and publish

### Step 3: Enable Pipeline
1. Toggle the schedule to **Enabled**
2. Wait for next morning (3:30 AM) to run
3. Check results at 8 AM

### Step 4: Validate Week 1 Results
After first successful run:
- Note completion time for each phase
- Compare raw table times to baselines in REFRESH-TIMES.md
- Check CU metrics: Fabric Admin Portal > Capacity Metrics > LH_Master_Data
- Document results (Claude can help update REFRESH-TIMES.md)

---

## Troubleshooting

### Pipeline Failed - Phase 1 (Raw Data)
**Symptom:** One or more raw dataflows failed
**Common Causes:**
1. Source system (ODBC) down or unreachable
2. Network timeout
3. Table schema changed in source

**Actions:**
1. Check which specific dataflow failed (expand Pipeline_Raw_Data in monitor)
2. Try manual refresh of that dataflow
3. If ODBC issue: check if source system is accessible
4. Pipeline has 2 retries built in - if it failed after retries, the issue is persistent

### Pipeline Failed - Phase 2 (InTrans)
**Symptom:** InTrans_Incremental failed
**Common Causes:**
1. Watermark table corrupted
2. Source connection issue

**Actions:**
1. Check watermark value in control table
2. Try manual refresh
3. If watermark issue: may need to reset and do full refresh (consult docs)

### Pipeline Failed - Phase 4 (Facts)
**Symptom:** One or more fact dataflows failed
**Common Causes:**
1. Upstream raw/dim data issue
2. Query timeout (especially Fact_WorkOrderParts at 18.5 min)
3. CU throttling

**Actions:**
1. Check which fact failed
2. Verify upstream data is fresh (Phase 1-3 succeeded)
3. If timeout: check if dataflow timeout is sufficient (should be 20+ min for WorkOrderParts)
4. Try manual refresh of the failed fact

### Pipeline Failed - Phase 5 (Semantic Models)
**Symptom:** Semantic model refresh failed
**Common Causes:**
1. Dataset ID changed (report was moved or republished)
2. Workspace permissions issue
3. CU throttling

**Actions:**
1. Verify dataset ID is correct in the notebook
2. Check workspace permissions for the service principal/user
3. Try manual SM refresh from Power BI Service

### Pipeline Runs But Data Isn't Fresh
**Symptom:** Pipeline shows success but reports show old data
**Possible Causes:**
1. Semantic model refresh skipped or failed silently
2. Report is cached in browser
3. Wrong semantic model was refreshed (e.g., old version)

**Actions:**
1. Check Phase 5 specifically - did SM refresh actually run?
2. Hard refresh the report in browser (Ctrl+F5)
3. Verify dataset ID in notebook matches the correct report

### CU Throttling
**Symptom:** Dataflows taking much longer than baseline, or capacity metrics showing >100%
**Actions:**
1. Reduce concurrent dataflows per wave (from 5 to 3-4)
2. Add wait activities between waves
3. Check if other workloads are running simultaneously
4. Review CU-Usage-History.csv for trends

---

## Manual Operations

### Manually Trigger Full Pipeline
1. Navigate to Pipeline_Master_Orchestrator
2. Click **Run** (or trigger via REST API)
3. Monitor progress in Fabric Monitor

### Manually Refresh a Single Report
If a single report needs mid-day refresh:
1. Find the report's fact dataflow(s) in REFRESH-PIPELINE.md
2. Manually refresh those dataflows in LH_Master_Data
3. Then refresh the semantic model in the report's workspace
4. **Note:** Raw/dim data will be from the morning pipeline

### Add a New Report to the Pipeline
1. Identify fact dataflows and semantic model
2. Determine which wave the fact DFs belong in (by duration)
3. Add RefreshDataflow activities to the appropriate fact pipeline
4. Add SM refresh to Phase 5
5. Update REFRESH-PIPELINE.md and this runbook
6. Test with a manual pipeline run

### Disable a Report from Pipeline
1. Set its RefreshDataflow activities to Inactive
2. Set its SM refresh activity to Inactive
3. Activities will be marked as Succeeded and skipped

---

## Contacts & Escalation

| Issue | Action |
|-------|--------|
| Source system (ODBC) down | Contact IT / DBA team |
| Fabric capacity issues | Check Azure portal, consider scaling |
| Report data quality | Investigate specific dataflow transformation |
| Pipeline architecture changes | Consult refresh-pipeline documentation |

---

*Last Updated: February 2026*
