# Associated Parts / Recommended Parts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new "Associated Parts" report that shows, for any selected part, which other parts customers most reliably buy alongside it (Part×Part market-basket association across all sales — counter and service work order alike).

**Architecture:** A weekly Fabric Notebook (DuckDB compute, Spark read/write) aggregates 24 months of `InTrans_Incremental` into a new Lakehouse Delta table `Fact_PartAssociation` (raw co-occurrence counts, Franchise-aware grain). A new semantic model computes Confidence/Baseline/Lift from those raw counts via DAX, using two local role-playing copies of `dim_Parts` (selected vs. recommended) so the shared dimension is untouched. A new single-page report lets a user pick a part and see its ranked associated parts.

**Tech Stack:** DuckDB (Python, local prototyping + in-notebook compute), PySpark (Fabric Notebook read/write), TMDL (semantic model), PBIR via `pbir` CLI (report), Power Query M (semantic model partitions via SQL Analytics Endpoint).

**Spec:** `docs/superpowers/specs/2026-08-27-associated-parts-design.md`

---

## Before You Start

- This plan assumes `az login` is already authenticated as a user with read access to the `LH_Master_Data` lakehouse (confirmed working during brainstorming: `az account show` returned `bfox@spitractor.com`). If a fresh environment fails Task 1's check, run `az login` interactively first — this plan can't do that for you.
- `duckdb` (pip package) is already installed in this environment (`v1.5.5` confirmed). If missing elsewhere: `pip install duckdb`.
- Lakehouse identifiers (reused from the existing `Fact_JobCodePartFrequency.pq` header — same lakehouse every fact table in this repo reads from):
  - Workspace ID: `b48cdb35-7ce3-46de-96df-d70db77649cb`
  - Lakehouse ID: `3e74497b-8c51-4a1a-91a1-888c59118f48`
  - SQL Analytics Endpoint host: `xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com`, database `LH_Master_Data`
- **Verified during planning:** `pbir new report` requires the target semantic model to already be published and visible in the named Fabric workspace — it rejects local-only models with `Semantic model 'X' not found in workspace 'Y'`. This is why Task 9 (report creation) is sequenced *after* Brian publishes the semantic model from Desktop, not before. Don't attempt to reorder this.

---

### Task 1: Verify local data-access prerequisites

**Files:** none (verification only)

- [ ] **Step 1: Confirm Azure CLI auth**

Run: `az account show`
Expected: JSON output showing `"user": {"name": "bfox@spitractor.com", ...}`. If this fails, stop and run `az login` interactively before continuing — no later step in this plan can substitute for this.

- [ ] **Step 2: Confirm DuckDB is importable and can load the delta/azure extensions**

Run:
```bash
python3 -c "
import duckdb
con = duckdb.connect()
con.execute(\"INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;\")
con.execute(\"CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');\")
print('OK')
"
```
Expected: prints `OK` with no errors.

- [ ] **Step 3: Confirm read access to `InTrans_Incremental` via OneLake**

Run:
```bash
python3 -c "
import duckdb
WS_ID = 'b48cdb35-7ce3-46de-96df-d70db77649cb'
LH_ID = '3e74497b-8c51-4a1a-91a1-888c59118f48'
base = f'abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables'
con = duckdb.connect()
con.execute(\"INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;\")
con.execute(\"CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');\")
row = con.execute(f\"SELECT COUNT(*) FROM delta_scan('{base}/InTrans_Incremental')\").fetchone()
print(f'InTrans_Incremental row count: {row[0]:,}')
"
```
Expected: prints a row count in the millions (no connection/permission error). This confirms Task 2 and 3 can run.

---

### Task 2: Profile invoice basket sizes and set the basket-size cap

**Files:**
- Create: `.claude/queries/adhoc/associated-parts-profiling/profile_basket_sizes.py`

- [x] **Step 1: Write the profiling script**

```python
"""
Associated Parts — basket size profiling (2026-08-27)
Determines the distinct-parts-per-invoice distribution in InTrans_Incremental
over the last 24 months, so a data-driven basket-size cap can be chosen
before building Fact_PartAssociation. See:
docs/superpowers/specs/2026-08-27-associated-parts-design.md
"""
import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

result = con.execute(f"""
    WITH baskets AS (
        SELECT Franchise, Branch, RONumber, COUNT(DISTINCT PartNumber) AS DistinctParts
        FROM delta_scan('{base}/InTrans_Incremental')
        WHERE Type = 'I' AND Qty > 0
          AND TransDatetime >= CURRENT_DATE - INTERVAL 24 MONTH
          AND PartNumber IS NOT NULL AND PartNumber <> ''
        GROUP BY Franchise, Branch, RONumber
    )
    SELECT
        COUNT(*)                                   AS TotalBaskets,
        MIN(DistinctParts)                         AS MinParts,
        approx_quantile(DistinctParts, 0.50)       AS P50,
        approx_quantile(DistinctParts, 0.90)       AS P90,
        approx_quantile(DistinctParts, 0.95)       AS P95,
        approx_quantile(DistinctParts, 0.99)       AS P99,
        MAX(DistinctParts)                         AS MaxParts
    FROM baskets
""").df()

print(result.to_string(index=False))
```

- [x] **Step 2: Run it and record the output**

Run: `python3 .claude/queries/adhoc/associated-parts-profiling/profile_basket_sizes.py`
Expected: one row of summary stats (TotalBaskets, MinParts, P50/P90/P95/P99, MaxParts). Record these numbers — they're the input to Step 3.

**Recorded output (run 2026-08-27, live `InTrans_Incremental`, 12,186,352 total rows in the table):**

| TotalBaskets | MinParts | P50 | P90 | P95 | P99 | MaxParts |
|---|---|---|---|---|---|---|
| 447,661 | 1 | 1 | 5 | 8 | 24 | 377 |

- [x] **Step 3: Set `BASKET_CAP`**

Set `BASKET_CAP = <P99 value from Step 2, rounded up to the nearest 5>`. This excludes the top ~1% of invoices by distinct-part count (the "big shop order" outliers the design doc flags) while keeping the overwhelming majority of real baskets intact. Write this exact value down — it's a literal constant in Task 3 and Task 4, not a placeholder to fill in later.

**Decided: `BASKET_CAP = 25`** (P99 = 24, rounded up to the nearest 5 = 25).

- [x] **Step 4: Commit the profiling script**

```bash
git add ".claude/queries/adhoc/associated-parts-profiling/profile_basket_sizes.py"
git commit -m "Add basket-size profiling script for Associated Parts report

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Validate the Part×Part aggregation logic, then finalize thresholds

**Files:**
- Create: `.claude/queries/adhoc/associated-parts-profiling/validate_association_logic.py`

- [x] **Step 1: Write the synthetic worked-example test (expected values known up front)**

```python
"""
Associated Parts — aggregation logic validation (2026-08-27)
Part 1: a synthetic 4-invoice basket set with hand-computed expected output,
to catch logic bugs before trusting the real-data run in Part 2.
Part 2: runs the same SQL against real InTrans_Incremental (capped/thresholded
per Task 2's BASKET_CAP), to finalize MIN_COOCCURRENCE and preview row count.
"""
import duckdb

