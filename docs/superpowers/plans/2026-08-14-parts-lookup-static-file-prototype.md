# Parts Lookup Static-File Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate whether pre-partitioned static JSON files (no live database) can serve `parts-lookup-app`'s exact-match part-number search fast enough to be worth building for real.

**Architecture:** Extract `InMaster_PartsLookup_Raw` from the Lakehouse once via DuckDB/OneLake, partition it into small JSON files keyed by a `PartNumber` prefix, upload the files to a test SharePoint document library, then measure read latency and concurrency behavior directly in the browser.

**Tech Stack:** Python (duckdb, pandas), a browser console JS snippet, manual SharePoint upload (no new infrastructure).

Full context: `docs/superpowers/specs/2026-08-14-parts-lookup-static-file-prototype-design.md`

---

### Task 1: Extract the source data

**Files:**
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/extract.py`
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/.gitignore`
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/README.md`

- [ ] **Step 1: Confirm prerequisites are active**

Run: `fab auth status` and `az account show`
Expected: both show a signed-in identity (matches the pattern already established in `.claude/queries/adhoc/kurt-sales/`). If either fails, run `fab auth login` / `az login` first.

- [ ] **Step 2: Write the extraction script**

```python
"""
PARTS LOOKUP STATIC-FILE PROTOTYPE - EXTRACT
============================================================================
Pulls InMaster_PartsLookup_Raw from the LH_Master_Data lakehouse via DuckDB
over OneLake (delta_scan, Azure CLI credential chain) - a one-time read for
prototype validation, not a recurring job. Same pattern established in
.claude/queries/adhoc/kurt-sales/build_report.py.

Requires `fab auth login` and `az login` to be active before running.

See docs/superpowers/specs/2026-08-14-parts-lookup-static-file-prototype-design.md
for the design this supports.
============================================================================
"""

import time

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"  # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"  # LH_Master_Data lakehouse
BASE = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
OUT_PATH = "partslookup_extract.parquet"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

start = time.time()
df = con.execute(
    f"""
    SELECT
        PartNumber, Branch, Franchise, Description, VendorCode,
        Bin, BinQty, OnOrder, SellPrice1, SuperTo, SuperFrom, Comments
    FROM delta_scan('{BASE}/InMaster_PartsLookup_Raw')
    """
).df()
elapsed = time.time() - start

df.to_parquet(OUT_PATH, index=False)

print(f"Extracted {len(df):,} rows in {elapsed:.1f} sec")
print(f"Saved to {OUT_PATH}")
```

- [ ] **Step 3: Run the extraction**

Run: `cd .claude/queries/adhoc/parts-lookup-static-prototype && pip install duckdb pandas pyarrow && python extract.py`
Expected: prints `Extracted N,NNN,NNN rows in X.X sec` (real row count and timing — this is the first real measurement for the design spec's success criteria) and `Saved to partslookup_extract.parquet`. Confirm the file exists (`ls -la partslookup_extract.parquet` or `dir`).

- [ ] **Step 4: Exclude the generated data from git**

```
*.parquet
output/
```

This is real business data (pricing, bin locations) — only the scripts and written-up findings belong in the repo, not the extract itself.

- [ ] **Step 5: Write the initial README**

```markdown
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

## Results

