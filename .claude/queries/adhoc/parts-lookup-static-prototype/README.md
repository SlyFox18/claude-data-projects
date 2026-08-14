# Parts Lookup — Static-File Backend Prototype

**Purpose:** Validate whether pre-partitioned static JSON files can serve
`parts-lookup-app`'s exact-match part-number search fast enough to replace
its current Fabric SQL Database backend, given the capacity cost confirmed
2026-08-13 (see `project_parts_lookup_tool` memory).

**Design:** `docs/superpowers/specs/2026-08-14-parts-lookup-static-file-prototype-design.md`

## Method

1. `extract.py` — one-time pull of `InMaster_PartsLookup_Raw` from
   `LH_Master_Data` via DuckDB over OneLake (same pattern as
   `.claude/queries/adhoc/kurt-sales/build_report.py`), saved locally as
   Parquet.
2. `partition.py` — splits the extract into one JSON file per
   `PartNumber` prefix bucket, at both 1-char and 2-char prefix length.
3. Manual upload of the chosen partition set to a test SharePoint document
   library.
4. `browser-test.js` — pasted into the browser console while viewing the
   library, times sequential and concurrent fetch+filter lookups.

Re-run `extract.py` any time for a fresh pull (requires `fab auth login`
and `az login` to be active).

**Known limitation:** `OnOrder` is excluded from the extract — it isn't
currently live on `InMaster_PartsLookup_Raw` in Fabric (the `.pq` file was
edited 2026-08-04 to add it, but that dataflow appears to need a redeploy
before the column actually lands on the table). Doesn't affect this
prototype's validation, which is about partitioning/file-size/latency, not
column completeness.

## Results

_(filled in after Tasks 2-5 run — see the design spec's Section 5 success
criteria for what's being measured)_