ASSOCIATION_SQL = """
    WITH baskets AS (
        SELECT Franchise, Branch, RONumber, PartNumber
        FROM {source}
        GROUP BY Franchise, Branch, RONumber, PartNumber
    ),
    basket_sizes AS (
        SELECT Franchise, Branch, RONumber, COUNT(*) AS DistinctParts
        FROM baskets GROUP BY Franchise, Branch, RONumber
    ),
    capped_baskets AS (
        SELECT b.*
        FROM baskets b
        INNER JOIN basket_sizes s
          ON b.Franchise = s.Franchise AND b.Branch = s.Branch AND b.RONumber = s.RONumber
        WHERE s.DistinctParts <= {basket_cap}
    ),
    pairs AS (
        SELECT a.Franchise, a.PartNumber AS PartA, b.PartNumber AS PartB
        FROM capped_baskets a
        INNER JOIN capped_baskets b
          ON a.Franchise = b.Franchise AND a.Branch = b.Branch AND a.RONumber = b.RONumber
         AND a.PartNumber <> b.PartNumber
    ),
    co_occurrence AS (
        SELECT Franchise, PartA, PartB, COUNT(*) AS CoOccurrenceCount
        FROM pairs GROUP BY Franchise, PartA, PartB
    ),
    part_totals AS (
        SELECT Franchise, PartNumber, COUNT(*) AS InvoiceCount
        FROM capped_baskets GROUP BY Franchise, PartNumber
    ),
    total_invoices AS (
        SELECT Franchise, COUNT(*) AS TotalInvoiceCount
        FROM basket_sizes GROUP BY Franchise
    )
    SELECT
        c.Franchise, c.PartA, c.PartB, c.CoOccurrenceCount,
        ta.InvoiceCount AS AnchorInvoiceCount,
        tb.InvoiceCount AS AssociatedInvoiceCount,
        ti.TotalInvoiceCount
    FROM co_occurrence c
    INNER JOIN part_totals ta ON ta.Franchise = c.Franchise AND ta.PartNumber = c.PartA
    INNER JOIN part_totals tb ON tb.Franchise = c.Franchise AND tb.PartNumber = c.PartB
    INNER JOIN total_invoices ti ON ti.Franchise = c.Franchise
    WHERE c.CoOccurrenceCount >= {min_cooccurrence}
    ORDER BY c.Franchise, c.PartA, c.PartB
"""

con = duckdb.connect()

# ---- Part 1: synthetic worked example -----------------------------------
# 4 invoices, franchise D, branch 1:
#   INV1: A, B      INV2: A, B      INV3: A, C      INV4: A
# Expected (min_cooccurrence=1, basket_cap=10):
#   A->B: CoOccurrence=2, AnchorInvoiceCount(A)=4, AssociatedInvoiceCount(B)=2 => Confidence=50%
#   B->A: CoOccurrence=2, AnchorInvoiceCount(B)=2, AssociatedInvoiceCount(A)=4 => Confidence=100%
#   A->C: CoOccurrence=1, AnchorInvoiceCount(A)=4, AssociatedInvoiceCount(C)=1 => Confidence=25%
#   C->A: CoOccurrence=1, AnchorInvoiceCount(C)=1, AssociatedInvoiceCount(A)=4 => Confidence=100%
con.execute("""
    CREATE OR REPLACE TABLE test_baskets AS
    SELECT * FROM (VALUES
        ('D','1','INV1','A'), ('D','1','INV1','B'),
        ('D','1','INV2','A'), ('D','1','INV2','B'),
        ('D','1','INV3','A'), ('D','1','INV3','C'),
        ('D','1','INV4','A')
    ) AS t(Franchise, Branch, RONumber, PartNumber)
""")

test_result = con.execute(
    ASSOCIATION_SQL.format(source="test_baskets", basket_cap=10, min_cooccurrence=1)
).df()
print("=== Synthetic test result ===")
print(test_result.to_string(index=False))

expected_pairs = {
    ("D", "A", "B"): (2, 4, 2, 4),
    ("D", "B", "A"): (2, 2, 4, 4),
    ("D", "A", "C"): (1, 4, 1, 4),
    ("D", "C", "A"): (1, 1, 4, 4),
}
actual = {
    (r.Franchise, r.PartA, r.PartB): (r.CoOccurrenceCount, r.AnchorInvoiceCount, r.AssociatedInvoiceCount, r.TotalInvoiceCount)
    for r in test_result.itertuples()
}
assert actual == expected_pairs, f"MISMATCH!\nExpected: {expected_pairs}\nActual: {actual}"
print("Synthetic test PASSED — aggregation logic is correct.\n")

# ---- Part 2: real data, capped, preview row counts at a few thresholds --
WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

BASKET_CAP = 25  # Task 2's determined value (P99=24, rounded up to nearest 5)

filtered_source = f"""(
    SELECT Franchise, Branch, RONumber, PartNumber
    FROM delta_scan('{base}/InTrans_Incremental')
    WHERE Type = 'I' AND Qty > 0
      AND TransDatetime >= CURRENT_DATE - INTERVAL 24 MONTH
      AND PartNumber IS NOT NULL AND PartNumber <> ''
)"""

for min_cooc in (3, 5, 10):
    real_result = con.execute(
        ASSOCIATION_SQL.format(source=filtered_source, basket_cap=BASKET_CAP, min_cooccurrence=min_cooc)
    ).df()
    print(f"MIN_COOCCURRENCE={min_cooc}: {len(real_result):,} rows in Fact_PartAssociation")

print("\nPick MIN_COOCCURRENCE for a row count that's usefully small (tens of\n"
      "thousands, not millions) while still covering real parts. Spot-check a\n"
      "few PartA values you recognize against the live report/business knowledge\n"
      "before finalizing.")
