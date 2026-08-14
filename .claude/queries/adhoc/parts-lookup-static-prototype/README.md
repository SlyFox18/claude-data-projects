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

- **Extraction (Task 1):** 1,060,738 rows in 10.7 sec (`OnOrder` excluded,
  see Known limitation above).
- **Partitioning (Task 2):**

  | Prefix length | Files | Size range | Total | Generation time |
  |---|---|---|---|---|
  | 1-char | 38 | 0.4 KB – 43,371.7 KB (~42.4 MB) | ~197.2 MB | 12.6 sec |
  | 2-char | 1,248 | 0.2 KB – 18,682.5 KB (~18.2 MB) | ~197.2 MB | 20.2 sec |

- **Prefix length chosen: 2-char.** 1-char produces a few very large files
  (up to ~42 MB — a dominant leading character swallowing a large share of
  parts), which is exactly the "pathologically large partition file" the
  design spec's success criteria warns against. 2-char is far more evenly
  distributed (max ~18 MB, average ~162 KB) at the cost of more files and a
  few extra seconds of generation time.
- **Upload (Task 3):** 1,248 files, ~6 minutes, via drag-and-drop in the
  SharePoint web UI. One transient "render failed" browser error occurred
  mid-upload (page auto-reloaded); all files appeared present afterward by
  visual inspection, but an exact file-count verification against 1,248 is
  still pending before this is treated as fully confirmed.
- **Test library URL:** `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite/Test%20%20Part%20Availability/`
  (site: South Plains Implement - Report Site, library: "Test - Part
  Availability" — note the library's actual URL path segment is
  `Test%20%20Part%20Availability`, a double space, which differs slightly
  from its displayed title).