_(filled in after Tasks 2-5 run — see the design spec's Section 5 success
criteria for what's being measured)_
```

- [ ] **Step 6: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/extract.py .claude/queries/adhoc/parts-lookup-static-prototype/.gitignore .claude/queries/adhoc/parts-lookup-static-prototype/README.md
git commit -m "Add extraction script for parts lookup static-file prototype"
```

---

### Task 2: Partition into prefix-bucketed JSON files

**Files:**
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/partition.py`

- [ ] **Step 1: Write the partitioning script**

```python
"""
PARTS LOOKUP STATIC-FILE PROTOTYPE - PARTITION
============================================================================
Reads the local extract from extract.py and partitions it into one JSON
file per PartNumber-prefix bucket, at both 1-char and 2-char prefix length,
so the two can be compared before picking one (design spec Section 4.2).

Run extract.py first.
============================================================================
"""

import json
import os
import re
import time

import pandas as pd

IN_PATH = "partslookup_extract.parquet"
PREFIX_LENGTHS = [1, 2]

SAFE_CHARS = re.compile(r"[^A-Z0-9]")


def safe_prefix(part_number: str, length: int) -> str:
    prefix = str(part_number).upper()[:length]
    return SAFE_CHARS.sub("_", prefix) or "_EMPTY_"


def partition(df: pd.DataFrame, prefix_len: int, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    df = df.copy()
    df["_prefix"] = df["PartNumber"].apply(lambda p: safe_prefix(p, prefix_len))

    sizes_kb = []
    for prefix, group in df.groupby("_prefix"):
        rows = group.drop(columns="_prefix").to_dict(orient="records")
        file_path = os.path.join(out_dir, f"{prefix}.json")
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
        sizes_kb.append(os.path.getsize(file_path) / 1024)

    print(f"\nPrefix length {prefix_len}: {len(sizes_kb)} files")
    print(f"  smallest: {min(sizes_kb):.1f} KB")
    print(f"  largest:  {max(sizes_kb):.1f} KB")
    print(f"  average:  {sum(sizes_kb) / len(sizes_kb):.1f} KB")
    print(f"  total:    {sum(sizes_kb):.1f} KB")


df = pd.read_parquet(IN_PATH)

for length in PREFIX_LENGTHS:
    start = time.time()
    partition(df, length, out_dir=f"output/{length}char")
    print(f"  generation time: {time.time() - start:.1f} sec")
```

- [ ] **Step 2: Run the partitioning**

Run: `python partition.py`
Expected: prints file count and size distribution (smallest/largest/average/total) plus generation time for both `1char` and `2char`. Both `output/1char/` and `output/2char/` folders now contain `.json` files. Record these numbers — this is the file-count/size-distribution measurement from the design spec's Section 5, and the basis for picking a prefix length in Task 3.

- [ ] **Step 3: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/partition.py
git commit -m "Add partitioning script for parts lookup static-file prototype"
```

---

### Task 3: Upload the chosen partition set to a test SharePoint library

This task is manual (SharePoint UI), not code.

**Files:**
- Modify: `.claude/queries/adhoc/parts-lookup-static-prototype/README.md`

- [ ] **Step 1: Pick a prefix length**

From Task 2's printed output, choose `1char` or `2char` — prefer whichever has a tighter size distribution without either too few huge files or too many tiny ones. If neither is well-balanced, note that in the README (Task 5 will need it for the go/no-go call) and proceed with whichever is closer for now.

- [ ] **Step 2: Create or navigate to a test document library**

In SharePoint, create a new document library in a sandbox site you already have edit access to (not the production Parts site) — e.g. named "Parts Lookup Prototype Test".

- [ ] **Step 3: Upload the files**

Open the chosen `output/1char/` or `output/2char/` folder in File Explorer, select all `.json` files, and drag them into the SharePoint library in the browser. Time the upload with a stopwatch or wall-clock start/end.

- [ ] **Step 4: Record the upload time and library URL**

Add to the README's Results section:
```markdown
## Results

- Extraction: [row count] rows in [X.X] sec (Task 1)
- Partitioning: [file count / size stats for both prefix lengths] (Task 2)
- Prefix length chosen: [1char or 2char], because [reason]
- Upload: [file count] files, [X] min [Y] sec
- Test library URL: [SharePoint URL]
```

- [ ] **Step 5: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/README.md
git commit -m "Record partition choice and upload results"
```

---

### Task 4: Read-latency and concurrency test

**Files:**
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/browser-test.js`

- [ ] **Step 1: Write the browser test script**

```javascript
// PARTS LOOKUP STATIC-FILE PROTOTYPE - READ LATENCY TEST
// ============================================================================
// Paste this into the browser DevTools console while viewing the test
// SharePoint document library folder (so fetch() calls are same-origin and
// carry the browser's existing SharePoint auth session).
//
// Before running: update PREFIX_LEN and TEST_PART_NUMBERS below to match
// the partition scheme chosen in Task 3, and real part numbers known to
// exist in the extracted data (pick a handful spanning different
// prefixes/branches for a representative test).
// ============================================================================

const PREFIX_LEN = 2; // match whichever prefix length was uploaded in Task 3
const TEST_PART_NUMBERS = [
  // fill in 4-6 real part numbers spanning different prefixes, e.g.:
  // "AR51410", "RE12345", "03-3212560",
];

function safePrefix(partNumber, length) {
  return (
    partNumber.toUpperCase().slice(0, length).replace(/[^A-Z0-9]/g, "_") ||
    "_EMPTY_"
  );
}

async function testLookup(partNumber) {
  const prefix = safePrefix(partNumber, PREFIX_LEN);
  const url = `${prefix}.json`;
  const start = performance.now();
  const res = await fetch(url);
  const rows = await res.json();
  const elapsed = performance.now() - start;
  const matches = rows.filter((r) => r.PartNumber === partNumber);
  console.log(
    `${partNumber}: ${elapsed.toFixed(1)}ms, file had ${rows.length} rows, ${matches.length} branch matches`
  );
  return elapsed;
}

async function runSequential() {
  console.log("--- Sequential lookups ---");
  for (const p of TEST_PART_NUMBERS) {
    await testLookup(p);
  }
}

async function runConcurrent(n = 10) {
  console.log(`--- ${n} concurrent lookups (same part repeated) ---`);
  const part = TEST_PART_NUMBERS[0];
  const start = performance.now();
  await Promise.all(Array.from({ length: n }, () => testLookup(part)));
  console.log(
    `Total wall time for ${n} concurrent: ${(performance.now() - start).toFixed(1)}ms`
  );
}

await runSequential();
await runConcurrent(10);
```

- [ ] **Step 2: Fill in real test part numbers**

Open `partslookup_extract.parquet` (e.g. via a quick `pd.read_parquet(...).sample(6)` in a Python shell) or the JSON files directly, and pick 4-6 real `PartNumber` values spanning different prefixes and branches. Replace the empty `TEST_PART_NUMBERS` array in `browser-test.js` with these.

- [ ] **Step 3: Run the test in the browser**

Navigate to the SharePoint library folder from Task 3 in the browser. Open DevTools (F12) → Console. Paste the full contents of `browser-test.js` and press Enter.
Expected: sequential section logs one line per part number with elapsed ms, rows-in-file, and match count; concurrent section logs total wall time for 10 simultaneous fetches. Record both — this is the read-latency and concurrency measurement from the design spec's Section 5.

- [ ] **Step 4: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/browser-test.js
git commit -m "Add browser-based read latency and concurrency test"
```

---

### Task 5: Compare against success criteria and record go/no-go

**Files:**
- Modify: `.claude/queries/adhoc/parts-lookup-static-prototype/README.md`

- [ ] **Step 1: Fill in the comparison table**

Append to the README's Results section, using the actual numbers recorded in Tasks 1-4 against the design spec's Section 5 targets:

```markdown
## Success criteria comparison

| Measurement | Target | Actual | Pass? |
|---|---|---|---|
| Generation time (full extract, both prefix lengths) | small fraction of 15-30 min window | [fill in] | [Y/N] |
| Upload time to SharePoint | fits comfortably alongside generation | [fill in] | [Y/N] |
| Single-lookup read latency | well under 1 second | [fill in] | [Y/N] |
| Concurrent reads (10 simultaneous) | no significant throttling/slowdown | [fill in] | [Y/N] |
| File size distribution | no pathologically large files at chosen prefix length | [fill in] | [Y/N] |

## Conclusion

[GO / NO-GO], because [reasoning]. [If GO: next step is a follow-up design
spec for the real production build. If NO-GO: fall back to whichever of
the Azure PaaS or dedicated-gateway-machine options IT makes available —
see design spec Section 8.]
```

- [ ] **Step 2: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/README.md
git commit -m "Record prototype results and go/no-go conclusion"
```

---

## Self-Review

**Spec coverage:** Section 4.1 (extraction) → Task 1. Section 4.2 (partitioning) → Task 2. Section 4.3/4.4 (file format, script location) → Task 1-2. Section 4.5 (hosting) → Task 3. Section 5 (success criteria) → measured across Tasks 1-4, compared in Task 5. Section 6 (validation plan, 6 steps) → maps directly to Tasks 1-5. All spec sections covered.

**Placeholder scan:** No TBD/TODO in any step. The only intentionally blank content is `TEST_PART_NUMBERS` (filled in Task 4 Step 2, using real data that doesn't exist until Task 1 runs) and the Results/comparison tables (filled in with real measurements as each task runs — this is the expected shape of an empirical validation, not vague instruction).

**Type/naming consistency:** `PartNumber`, `Branch`, `Franchise`, `Description`, `VendorCode`, `Bin`, `BinQty`, `OnOrder`, `SellPrice1`, `SuperTo`, `SuperFrom`, `Comments` — PascalCase throughout `extract.py`, `partition.py`, and `browser-test.js` (matching the Lakehouse's own column names, not the camelCase the eventual production app would use — that mapping is explicitly out of scope per the design spec). `safe_prefix()`/`safePrefix()` logic (uppercase, first N chars, non-alphanumeric → `_`) is identical between `partition.py` (Python) and `browser-test.js` (JS) — necessary since the browser test must compute the same filenames the partition script generated.