```

- [x] **Step 2: Replace `BASKET_CAP = 999` with the real value from Task 2**

Edit the script: set `BASKET_CAP` to the literal integer decided in Task 2, Step 3. (Already done above — `BASKET_CAP = 25`.)

- [x] **Step 3: Run the validation script**

Run: `python3 .claude/queries/adhoc/associated-parts-profiling/validate_association_logic.py`
Expected: `Synthetic test PASSED — aggregation logic is correct.` printed, followed by three row-count lines (one per `MIN_COOCCURRENCE` candidate). If the assertion fails, the aggregation SQL has a bug — fix it before proceeding to real data.

**Synthetic test: PASSED** (run 2026-08-27) — all four expected pairs
((D,A,B), (D,B,A), (D,A,C), (D,C,A)) matched hand-computed values exactly
on the first attempt. `ASSOCIATION_SQL` required no logic changes.

**Real-data run — hit a real resource error first, root-caused and fixed
(not a logic bug):** The first attempt threw
`_duckdb.OutOfMemoryException: ... max_temp_directory_size exceeded`
(claimed 45.9 GiB temp-spill cap, on a host with 185 GB free disk and
31.6 GB RAM) on the very first threshold iteration. A diagnostic pass
(materializing each intermediate CTE — `filtered_intrans`,
`baskets`, `basket_sizes`, `capped_baskets` — as physical DuckDB tables
one at a time) showed the actual filtered data is small: 1,290,947 raw
rows → 447,661 baskets (matches Task 2's profiling exactly) →
1,031,637 capped-basket rows → an estimated ~4.8M pairs. None of that
should need 46 GB of spill. Root cause: `ASSOCIATION_SQL`'s CTEs
(`baskets`, `capped_baskets`) reference `{source}` — and `capped_baskets`
is self-joined against itself in the `pairs` step — so when `{source}`
is a live `delta_scan(...)`-backed remote subquery, DuckDB's planner
re-inlines and re-evaluates that remote OneLake scan on every reference
instead of computing it once, multiplying the effective I/O and spill
many times over even though the final data volume is tiny. Fix applied
(query-planning only, `ASSOCIATION_SQL` itself untouched from the
validated version): materialize the filtered extract into a local
DuckDB table (`filtered_intrans`) once via `CREATE TABLE AS SELECT ...`,
then pass `source="filtered_intrans"` into `ASSOCIATION_SQL` instead of
the raw subquery text. Added `PRAGMA memory_limit='10GB'` and
`SET max_temp_directory_size='150GiB'` as a belt-and-suspenders safety
margin on top of that fix. Rerun succeeded cleanly with no further
errors.

**Recorded real-data row counts (run 2026-08-27, `InTrans_Incremental`,
last 24 months, `BASKET_CAP = 25`, source: locally-materialized
`filtered_intrans` = 1,290,947 rows / 447,661 baskets):**

| MIN_COOCCURRENCE | Fact_PartAssociation row count |
|---|---|
| 3 | 229,452 |
| 5 | 108,338 |
| 10 | 44,326 |

- [x] **Step 4: Set `MIN_COOCCURRENCE`**

Pick the value from Step 3's three candidates whose row count looks right per the script's own guidance (tens of thousands, not millions). Write this exact integer down — it's a literal constant in Task 4.

**Decided: `MIN_COOCCURRENCE = 10`** (44,326 rows). Of the three
candidates, only 10 lands in the "tens of thousands" range the script's
own guidance calls for — 3 and 5 are both still in the hundreds of
thousands (229,452 and 108,338 respectively), too large to be a useful
curated recommendation list. Requiring at least 10 invoices to have
carried both parts together (out of 447,661 qualifying invoices) is
also a defensible real-world confidence bar — a pair that only
co-occurred once or twice in two years of sales is noise, not a
reliable recommendation. Business-side spot-checking of specific
PartA/PartB pairs against known-good pairings is still recommended
before this ships (per the script's own printed guidance) but is
deferred to Task 9 (manual/Brian) since it requires domain knowledge
this session doesn't have.

- [x] **Step 5: Commit the validation script**

```bash
git add ".claude/queries/adhoc/associated-parts-profiling/validate_association_logic.py"
git commit -m "Validate Fact_PartAssociation aggregation logic against synthetic and real data

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Write the production Fabric Notebook

**Files:**
- Create: `projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb`

- [ ] **Step 1: Write the notebook JSON**

This runs *inside* Fabric (not locally) — it uses the notebook's attached default lakehouse (`LH_Master_Data`) via native Spark, which needs no OneLake/az-login workaround. DuckDB still does the actual pairwise aggregation (per the design's engine choice), it just receives its input as an in-memory pandas frame instead of via `delta_scan` over abfss. The final write uses `.save("Tables/Fact_PartAssociation")` (path-based, **not** `saveAsTable()`) specifically to avoid the documented Fabric lowercase-table-name gotcha.

