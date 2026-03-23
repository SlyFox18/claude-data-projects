# Pipeline Schedule Reference

## Active Schedules

### Pipeline_Master_Orchestrator (Daily)
**Schedule:** 4:15 AM CST, Monday-Friday
**End Date:** 2026-12-31 (extend annually)
**Note:** Changed from 3:30 AM — IT restricts EquipRDB access until 4 AM; 4:15 ensures connection is active before first dataflow fires.

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/schedules/1.0.0/schema.json",
  "schedules": [
    {
      "enabled": true,
      "jobType": "Execute",
      "configuration": {
        "type": "Weekly",
        "startDateTime": "2026-02-17T00:00:00",
        "endDateTime": "2026-12-31T23:59:00",
        "localTimeZoneId": "Central Standard Time",
        "times": ["03:30"],
        "weekdays": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      }
    }
  ]
}
```

**To apply:** Replace the contents of `Pipeline_Master_Orchestrator.DataPipeline/.schedules` in the Fabric Git workspace, or update directly in Fabric UI under Pipeline Settings > Schedule.

### DF_PartMaster_Snapshot_Daily (Independent)
**Schedule:** 2:00 AM CST, Daily
**Status:** Already running, do not modify

### DF_PartMaster_Snapshot_Weekly (Independent)
**Schedule:** 1:00 AM CST, Sunday
**Status:** Already running, do not modify

### NB_PartMaster_Retention_Policy (Independent)
**Schedule:** 1st of month, midnight CST
**Status:** Already running, do not modify

---

## Future Schedules (Not Yet Active)

### Pipeline_PartsNotReordered_QuickRefresh (Twice Daily)
**When to enable:** After daily pipeline is stable (Week 5+)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/schedules/1.0.0/schema.json",
  "schedules": [
    {
      "enabled": true,
      "jobType": "Execute",
      "configuration": {
        "type": "Weekly",
        "startDateTime": "2026-03-01T00:00:00",
        "endDateTime": "2026-12-31T23:59:00",
        "localTimeZoneId": "Central Standard Time",
        "times": ["09:30", "16:00"],
        "weekdays": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      }
    }
  ]
}
```

### Pipeline_InTrans_Midday (3x Daily InTrans)
**When to enable:** When Parts Not Re-Ordered needs fresh InTrans data

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/schedules/1.0.0/schema.json",
  "schedules": [
    {
      "enabled": true,
      "jobType": "Execute",
      "configuration": {
        "type": "Weekly",
        "startDateTime": "2026-03-01T00:00:00",
        "endDateTime": "2026-12-31T23:59:00",
        "localTimeZoneId": "Central Standard Time",
        "times": ["09:15", "15:45"],
        "weekdays": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      }
    }
  ]
}
```

**Note:** Times are 15 min before Parts Not Re-Ordered to allow InTrans to complete first.

### Weekly Pipeline (Tier 3)
**When to enable:** After daily pipeline is stable

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/schedules/1.0.0/schema.json",
  "schedules": [
    {
      "enabled": true,
      "jobType": "Execute",
      "configuration": {
        "type": "Weekly",
        "startDateTime": "2026-03-01T00:00:00",
        "endDateTime": "2026-12-31T23:59:00",
        "localTimeZoneId": "Central Standard Time",
        "times": ["05:00"],
        "weekdays": ["Monday"]
      }
    }
  ]
}
```

---

## Schedule Timeline (Visual)

```
Daily (Mon-Fri):
  1:00 AM  DF_PartMaster_Snapshot_Weekly (Sunday only)
  2:00 AM  DF_PartMaster_Snapshot_Daily
  4:15 AM  Pipeline_Master_Orchestrator (Raw → InTrans → Dims → Facts)
  ~5:27 AM Master Orchestrator complete
  6:30 AM  Pipeline_SemanticModels (all reports except Parts Not Re-Ordered)
  ~7:20 AM Reports fresh — SM pipeline complete
  11:00 AM Pipeline_PartsNotReordered (InTrans + jdis + Fact + SM)
  ~11:20 AM Parts Not Re-Ordered fresh

Weekly (Monday only):
  5:00 AM  Pipeline_Weekly_Tier3

Monthly (1st):
  12:00 AM NB_PartMaster_Retention_Policy
```

---

## Seasonal Adjustments

### Harvest Season (typically Sept-Nov)
Consider:
- Add Saturday to daily pipeline weekdays
- Increase InTrans/jdis to 4x daily
- Monitor CU more closely

### Holiday/Downtime
- Source system may be down unpredictably
- Pipeline will retry 2x per dataflow automatically
- Check Monday morning for weekend failures
- No special calendar exclusion needed (retries handle it)

---

## How to Change Schedule

### Via Fabric UI:
1. Navigate to LH_Master_Data workspace
2. Find the pipeline
3. Click ... > Settings > Schedule
4. Modify time/days
5. Save

### Via Git Sync:
1. Edit the `.schedules` file in `fabric-workspace-docs` repo
2. Commit and push
3. Sync from Fabric workspace

---

*Last Updated: February 2026*
