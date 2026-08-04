# Update_Watermark_PartsLookup (Notebook)

Location: LH_Master_Data → Notebooks. Runs as the last step of
`Pipeline_PartsLookup_Incremental`, after `Merge_Staging_Incremental_To_Live`
succeeds. Mirrors the InTrans_Incremental Update_Watermark notebook pattern
(`projects/inspections - report/documentation/pipelines/phase-2-intrans-incremental.md`),
adapted for this table's TableName, with an added null-guard for empty runs.

```python
max_datetime_df = spark.sql("""
    SELECT MAX(LastUpdDatetime) as MaxDatetime
    FROM InMaster_PartsLookup_Incremental
""")
max_datetime = max_datetime_df.collect()[0]['MaxDatetime']

print(f"Latest LastUpdDatetime in InMaster_PartsLookup_Incremental: {max_datetime}")

if max_datetime is not None:
    spark.sql(f"""
        UPDATE watermark_control
        SET LastLoadedDatetime = '{max_datetime}',
            LastUpdated = current_timestamp()
        WHERE TableName = 'InMaster_PartsLookup'
    """)
    print(f"Watermark updated to {max_datetime}")
else:
    print("No new rows this run — watermark left unchanged")
```

**Edge case handled:** if a run pulls zero new rows (nothing changed since
the last watermark), `InMaster_PartsLookup_Incremental` is empty and
`MAX(LastUpdDatetime)` is `null`. The guard above prevents overwriting a
valid watermark with `null`, which would otherwise force every subsequent
run back to a full extract.