```python
import json

BASKET_CAP = 999          # <-- replace with Task 2's value
MIN_COOCCURRENCE = 5      # <-- replace with Task 3's value

notebook = {
    "nbformat": 4,
    "nbformat_minor": 5,
    "metadata": {
        "language_info": {"name": "python"}
    },
    "cells": [
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": [
                "# Fact_PartAssociation Build\n",
                "\n",
                "Part×Part market-basket association, computed weekly (off the daily\n",
                "critical path). See `docs/superpowers/specs/2026-08-27-associated-parts-design.md`\n",
                "and `docs/superpowers/plans/2026-08-27-associated-parts-recommended-parts.md`\n",
                "for the full design and validation history.\n",
                "\n",
                "Reads `InTrans_Incremental` via native Spark (this notebook's attached\n",
                "default lakehouse), does the actual pairwise aggregation in DuckDB\n",
                "(same engine already proven safe for this shape of self-join elsewhere\n",
                f"in this repo), and writes back via `.save(\"Tables/...\")` (not\n",
                "`saveAsTable()`) to preserve PascalCase in the stored Delta table name."
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "%pip install duckdb"
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "import duckdb\n",
                "\n",
                f"BASKET_CAP = {BASKET_CAP}\n",
                f"MIN_COOCCURRENCE = {MIN_COOCCURRENCE}\n",
                "\n",
                "# Native Spark read of the attached lakehouse — no OneLake/az-login\n",
                "# workaround needed inside a Fabric notebook.\n",
                "intrans_df = spark.sql(\"\"\"\n",
                "    SELECT Franchise, Branch, RONumber, PartNumber\n",
                "    FROM InTrans_Incremental\n",
                "    WHERE Type = 'I' AND Qty > 0\n",
                "      AND TransDatetime >= date_sub(current_date(), 730)\n",
                "      AND PartNumber IS NOT NULL AND PartNumber <> ''\n",
                "\"\"\")\n",
                "intrans_pdf = intrans_df.toPandas()\n",
                "print(f\"Filtered InTrans rows pulled into pandas: {len(intrans_pdf):,}\")"
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "con = duckdb.connect()\n",
                "con.register(\"intrans\", intrans_pdf)\n",
                "\n",
                "result_pdf = con.execute(f\"\"\"\n",
                "    WITH baskets AS (\n",
                "        SELECT Franchise, Branch, RONumber, PartNumber\n",
                "        FROM intrans\n",
                "        GROUP BY Franchise, Branch, RONumber, PartNumber\n",
                "    ),\n",
                "    basket_sizes AS (\n",
                "        SELECT Franchise, Branch, RONumber, COUNT(*) AS DistinctParts\n",
                "        FROM baskets GROUP BY Franchise, Branch, RONumber\n",
                "    ),\n",
                "    capped_baskets AS (\n",
                "        SELECT b.*\n",
                "        FROM baskets b\n",
                "        INNER JOIN basket_sizes s\n",
                "          ON b.Franchise = s.Franchise AND b.Branch = s.Branch AND b.RONumber = s.RONumber\n",
                "        WHERE s.DistinctParts <= {BASKET_CAP}\n",
                "    ),\n",
                "    pairs AS (\n",
                "        SELECT a.Franchise, a.PartNumber AS PartA, b.PartNumber AS PartB\n",
                "        FROM capped_baskets a\n",
                "        INNER JOIN capped_baskets b\n",
                "          ON a.Franchise = b.Franchise AND a.Branch = b.Branch AND a.RONumber = b.RONumber\n",
                "         AND a.PartNumber <> b.PartNumber\n",
                "    ),\n",
                "    co_occurrence AS (\n",
                "        SELECT Franchise, PartA, PartB, COUNT(*) AS CoOccurrenceCount\n",
                "        FROM pairs GROUP BY Franchise, PartA, PartB\n",
                "    ),\n",
                "    part_totals AS (\n",
                "        SELECT Franchise, PartNumber, COUNT(*) AS InvoiceCount\n",
                "        FROM capped_baskets GROUP BY Franchise, PartNumber\n",
                "    ),\n",
                "    total_invoices AS (\n",
                "        SELECT Franchise, COUNT(*) AS TotalInvoiceCount\n",
                "        FROM basket_sizes GROUP BY Franchise\n",
                "    )\n",
                "    SELECT\n",
                "        c.Franchise, c.PartA, c.PartB, c.CoOccurrenceCount,\n",
                "        ta.InvoiceCount AS AnchorInvoiceCount,\n",
                "        tb.InvoiceCount AS AssociatedInvoiceCount,\n",
                "        ti.TotalInvoiceCount\n",
                "    FROM co_occurrence c\n",
                "    INNER JOIN part_totals ta ON ta.Franchise = c.Franchise AND ta.PartNumber = c.PartA\n",
                "    INNER JOIN part_totals tb ON tb.Franchise = c.Franchise AND tb.PartNumber = c.PartB\n",
                "    INNER JOIN total_invoices ti ON ti.Franchise = c.Franchise\n",
                "    WHERE c.CoOccurrenceCount >= {MIN_COOCCURRENCE}\n",
                "\"\"\").df()\n",
                "\n",
                "print(f\"Fact_PartAssociation rows: {len(result_pdf):,}\")"
            ]
        },
        {
            "cell_type": "code",
            "metadata": {},
            "execution_count": None,
            "outputs": [],
            "source": [
                "result_df = spark.createDataFrame(result_pdf)\n",
                "\n",
                "# .save(\"Tables/...\") — NOT saveAsTable() — preserves PascalCase.\n",
                "# saveAsTable() lowercases the stored Delta table name in the Hive\n",
                "# metastore, which breaks the semantic model's exact-case SQL Analytics\n",
                "# Endpoint lookup (documented gotcha, confirmed twice previously in this repo).\n",
                "result_df.write.format(\"delta\").mode(\"overwrite\").save(\"Tables/Fact_PartAssociation\")\n",
                "print(\"Wrote Fact_PartAssociation.\")"
            ]
        }
    ]
}

with open("projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb", "w", encoding="utf-8") as f:
    json.dump(notebook, f, indent=1)

print("Notebook written.")
```

Run this as a one-off Python script (not committed itself — it's just the file generator) to produce the `.ipynb` file, then discard it.

- [ ] **Step 2: Verify the notebook JSON is well-formed**

Run:
```bash
python3 -c "
import json
with open('projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb', encoding='utf-8') as f:
    nb = json.load(f)
print(f'{len(nb[\"cells\"])} cells, nbformat {nb[\"nbformat\"]}')
"
```
Expected: `5 cells, nbformat 4` with no JSON parse error.

- [ ] **Step 3: Commit the notebook**

```bash
git add "projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb"
git commit -m "Add Fact_PartAssociation Fabric Notebook (DuckDB compute, Spark I/O)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

