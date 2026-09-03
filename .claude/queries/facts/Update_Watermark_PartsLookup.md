# Update_Watermark_PartsLookup (Notebook)

Location: LH_Master_Data → Notebooks. Runs as the last step of
`Pipeline_PartsLookup_Incremental`, after `Merge_Staging_Incremental_To_Live`
succeeds. Mirrors the InTrans_Incremental Update_Watermark notebook pattern
(`projects/inspections - report/documentation/pipelines/phase-2-intrans-incremental.md`),
adapted for this table's TableName, with an added null-guard for empty runs.

**Do not confuse with `Parts_Availability_App_WaterMark.Notebook`** — that
existing notebook is the one-time Task 3 seed script (`INSERT` of the
`2018-01-01` starting row). If it gets wired into the pipeline instead of
this one, every run resets the watermark back to 2018-01-01 and forces a
full historical re-pull every time, silently defeating the incremental
design. Confirmed as a real, distinct item during the 2026-08-05 build —
easy to mix up by name alone.

Built 2026-08-05 as a `%%sql` magic cell, matching the actual established
local convention (`Update_InTrans_Watermark`, the working InTrans-side
equivalent) rather than the more verbose `spark.sql()` Python form originally
sketched here — simpler, and consistent with every other watermark-update
notebook already in this workspace. Lakehouse default attached to
`LH_Master_Data` (id `3e74497b-8c51-4a1a-91a1-888c59118f48`, workspace
`b48cdb35-7ce3-46de-96df-d70db77649cb`).

```sql
%%sql
UPDATE watermark_control
SET LastLoadedDatetime = COALESCE((SELECT MAX(LastUpdDatetime) FROM InMaster_PartsLookup_Incremental), LastLoadedDatetime),
    LastUpdated = current_timestamp()
WHERE TableName = 'InMaster_PartsLookup'
```

Optional second cell for manual verification after a run:
```sql
%%sql
SELECT * FROM watermark_control WHERE TableName = 'InMaster_PartsLookup'
```

**Edge case handled:** if a run pulls zero new rows (nothing changed since
the last watermark), `InMaster_PartsLookup_Incremental` is empty and
`MAX(LastUpdDatetime)` is `NULL`. `COALESCE(..., LastLoadedDatetime)` falls
back to the existing watermark value in that case instead of overwriting it
with `NULL`, which would otherwise force every subsequent run back to a full
extract.
