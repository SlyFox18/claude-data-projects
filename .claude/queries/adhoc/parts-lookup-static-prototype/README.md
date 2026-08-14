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
  mid-upload (page auto-reloaded) and genuinely did drop files — a Ctrl+A
  count afterward showed only 1,239 of 1,248. A second drag-and-drop pass
  ("Replace all" on the conflict prompt — safe here since the re-uploaded
  content is identical, and it also uploads the missing files with no
  conflict) closed the gap; confirmed all 1,248 present afterward.
- **Test library URL:** `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite/Test%20%20Part%20Availability/`
  (site: South Plains Implement - Report Site, library: "Test - Part
  Availability" — note the library's actual URL path segment is
  `Test%20%20Part%20Availability`, a double space, which differs slightly
  from its displayed title).
- **Read latency (Task 4), sequential lookups of 6 real part numbers:**

  | Part number | Prefix | File size (rows) | Elapsed |
  |---|---|---|---|
  | SE501403 | SE | 11,551 | 254ms |
  | JDE80 | JD | 20,168 | 276ms |
  | 19M7775 | 19 | 21,641 | 228ms |
  | AN220364 | AN | 29,046 | 288ms |
  | R127764 | R1 | 36,727 | 361ms |
  | RE568839 | RE | **97,654** | **1,014ms** |

  Five of six land 228-361ms, comfortably under the "well under 1 second"
  target. `RE568839`'s file is an outlier — nearly 3x the rows of the
  next-largest and by far the biggest partition file on disk (~18.2 MB,
  the same file already flagged as the largest at the partitioning stage).
  Latency scales with file size as expected; this specific bucket crosses
  the 1-second mark.
- **Concurrency (Task 4), 10 simultaneous fetches of `RE568839`'s file
  (deliberately the largest/worst-case file, to stress-test):** 10/10
  succeeded, 1,354.2ms total wall time. Individual elapsed times show a
  queuing pattern — the first 4 finished in 170-542ms, the last 6 clustered
  at 1,265-1,350ms — consistent with the browser's own per-origin
  connection cap (commonly ~6 simultaneous connections per domain) rather
  than necessarily a SharePoint-side throttle. Note this test is harsher
  than real production usage: it's one browser repeatedly hitting one file,
  where real usage is ~70 independent browsers each making one request,
  spread across time, each with its own connection pool — so this result
  likely overstates real-world contention rather than understating it.

## Success criteria comparison

| Measurement | Target | Actual | Pass? |
|---|---|---|---|
| Generation time (full extract, both prefix lengths) | small fraction of 15-30 min window | 12.6-20.2 sec | ✅ Y |
| Upload time to SharePoint | fits comfortably alongside generation | ~6 min (plus a short second pass to close a gap caused by a transient browser error, unrelated to file count/size) | ✅ Y |
| Single-lookup read latency | well under 1 second | 228-361ms for 5 of 6 test lookups; 1,014ms for the largest partition file (`RE`) | ⚠️ Mostly — one identified outlier |
| Concurrent reads (10 simultaneous) | no significant throttling/slowdown | 10/10 succeeded; visible queuing on the largest file under single-browser same-origin load, likely browser connection-pool behavior rather than SharePoint throttling; not representative of real multi-user usage | ⚠️ Qualified pass — real-world pattern likely easier than this test |
| File size distribution | no pathologically large partition files at chosen prefix length | 2-char: 0.2 KB-18.2 MB range, most files well under 200 KB; the one ~18 MB file is a real, now-measured outlier | ⚠️ One confirmed outlier bucket |

## Conclusion

**GO, with one specific follow-up before a production build.** The core idea
is validated: typical lookups are fast (228-361ms, well within target),
generation and upload both comfortably fit inside the 15-30 min refresh
window, and the approach requires no live database, no server, and no
Fabric/Azure capacity at all. The one real, measured weakness is the
largest partition bucket (`RE`, ~97K rows / ~18.2 MB) crossing the 1-second
mark — not catastrophic, but not "well under" either. Before a production
build, this should be addressed directly: either a finer-grained scheme for
the handful of high-volume prefixes specifically (e.g. 3-char partitioning
only for buckets that exceed some size threshold, while leaving small
buckets at 2-char), or a deliberate decision that ~1 second is an
acceptable worst case for the least-common searches. Next step: a follow-up
design spec for the real production build (Rayfin/React frontend
integration, production refresh scheduling, decommissioning the current
Fabric App) — see design spec Section 8 for the fallback options (Azure
PaaS, dedicated gateway machine) if that build ever stalls.