**Note for Task 9:** this notebook file is not yet a live Fabric item — it still needs to be created as a Notebook in the `LH_Master_Data` workspace and its content pasted in (Fabric doesn't currently git-sync notebook *content* from `data-projects`, only from `fabric-workspace-docs` — same two-repo distinction as everything else in this CLAUDE.md). That step is in Task 9's checklist.

---

### Task 5: Scaffold the project folder and update the query library

**Files:**
- Create: `projects/associated parts - report/CLAUDE.md`
- Create: `.claude/queries/facts/Fact_PartAssociation.md`
- Modify: `.claude/queries/facts/FACT-TABLES-SUMMARY.md`

- [ ] **Step 1: Create the project folder structure**

```bash
mkdir -p "projects/associated parts - report/queries/fact-tables"
mkdir -p "projects/associated parts - report/documentation"
```

- [ ] **Step 2: Write the query-library documentation for the new fact table**

This mirrors the header-comment convention used by every `.pq` file in `.claude/queries/`, but documents a notebook instead (no `.pq` file exists for this one — it's Spark/DuckDB, not Power Query).

```markdown
# Fact_PartAssociation

**Notebook:** `projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb`
**Fabric item:** Notebook in `LH_Master_Data` workspace (create per Task 9 checklist)
**Output:** Lakehouse Delta table `Fact_PartAssociation`

## Purpose

Part×Part market-basket association. For each Franchise × PartA × PartB,
how often do invoices containing PartA also contain PartB — across **all**
sales activity (counter sales and service work order parts alike), not
scoped to a Job Code the way `Fact_JobCodePartFrequency` is.

## Grain

One row per `(Franchise, PartA, PartB)`, directional (PartA→PartB is a
separate row from PartB→PartA).

## Source & Filters

- Source: `InTrans_Incremental` (Lakehouse), last 24 months
- `Type = 'I'` (invoiced sales only), `Qty > 0`
- Basket = one invoice: `(Franchise, Branch, RONumber)`
- Basket-size cap: `<BASKET_CAP value from Task 2>` distinct parts (excludes
  the top ~1% of invoices by distinct-part count — large shop orders/bulk
  counter sales that would otherwise dominate the pair counts without
  reflecting a genuine "these go together" pairing)
- Minimum `CoOccurrenceCount`: `<MIN_COOCCURRENCE value from Task 3>` (drops
  one-off noise pairs)

## Output Columns

| Column | Type | Meaning |
|---|---|---|
| `Franchise` | text | Franchise the counts are scoped to |
| `PartA` | text | Anchor part |
| `PartB` | text | Associated/recommended part |
| `CoOccurrenceCount` | int | Invoices (this franchise) containing both A and B |
| `AnchorInvoiceCount` | int | Invoices (this franchise) containing A |
| `AssociatedInvoiceCount` | int | Invoices (this franchise) containing B |
| `TotalInvoiceCount` | int | Total qualifying invoices (this franchise) |

Raw counts, not pre-computed percentages — deliberate, so the semantic
model can produce both a franchise-specific view and a true company-wide
rollup (sum counts, then divide) from one table, and so Lift can be
computed at all. See design doc for full rationale.

## Refresh

Weekly (Tier-3-style cadence, off the daily 4:15 AM orchestrator). Set up
per Task 9's checklist — not yet wired into any pipeline as of this
writing.

## Related

- Precedent: `Fact_JobCodePartFrequency` / `Fact_JobCodePartFrequency_Branch`
  (Inspections report) — same invoice-as-basket join convention, but
  JobCode×Part instead of Part×Part, and pre-computed percentages instead
  of raw counts.
- Full design: `docs/superpowers/specs/2026-08-27-associated-parts-design.md`
```

- [ ] **Step 3: Add a summary line to FACT-TABLES-SUMMARY.md**

Add this row under the closest existing table-listing section (the file is
acknowledged stale elsewhere in it, so match whatever section header
convention is already there rather than inventing a new one):

```
Fact_PartAssociation — Associated Parts report — Franchise×PartA×PartB market-basket
association, weekly refresh, Fabric Notebook (DuckDB+Spark), see
.claude/queries/facts/Fact_PartAssociation.md
```

- [ ] **Step 4: Commit**

```bash
git add "projects/associated parts - report/queries/fact-tables" \
        "projects/associated parts - report/documentation" \
        ".claude/queries/facts/Fact_PartAssociation.md" \
        ".claude/queries/facts/FACT-TABLES-SUMMARY.md"
git commit -m "Document Fact_PartAssociation in the shared query library

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Generate the semantic model TMDL scaffold

**Files:**
- Create: `projects/associated parts - report/reports/current/Associated Parts.pbip`
- Create: `projects/associated parts - report/reports/current/Associated Parts.SemanticModel/.platform`
- Create: `.../Associated Parts.SemanticModel/definition.pbism`
- Create: `.../Associated Parts.SemanticModel/diagramLayout.json`
- Create: `.../Associated Parts.SemanticModel/definition/database.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/model.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/relationships.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/cultures/en-US.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/tables/Fact_PartAssociation.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/tables/dim_Parts_Selected.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/tables/dim_Parts_Recommended.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/tables/dim_Franchise.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/tables/Data Refresh.tmdl`
- Create: `.../Associated Parts.SemanticModel/definition/tables/MeasuresTable.tmdl`

**Reminders from this repo's own CLAUDE.md (real, previously-confirmed gotchas — check for these in Step 2):**
- TMDL does **not** support `//` comments anywhere — not even inside doc text.
- Object descriptions use a `///` line immediately before the declaration, never a `description:` property.
- TMDL files must be UTF-8 **without BOM**.

- [ ] **Step 1: Write and run the generator script**

```python
"""
One-shot generator for the Associated Parts semantic model TMDL scaffold.
Run once; do not re-run after Desktop has opened/edited these files (it will
overwrite hand/Desktop edits with fresh lineageTags).
"""
import json
import uuid
from pathlib import Path

ROOT = Path("projects/associated parts - report/reports/current")
MODEL_DIR = ROOT / "Associated Parts.SemanticModel"
DEF_DIR = MODEL_DIR / "definition"
TABLES_DIR = DEF_DIR / "tables"
TABLES_DIR.mkdir(parents=True, exist_ok=True)
(DEF_DIR / "cultures").mkdir(parents=True, exist_ok=True)

SQL_SERVER = "xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com"
SQL_DB = "LH_Master_Data"

def tag():
    return str(uuid.uuid4())

def write_utf8_no_bom(path: Path, content: str):
    path.write_bytes(content.encode("utf-8"))

def sql_partition(table_name: str, source_item: str, select_columns=None, rename_map=None) -> str:
    steps = [f'Source = Sql.Database("{SQL_SERVER}", "{SQL_DB}"),']
    var = f"dbo_{source_item}"
    steps.append(f'{var} = Source{{[Schema="dbo",Item="{source_item}"]}}[Data]')
    body_var = var
    extra_lines = []
    if select_columns:
        cols = ", ".join(f'"{c}"' for c in select_columns)
        extra_lines.append(f"Selected = Table.SelectColumns({body_var}, {{{cols}}})")
        body_var = "Selected"
    if rename_map:
        pairs = ", ".join(f'{{"{k}", "{v}"}}' for k, v in rename_map.items())
        extra_lines.append(f"Renamed = Table.RenameColumns({body_var}, {{{pairs}}})")
        body_var = "Renamed"
    lines = [f"    let", f"        {steps[0]}"]
    lines.append(f"        {steps[1]}" + ("," if extra_lines else ""))
    for i, line in enumerate(extra_lines):
        suffix = "," if i < len(extra_lines) - 1 else ""
        lines.append(f"        {line}{suffix}")
    lines.append(f"    in")
    lines.append(f"        {body_var}")
    return "\n".join(lines)

def column_block(name, dtype, summarize="none", hidden=False, format_string=None, source_column=None):
    lines = [f"\tcolumn {name}"]
    lines.append(f"\t\tdataType: {dtype}")
    if hidden:
        lines.append("\t\tisHidden")
    if format_string:
        lines.append(f"\t\tformatString: {format_string}")
    lines.append(f"\t\tlineageTag: {tag()}")
    lines.append(f"\t\tsummarizeBy: {summarize}")
    lines.append(f"\t\tsourceColumn: {source_column or name}")
    lines.append("")
    if hidden:
        lines.append("\t\tchangedProperty = IsHidden")
        lines.append("")
    lines.append("\t\tannotation SummarizationSetBy = Automatic")
    lines.append("")
    return "\n".join(lines)

# ---------------------------------------------------------------------
# Fact_PartAssociation
# ---------------------------------------------------------------------
fact_cols = (
    column_block("Franchise", "string")
    + column_block("PartA", "string")
    + column_block("PartB", "string")
    + column_block("CoOccurrenceCount", "int64", summarize="sum", format_string="0")
    + column_block("AnchorInvoiceCount", "int64", summarize="sum", format_string="0")
    + column_block("AssociatedInvoiceCount", "int64", summarize="sum", format_string="0")
    + column_block("TotalInvoiceCount", "int64", summarize="sum", format_string="0")
)
fact_partition = sql_partition("Fact_PartAssociation", "Fact_PartAssociation")
fact_tmdl = f"""table Fact_PartAssociation
\tlineageTag: {tag()}

{fact_cols}
\tpartition Fact_PartAssociation = m
\t\tmode: import
\t\tsource =
{fact_partition}
"""
write_utf8_no_bom(TABLES_DIR / "Fact_PartAssociation.tmdl", fact_tmdl)

# ---------------------------------------------------------------------
# dim_Parts_Selected / dim_Parts_Recommended (role-playing copies of dim_Parts)
# ---------------------------------------------------------------------
for table_name in ("dim_Parts_Selected", "dim_Parts_Recommended"):
    cols = (
        column_block("PartNumber", "string")
        + column_block("Description", "string")
    )
    partition = sql_partition(table_name, "dim_Parts", select_columns=["PartNumber", "Description"])
    tmdl = f"""table {table_name}
\tlineageTag: {tag()}

{cols}
\tpartition {table_name} = m
\t\tmode: import
\t\tsource =
{partition}
"""
    write_utf8_no_bom(TABLES_DIR / f"{table_name}.tmdl", tmdl)

# ---------------------------------------------------------------------
# dim_Franchise (local import copy — full shared table already has
# FranchiseKey/Franchise as documented in dim_Franchise.pq; only pull
# what this model needs)
# ---------------------------------------------------------------------
franchise_cols = (
    column_block("Franchise", "string")
)
franchise_partition = sql_partition("dim_Franchise", "dim_Franchise", select_columns=["Franchise"])
franchise_tmdl = f"""table dim_Franchise
\tlineageTag: {tag()}

{franchise_cols}
\tpartition dim_Franchise = m
\t\tmode: import
\t\tsource =
{franchise_partition}
"""
write_utf8_no_bom(TABLES_DIR / "dim_Franchise.tmdl", franchise_tmdl)

# ---------------------------------------------------------------------
# Data Refresh (standard UTC->Central watermark pattern used everywhere else)
# ---------------------------------------------------------------------
data_refresh_tag = tag()
data_refresh_m = """    let
        UtcNow    = DateTimeZone.UtcNow(),
        UtcDT     = DateTimeZone.RemoveZone(UtcNow),
        CurYear   = Date.Year(DateTime.Date(UtcDT)),
        Mar1      = #date(CurYear, 3, 1),
        Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
        DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
        Nov1      = #date(CurYear, 11, 1),
        Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
        DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
        OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
        LocalDT   = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),
        Source    = #table({"CurrentDateTime"}, {{LocalDT}}),
        AddDate   = Table.DuplicateColumn(Source, "CurrentDateTime", "Date"),
        AddTime   = Table.DuplicateColumn(AddDate, "Date", "Time"),
        ChgTypes  = Table.TransformColumnTypes(AddTime, {{"Date", type date}, {"Time", type time}})
    in
        ChgTypes"""
data_refresh_tmdl = f"""table 'Data Refresh'
\tisHidden
\tlineageTag: {data_refresh_tag}

{column_block("CurrentDateTime", "string", hidden=True)}{column_block("Date", "dateTime", hidden=True, format_string="Long Date")}{column_block("Time", "dateTime", hidden=True, format_string="Long Time")}
\tpartition 'Data Refresh' = m
\t\tmode: import
\t\tsource =
{data_refresh_m}

\tchangedProperty = IsHidden

\tannotation PBI_NavigationStepName = Navigation

\tannotation PBI_ResultType = Table
"""
write_utf8_no_bom(TABLES_DIR / "Data Refresh.tmdl", data_refresh_tmdl)

# ---------------------------------------------------------------------
# MeasuresTable
# ---------------------------------------------------------------------
def measure_block(name, expr, format_string=None):
    lines = [f"\tmeasure {name} =", "\t\t\t", f"\t\t\t{expr}"]
    if format_string:
        lines.append(f"\t\tformatString: {format_string}")
    lines.append(f"\t\tlineageTag: {tag()}")
    lines.append("")
    return "\n".join(lines)

measures = (
    measure_block(
        "Co-Occurrence Count",
        "SUM ( Fact_PartAssociation[CoOccurrenceCount] )",
        format_string="#,0",
    )
    + measure_block(
        "Anchor Invoices",
        (
            "SUMX (\n"
            "\t\t\t\tSUMMARIZE ( Fact_PartAssociation, Fact_PartAssociation[Franchise], "
            "Fact_PartAssociation[PartA], Fact_PartAssociation[AnchorInvoiceCount] ),\n"
            "\t\t\t\tFact_PartAssociation[AnchorInvoiceCount]\n\t\t\t)"
        ),
        format_string="#,0",
    )
    + measure_block(
        "Associated Invoices",
        (
            "SUMX (\n"
            "\t\t\t\tSUMMARIZE ( Fact_PartAssociation, Fact_PartAssociation[Franchise], "
            "Fact_PartAssociation[PartB], Fact_PartAssociation[AssociatedInvoiceCount] ),\n"
            "\t\t\t\tFact_PartAssociation[AssociatedInvoiceCount]\n\t\t\t)"
        ),
        format_string="#,0",
    )
    + measure_block(
        "Total Invoices",
        (
            "SUMX (\n"
            "\t\t\t\tSUMMARIZE ( Fact_PartAssociation, Fact_PartAssociation[Franchise], "
            "Fact_PartAssociation[TotalInvoiceCount] ),\n"
            "\t\t\t\tFact_PartAssociation[TotalInvoiceCount]\n\t\t\t)"
        ),
        format_string="#,0",
    )
    + measure_block(
        "Confidence %",
        "DIVIDE ( [Co-Occurrence Count], [Anchor Invoices] )",
        format_string="0.0%;-0.0%;0.0%",
    )
    + measure_block(
        "Baseline %",
        "DIVIDE ( [Associated Invoices], [Total Invoices] )",
        format_string="0.0%;-0.0%;0.0%",
    )
    + measure_block(
        "Lift",
        "DIVIDE ( [Confidence %], [Baseline %] )",
        format_string="0.00",
    )
)
measures_tmdl = f"""table MeasuresTable
\tlineageTag: {tag()}

{measures}"""
write_utf8_no_bom(TABLES_DIR / "MeasuresTable.tmdl", measures_tmdl)

# ---------------------------------------------------------------------
# relationships.tmdl
# ---------------------------------------------------------------------
relationships_tmdl = f"""relationship {tag()}
\tfromColumn: Fact_PartAssociation.PartA
\ttoColumn: dim_Parts_Selected.PartNumber

relationship {tag()}
\tfromColumn: Fact_PartAssociation.PartB
\ttoColumn: dim_Parts_Recommended.PartNumber

relationship {tag()}
\tfromColumn: Fact_PartAssociation.Franchise
\ttoColumn: dim_Franchise.Franchise
"""
write_utf8_no_bom(DEF_DIR / "relationships.tmdl", relationships_tmdl)

# ---------------------------------------------------------------------
# model.tmdl / database.tmdl / cultures/en-US.tmdl
# ---------------------------------------------------------------------
write_utf8_no_bom(DEF_DIR / "database.tmdl", "database\n\tcompatibilityLevel: 1600\n")

model_tmdl = """model Model
\tculture: en-US
\tdefaultPowerBIDataSourceVersion: powerBI_V3
\tsourceQueryCulture: en-US
\tdataAccessOptions
\t\tlegacyRedirects
\t\treturnErrorValuesAsNull

annotation __PBI_TimeIntelligenceEnabled = 0

annotation PBI_QueryOrder = ["Data Refresh","dim_Franchise","dim_Parts_Selected","dim_Parts_Recommended","Fact_PartAssociation","MeasuresTable"]

annotation PBI_ProTooling = ["DevMode"]

ref table MeasuresTable
ref table 'Data Refresh'
ref table dim_Franchise
ref table dim_Parts_Selected
ref table dim_Parts_Recommended
ref table Fact_PartAssociation

ref cultureInfo en-US
"""
write_utf8_no_bom(DEF_DIR / "model.tmdl", model_tmdl)

write_utf8_no_bom(DEF_DIR / "cultures" / "en-US.tmdl", "cultureInfo en-US\n")

# ---------------------------------------------------------------------
# .platform, definition.pbism, diagramLayout.json, top-level .pbip
# ---------------------------------------------------------------------
platform = {
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
    "metadata": {"type": "SemanticModel", "displayName": "Associated Parts"},
    "config": {"version": "2.0", "logicalId": str(uuid.uuid4())},
}
write_utf8_no_bom(MODEL_DIR / ".platform", json.dumps(platform, indent=2))

pbism = {
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json",
    "version": "4.2",
    "settings": {},
}
write_utf8_no_bom(MODEL_DIR / "definition.pbism", json.dumps(pbism, indent=2))

diagram = {"version": "1.1.0", "diagrams": [{"ordinal": 0, "scrollPosition": {"x": 0, "y": 0}, "nodes": []}]}
write_utf8_no_bom(MODEL_DIR / "diagramLayout.json", json.dumps(diagram, indent=2))

pbip = {
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
    "version": "1.0",
    "artifacts": [{"report": {"path": "Associated Parts.Report"}}],
    "settings": {"enableAutoRecovery": True},
}
write_utf8_no_bom(ROOT / "Associated Parts.pbip", json.dumps(pbip, indent=2))

print("Semantic model scaffold written to:", MODEL_DIR)
```

Run this as a one-off script from the repo root, then discard it (it's a generator, not a checked-in artifact).

Note: the generated top-level `Associated Parts.pbip` references `Associated Parts.Report`, which doesn't exist yet — that's expected. Desktop will show a broken reference until Task 9 creates the report; don't try to open the `.pbip` in Desktop before then. Opening the `.SemanticModel` folder's contents is fine.

- [ ] **Step 2: Check for the three known TMDL gotchas**

Run:
```bash
grep -rn "^\s*//" "projects/associated parts - report/reports/current/Associated Parts.SemanticModel/definition" || echo "No // comments found (good)"
grep -rn "description:" "projects/associated parts - report/reports/current/Associated Parts.SemanticModel/definition" || echo "No description: properties found (good)"
python3 -c "
from pathlib import Path
for p in Path('projects/associated parts - report/reports/current/Associated Parts.SemanticModel/definition').rglob('*.tmdl'):
    data = p.read_bytes()
    if data.startswith(b'\xef\xbb\xbf'):
        print(f'BOM FOUND: {p}')
print('BOM check complete.')
"
```
Expected: `No // comments found (good)`, `No description: properties found (good)`, `BOM check complete.` with no `BOM FOUND` lines.

- [ ] **Step 3: Verify the JSON files parse**

Run:
```bash
python3 -c "
import json
from pathlib import Path
base = Path('projects/associated parts - report/reports/current')
for f in [base / 'Associated Parts.pbip',
          base / 'Associated Parts.SemanticModel' / '.platform',
          base / 'Associated Parts.SemanticModel' / 'definition.pbism',
          base / 'Associated Parts.SemanticModel' / 'diagramLayout.json']:
    json.loads(f.read_text(encoding='utf-8'))
    print(f'{f.name}: OK')
"
```
Expected: four `OK` lines, no `json.decoder.JSONDecodeError`.

- [ ] **Step 4: Commit**

```bash
git add "projects/associated parts - report/reports/current"
git commit -m "Scaffold Associated Parts semantic model (TMDL)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Write project documentation

**Files:**
- Create: `projects/associated parts - report/CLAUDE.md`
- Create: `projects/associated parts - report/README.md`

- [ ] **Step 1: Write CLAUDE.md**

Follow the exact structure already used by `projects/unique parts customers - report/CLAUDE.md` (Report Overview, Semantic Model tables, Dimensions, Key Measures, Report Pages, Data Flow, Known Issues & Gotchas, Refresh Pipeline Position, Documentation Status):

```markdown
# Associated Parts — Claude Context

## Report Overview
- **Business purpose:** For any selected part, shows the parts customers most reliably buy alongside it — a Part×Part market-basket association across all sales (counter and service work order alike), for parts reordering and recommendation decisions.
- **Primary users:** Parts managers, counter staff
- **Workspace:** RP - Parts Reports (target production workspace; not yet published — see Task 9)
- **Refresh tier:** Weekly (Tier-3-style cadence, off the daily 4:15 AM orchestrator — association patterns are slow-moving and don't need daily freshness)
- **Status:** In development

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_PartAssociation` | One row per Franchise × PartA × PartB (directional) | CoOccurrenceCount, AnchorInvoiceCount, AssociatedInvoiceCount, TotalInvoiceCount | Raw counts, not pre-computed percentages — lets DAX correctly roll up to a company-wide (all-franchise) view. Built by a weekly Fabric Notebook, not a Dataflow Gen2 — see Known Issues. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_Parts_Selected` | Local import of shared `dim_Parts` | `Fact_PartAssociation.PartA → dim_Parts_Selected.PartNumber` |
| `dim_Parts_Recommended` | Local import of shared `dim_Parts` | `Fact_PartAssociation.PartB → dim_Parts_Recommended.PartNumber` |
| `dim_Franchise` | Local import of shared `dim_Franchise` | `Fact_PartAssociation.Franchise → dim_Franchise.Franchise` |

Note: `dim_Parts` is imported **twice** under different table names
(role-playing dimension pattern) because the fact table needs to relate to
it once as "the part the user selected" and once as "the recommended
part." The shared `dim_Parts` dimension itself is untouched — this model
just reads it twice locally.

### Key Measures (in `MeasuresTable`)
| Measure | Description |
|---------|-------------|
| `Co-Occurrence Count` | SUM of Fact_PartAssociation[CoOccurrenceCount] |
| `Anchor Invoices` | De-duplicated (Franchise, PartA) sum of AnchorInvoiceCount — **not** a plain SUM, because AnchorInvoiceCount repeats across every PartB row for the same PartA; a plain SUM would overcount whenever more than one associated part is in context |
| `Associated Invoices` | Same de-duplication pattern, keyed on (Franchise, PartB) |
| `Total Invoices` | Same de-duplication pattern, keyed on Franchise alone |
| `Confidence %` | DIVIDE([Co-Occurrence Count], [Anchor Invoices]) — "of everyone who bought the selected part, what % also bought this one" |
| `Baseline %` | DIVIDE([Associated Invoices], [Total Invoices]) — how often the associated part sells anyway, regardless of the selected part |
| `Lift` | DIVIDE([Confidence %], [Baseline %]) — how much more likely the pairing is than chance; ~1 means the associated part is just universally popular (not a real signal) |

## Report Pages
| Page | Purpose | Visibility |
|------|---------|------------|
| Associated Parts | Part picker + ranked associated-parts table + context card | Visible (not yet built — see Task 9) |

## Data Flow
```
EquipRDB (ODBC) → InTrans_Incremental (Lakehouse)
  → Fact_PartAssociation_Build.ipynb (Fabric Notebook, weekly, DuckDB compute + Spark write)
  → Fact_PartAssociation (Lakehouse Delta table)
```

## Known Issues & Gotchas
- **Not a Dataflow Gen2 fact table** — unlike most fact tables in this repo, `Fact_PartAssociation` is built by a Fabric Notebook. This was a deliberate choice: the Part×Part self-join-on-invoice is the same shape that caused two real multi-minute-to-45-minute M-engine hangs elsewhere (dim_Parts, Fact_PriceUpdate_Enriched) — see the design spec for full reasoning.
- **`AnchorInvoiceCount`/`AssociatedInvoiceCount`/`TotalInvoiceCount` are repeated values, not additive facts** — always aggregate them through the `Anchor Invoices`/`Associated Invoices`/`Total Invoices` measures (which de-duplicate via SUMMARIZE first), never with a bare SUM in new DAX. A bare SUM silently overcounts as soon as more than one row shares the same PartA/PartB/Franchise.
- **Basket-size cap and minimum co-occurrence threshold are data-driven constants**, not universal truths — determined once from a real-data profiling pass (see `docs/superpowers/plans/2026-08-27-associated-parts-recommended-parts.md`, Tasks 2-3) and hardcoded into the notebook. Re-profile if InTrans sales patterns change materially (e.g., after a franchise mix shift).
- **Not yet published anywhere** — semantic model and notebook exist as local files only as of this writing; see Task 9 for the remaining manual Fabric/Desktop steps.

## Refresh Pipeline Position
- Weekly, off the daily Phase 1-5 orchestrator entirely (not yet scheduled — see Task 9)
- Depends on `InTrans_Incremental` (Phase 2, daily) being current

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ⬜ PROJECT-SUMMARY.md (add if/when this report gets a formal stakeholder handoff)
- Obsidian stakeholder docs: ⬜ Not yet created — run `/document-report` once the report is live in Sandbox/production
```

- [ ] **Step 2: Write a short README.md**

```markdown
# Associated Parts

Part×Part market-basket association report — "customers who bought this
part also bought these parts," across all sales (counter and service work
order alike).

See `CLAUDE.md` for the full technical breakdown, and
`docs/superpowers/specs/2026-08-27-associated-parts-design.md` in the repo
root for the original design rationale.

**Status:** In development — semantic model and notebook built, not yet
published to Fabric. See `docs/superpowers/plans/2026-08-27-associated-parts-recommended-parts.md`,
Task 9, for remaining steps.
```

- [ ] **Step 3: Commit**

```bash
git add "projects/associated parts - report/CLAUDE.md" "projects/associated parts - report/README.md"
git commit -m "Add project documentation for Associated Parts report

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Push the dev branch

**Files:** none (git operation only)

- [ ] **Step 1: Confirm all Associated Parts work is committed**

Run: `git status`
Expected: no uncommitted changes under `projects/associated parts - report/`, `.claude/queries/facts/Fact_PartAssociation.md`, `.claude/queries/adhoc/associated-parts-profiling/`, or `docs/superpowers/`.

- [ ] **Step 2: Push**

```bash
git push origin dev
```

---

### Task 9 (manual — Brian): Publish the semantic model and build the report

This task is not automatable from this session — it requires Power BI
Desktop and the live Fabric workspace. Follow in order:

- [ ] **Step 1:** Open `projects/associated parts - report/reports/current/Associated Parts.SemanticModel` in Power BI Desktop (open the folder directly, or via Tabular Editor / TMDL view — do **not** open the sibling `.pbip` yet, since it points at a `Associated Parts.Report` that doesn't exist until Step 3).
- [ ] **Step 2:** Verify the model loads without error (this is the real validation the earlier automated checks in Task 6 couldn't do), spot-check `Confidence %`/`Lift` on a few known parts against the numbers from Task 3's real-data validation run, then **Publish to RP - Dev** (per this repo's standard dev→sandbox→production flow — never publish new/unvalidated reports straight to a production workspace).
- [ ] **Step 3:** Once published and confirmed visible in RP - Dev, create the connected report locally:
  ```bash
  cd "projects/associated parts - report/reports/current"
  pbir new report "Associated Parts.Report" -c "RP - Dev/Associated Parts.SemanticModel"
  ```
- [ ] **Step 4:** Build the report page per the design spec's Section 3 (part selector slicer bound to `dim_Parts_Selected`, franchise slicer bound to `dim_Franchise`, a ranked table of `dim_Parts_Recommended[Description]` / `Co-Occurrence Count` / `Confidence %` / `Lift` sorted by Lift descending, and a context card showing `Anchor Invoices` for the selected part) — either by hand in Desktop, or by continuing with `pbir add page`/`pbir add visual`/`pbir visuals bind` in a follow-up Claude Code session (the `pbir-cli` skill's `create-new-report.md` reference has the exact command patterns).
- [ ] **Step 5:** Create the Fabric Notebook item in the `LH_Master_Data` workspace, paste in the contents of `Fact_PartAssociation_Build.ipynb` (Task 4), and run it once manually to confirm `Fact_PartAssociation` is created successfully before wiring any schedule.
- [ ] **Step 6:** Create a weekly Fabric Pipeline trigger for the notebook (Tier-3-style cadence, off the 4:15 AM Mon-Fri orchestrator — a separate weekly schedule, matching Price Matrix/Bin Location).
- [ ] **Step 7:** Once both the notebook has run successfully and the report is built, refresh the semantic model in RP - Dev and validate the report end-to-end (pick a few real, high-volume parts and sanity-check the associated-parts list against business knowledge) before deploying further per this repo's standard Dev → Sandbox → Production flow.
