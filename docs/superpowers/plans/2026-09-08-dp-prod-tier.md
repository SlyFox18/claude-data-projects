# DP Prod Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Prod tier of the JD Bronze data platform backend (`DP - Staging - Prod`, `DP - Presentation - Prod`) — lakehouses, bronze shortcut, and the silver/gold notebooks — as a fully independent, fully verified build (not a copy trusted by association with Dev), so a future plan can safely repoint production `RP - Parts Reports`'s Parts Promo at it.

**Architecture:** Mirrors Plans 2-4 exactly, but with one real correction caught during planning research (not left for a future "corrected 2026-09-XX" note): the original intent was for both notebooks to read their lakehouse GUIDs from the `DP - Environment Config` Variable Library at runtime via `notebookutils.variableLibrary`. Current Microsoft Fabric documentation confirms this **does not work cross-workspace** — `notebookutils.variableLibrary` "only supports access to variable libraries within the same workspace. Cross-workspace access isn't supported." (`Build_Gold_PartsPromo.Notebook` lives in `DP - Presentation - Dev`; the Variable Library lives in `DP - Staging - Dev` — a different workspace.)

The corrected design needs no runtime Variable Library calls at all:
- `Build_Silver_InTrans.Notebook`'s cell code is already environment-agnostic — it only ever reads/writes tables by name (`spark.read.table("InTrans")`, `.save("Tables/Silver_InTrans")`), resolved through the notebook's own `default_lakehouse` binding. That binding is notebook-item metadata, not something Variable Library replaces — it's the same kind of unavoidable per-environment structural difference as a semantic model's `.tmdl` connection string differing between `RP - Dev` and `RP - Parts Reports` today.
- `Build_Gold_PartsPromo.Notebook` is the one real offender: it hardcodes a cross-workspace `abfss://` path (`SILVER_PATH`) with the Dev Staging workspace/lakehouse GUIDs baked into a Python string literal. The fix is the same "shortcuts, not copies" principle Section 3 of the design spec already established for bronze: add a `Silver_InTrans` OneLake shortcut inside `DP_Presentation`'s own lakehouse, pointing at `DP_Staging.Silver_InTrans` — then the notebook reads `spark.read.table("Silver_InTrans")`, no GUIDs, no cross-workspace call of any kind. This makes the notebook's cell code byte-identical between Dev and Prod; only `default_lakehouse` metadata differs.

Since the Dev tier currently has the hardcoded-path problem too, this plan fixes Dev's copy first (Task 3) as a verified, zero-data-change refactor, before authoring the Prod copy from the corrected version (Task 4) — so both tiers run the exact same logic from day one, per the design's actual intent, just accomplished through shortcuts instead of a runtime Variable Library read.

The Variable Library keeps the role it already has: an authoritative, git-tracked, human-and-future-tooling-readable record of the 4 lakehouse GUIDs (useful for a future `fabric-cicd` deployment config, or a future pipeline/shortcut-variable consumer, both of which *do* support the mechanisms this plan found don't fit notebooks). This plan populates its `Prod` value set with the real GUIDs once they exist, replacing the `not-yet-created` placeholders — a record-keeping step, not a functional dependency for anything built here.

Because `DP - Staging - Prod` and `DP - Presentation - Prod` are different git folders than their Dev counterparts (`workspaces/DP - Staging - Prod/...` vs. `workspaces/DP - Staging - Dev/...`), a `dev`→`main` branch merge would not place anything into them — there is nothing at those paths on `dev` to merge. "Promotion" in this plan means authoring the notebook content directly into the Prod-tier git folder (Task 4), the same way `Build_Gold_PartsPromo.Notebook` was originally authored directly as a Dev-tier git file in Plan 4 — not a merge operation.

**Tech Stack:** Microsoft Fabric CLI (`fab`) for lakehouse creation, Fabric portal for shortcuts and running notebooks (no verified CLI syntax for either — same reasoning as every prior plan in this series), DuckDB for independent verification, `pyodbc`/`dsn=EquipRDB64` for source-of-truth verification.

**Capacity note (ongoing tracking, per project memory):** this plan runs each notebook exactly twice total across its lifetime as written — once to prove the Dev refactor didn't change output (Task 3), once for the real Prod build (Task 7). That's a small, one-time cost. The lasting capacity impact is structural: once Prod is live, the backend has *two* full silver+gold builds that will eventually need scheduling (Dev for continued iteration, Prod for the live report) instead of one — worth remembering when refresh scheduling (still explicitly deferred, per the design spec and prior session agreement) is designed, so Prod doesn't end up scheduled as frequently as Dev needs to be for active development.

---

### Task 1: Create the 2 Prod lakehouses

**Files:** none (Fabric tenant infrastructure)

- [x] **Step 1: Brian creates both lakehouses**

Run in your own terminal (not this session — every mutating `fab` command in this series gets auto-blocked by the sandbox classifier but runs fine directly):
```
fab mkdir "DP - Staging - Prod.Workspace/DP_Staging.Lakehouse"
fab mkdir "DP - Presentation - Prod.Workspace/DP_Presentation.Lakehouse"
```
Expected: both commands complete with no error.

**Done 2026-09-08:** `DP_Staging` already existed in `DP - Staging - Prod` from earlier work; `DP_Presentation` was newly created in `DP - Presentation - Prod`.

- [x] **Step 2: Verify and record the IDs (agent-executed)**

Once Brian confirms Step 1 is done, run:
```
fab get "DP - Staging - Prod.Workspace/DP_Staging.Lakehouse" -q "id"
fab get "DP - Presentation - Prod.Workspace/DP_Presentation.Lakehouse" -q "id"
```
Expected: two GUIDs. Record both — needed for every later task in this plan.

**Recorded 2026-09-08:**
- `DP_Staging` (Prod) lakehouse ID: `6713bd45-a4ad-47e6-8bff-1bb0415e9784`
- `DP_Presentation` (Prod) lakehouse ID: `29d9df80-a383-4d40-9807-1e2e6cbff88f`
- (Workspace IDs, already on record in `docs/architecture/data-platform-workspaces.md`: `DP - Staging - Prod` = `189e5c0a-548a-4feb-93d6-dda9ebbe96c1`, `DP - Presentation - Prod` = `7836042d-adb1-4846-b70d-bd42980054c5`)

---

### Task 2: Create the Prod bronze shortcut and verify it independently ✅ DONE 2026-09-08

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut_prod.py`

Verified: row count (20,612,638), min/max timestamp, and RO 1985073 (9 rows) all match JD Bronze source exactly. Committed `df6300bf`.

- [x] **Step 1: Brian creates the shortcut**

In the Fabric portal:
1. Open workspace `DP - Staging - Prod` → lakehouse `DP_Staging`
2. In the **Tables** section, select **...** → **New table shortcut** → **Microsoft OneLake**
3. Browse to: workspace `JD_FabricOneLake` → lakehouse `JD_EquipRDB_Production_Bronze` → **Tables** → select `InTrans`
4. Keep the shortcut name as `InTrans`
5. Select **Create**

- [ ] **Step 2: Confirm it appears**

In the lakehouse's Tables list, `InTrans` should show with a shortcut icon. Report back once visible.

- [ ] **Step 3: Write the Prod verification script**

Same three checks as the Dev shortcut verification (`.claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py`, Plan 2 Task 3), pointed at the Prod IDs instead:

```python
"""
DP BRONZE SHORTCUT VERIFICATION - PROD TIER
============================================================================
Confirms the DP - Staging - Prod / DP_Staging.InTrans OneLake shortcut
(created in this plan's Task 2) is a complete, accurate zero-copy reference
to JD_EquipRDB_Production_Bronze.InTrans - not a partial or stale copy.

Same three checks as the Dev tier's verify_shortcut.py (Plan 2), run
independently against the Prod shortcut rather than assumed identical
because it came from the same source - this is a separate shortcut object
and needs its own proof.

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb

JD_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"      # JD_FabricOneLake workspace
JD_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"      # JD_EquipRDB_Production_Bronze lakehouse
jd_base = f"abfss://{JD_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_LH_ID}/Tables"

# Fill in after Task 1, Step 2:
DP_STAGING_PROD_WS_ID = "<DP - Staging - Prod workspace ID>"
DP_STAGING_PROD_LH_ID = "<DP_Staging Prod lakehouse ID from Task 1>"
dp_base = f"abfss://{DP_STAGING_PROD_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_PROD_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count / date range, JD source vs. Prod DP shortcut ===")
jd_stats = con.execute(f"""
    SELECT COUNT(*) AS RowCount, MIN(Trans_Datetime) AS MinTS, MAX(Trans_Datetime) AS MaxTS
    FROM delta_scan('{jd_base}/InTrans')
""").df()
print("JD Bronze direct:")
print(jd_stats.to_string())

dp_stats = con.execute(f"""
    SELECT COUNT(*) AS RowCount, MIN(Trans_Datetime) AS MinTS, MAX(Trans_Datetime) AS MaxTS
    FROM delta_scan('{dp_base}/InTrans')
""").df()
print("\nDP_Staging (Prod) shortcut:")
print(dp_stats.to_string())

match = (jd_stats["RowCount"][0] == dp_stats["RowCount"][0]
         and jd_stats["MaxTS"][0] == dp_stats["MaxTS"][0])
print(f"\nRow count and max timestamp match: {match}")

print("\n=== Check 2: RO 1985073 spot check through the Prod shortcut ===")
ro_check = con.execute(f"""
    SELECT BRANCH, FRANCHISE, REF_NO, PART_NO, Trans_Datetime, SALE_VAL
    FROM delta_scan('{dp_base}/InTrans')
    WHERE REF_NO = '1985073'
    ORDER BY Trans_Datetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 through Prod shortcut: {len(ro_check)} (expect 9, matching source)")
```

- [ ] **Step 4: Fill in the two placeholder IDs and run it**

```
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_shortcut_prod.py"
```
Expected: identical row counts/max timestamp between JD source and the Prod shortcut, exactly 9 rows for RO 1985073.

**If any check fails: stop, do not proceed to Task 3.**

- [ ] **Step 5: Commit the verification script**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcut_prod.py
git commit -m "Add DP bronze shortcut verification script (Prod tier)

Confirms DP - Staging - Prod's InTrans OneLake shortcut is a complete,
accurate zero-copy reference to JD_EquipRDB_Production_Bronze -
verified independently, not assumed identical to the Dev shortcut.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Fix the Dev-tier Gold notebook's hardcoded cross-workspace path ✅ DONE 2026-09-08

Verified as a pure refactor: `verify_gold_parts_promo.py` re-run after the fix produced an identical result to Plan 4's original run — 0 mismatches across all 11 known-bad orders, RO 1985073 still $627.64. Commits `aebabb78` (the fix) and `05dc40fa` (a stale header paragraph the subagent flagged but correctly left out of scope, cleaned up separately).

**Files:**
- Modify: `workspaces/DP - Presentation - Dev/Build_Gold_PartsPromo.Notebook/notebook-content.py` (in `fabric-workspace-docs`)

This is a refactor, not a data change — the shortcut and the direct `abfss` path point at the exact same physical table. Task 3's own verification proves that.

- [ ] **Step 1: Brian adds the Silver_InTrans shortcut to DP_Presentation (Dev)**

In the Fabric portal:
1. Open workspace `DP - Presentation - Dev` → lakehouse `DP_Presentation`
2. In the **Tables** section, select **...** → **New table shortcut** → **Microsoft OneLake**
3. Browse to: workspace `DP - Staging - Dev` → lakehouse `DP_Staging` → **Tables** → select `Silver_InTrans`
4. Keep the shortcut name as `Silver_InTrans`
5. Select **Create**

- [ ] **Step 2: Confirm it appears, and row counts match the direct source**

Report back once `Silver_InTrans` shows with a shortcut icon in `DP_Presentation`'s Tables list. Then run:
```
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python -c "
import duckdb
con = duckdb.connect()
con.execute(\"INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;\")
con.execute(\"CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');\")
staging = con.execute(\"SELECT COUNT(*) FROM delta_scan('abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/Silver_InTrans')\").fetchone()[0]
presentation = con.execute(\"SELECT COUNT(*) FROM delta_scan('abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/Silver_InTrans')\").fetchone()[0]
print(f'Staging direct: {staging:,}')
print(f'Presentation shortcut: {presentation:,}')
print(f'Match: {staging == presentation}')
"
```
Expected: `Match: True`.

- [ ] **Step 3: Update the notebook code**

Read the current file, then replace the `SILVER_PATH`/`silver` cell (the second `# CELL` block) — currently:
```python
from pyspark.sql import functions as F

SILVER_PATH = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/Silver_InTrans"
START_DATE = "2022-01-01"  # matches the existing production Fact_PartsPromo_v2.pq / dim_RepairOrder.pq StartDate

silver = spark.read.format("delta").load(SILVER_PATH).filter(F.col("TransDatetime") >= START_DATE)

row_count = silver.count()
print(f"Silver_InTrans rows loaded (>= {START_DATE}): {row_count:,}")
```

with:
```python
from pyspark.sql import functions as F

START_DATE = "2022-01-01"  # matches the existing production Fact_PartsPromo_v2.pq / dim_RepairOrder.pq StartDate

# Reads via the Silver_InTrans OneLake shortcut in this lakehouse's own Tables
# section (added 2026-09-08, see the DP Prod Tier plan's Task 3) instead of a
# hardcoded cross-workspace abfss path. notebookutils.variableLibrary cannot
# resolve variables across workspaces (confirmed via current Fabric docs:
# "only supports access to variable libraries within the same workspace"),
# so a shortcut is the correct zero-hardcoding mechanism here - the same
# "shortcuts, not copies" principle already used for the bronze InTrans
# shortcut. This also makes this notebook's cell code identical between the
# Dev and Prod tiers - only the notebook's own default_lakehouse METADATA
# binding differs per tier.
silver = spark.read.table("Silver_InTrans").filter(F.col("TransDatetime") >= START_DATE)

row_count = silver.count()
print(f"Silver_InTrans rows loaded (>= {START_DATE}): {row_count:,}")
```

Also append a third numbered correction note to the notebook's header comment block (after the existing "1." and "2." from the 2026-09-08 corrections), directly above the `print("=" * 80)` line:
```python
#
# 3. Replaced the hardcoded SILVER_PATH abfss:// literal (Dev Staging
#    workspace/lakehouse GUIDs baked into the code) with a read through a
#    Silver_InTrans OneLake shortcut added to this lakehouse - see the note
#    above the `silver = spark.read.table(...)` line for why. Needed before
#    this notebook could be correctly authored a second time for the Prod
#    tier without forking the code.
```

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Build_Gold_PartsPromo.Notebook/notebook-content.py"
git commit -m "Fix Build_Gold_PartsPromo hardcoded cross-workspace path

Reads Silver_InTrans via a OneLake shortcut now, not a hardcoded
abfss:// literal with the Staging workspace/lakehouse GUIDs baked in.
notebookutils.variableLibrary can't resolve variables cross-workspace
(confirmed via current Fabric docs), so a shortcut - the same pattern
already used for the bronze InTrans shortcut - is the correct fix.
Makes the notebook's cell code identical between Dev and Prod tiers.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

- [ ] **Step 5: Brian confirms the Dev workspace picked up the change**

In the Fabric portal: `DP - Presentation - Dev` → Source control → **Update all**.

- [ ] **Step 6: Brian re-runs the Dev Gold notebook**

Open `Build_Gold_PartsPromo.Notebook` in `DP - Presentation - Dev` and run all cells.

- [ ] **Step 7: Verify Dev output is unchanged (agent-executed)**

Run the existing Dev verification script again — it should produce the exact same result as it did in Plan 4, proving this was a pure refactor:
```
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo.py"
```
Expected: `Orders checked: 11`, `Orders with a real mismatch: 0` — identical to Plan 4's result. **If this differs from before, stop and investigate before proceeding — the shortcut refactor should not have changed a single row.**

---

### Task 4: Author the Prod-tier notebooks ✅ DONE 2026-09-08

**Correction found during execution:** Step 4 below originally said to `git push origin main` directly. `fabric-workspace-docs` has a local hook enforcing the repo's own stated convention ("Direct pushes to `main` should be avoided even on `fabric-workspace-docs`," per root `CLAUDE.md`) — it correctly rejected the push. Fixed by branching the commit off (`dp-prod-tier-notebooks`), opening a PR (`SlyFox18/fabric-workspace-docs#15`), and merging via `gh pr merge` — Brian's call to proceed since this was the first `main` merge of the session. Local `main` fast-forwarded cleanly, branch deleted, back on `dev`. Logical IDs generated fresh (not reused from Dev, since these are independently-provisioned items, not deployment-pipeline-linked): Silver `7c1ac7f4-948f-4166-ae09-f27bb4df60ef`, Gold `b77e2ad5-26a1-45e5-bbef-cdcc32e2790b`.

**Files:**
- Create: `workspaces/DP - Staging - Prod/Build_Silver_InTrans.Notebook/.platform`
- Create: `workspaces/DP - Staging - Prod/Build_Silver_InTrans.Notebook/notebook-content.py`
- Create: `workspaces/DP - Presentation - Prod/Build_Gold_PartsPromo.Notebook/.platform`
- Create: `workspaces/DP - Presentation - Prod/Build_Gold_PartsPromo.Notebook/notebook-content.py`

All four files live in `fabric-workspace-docs`, committed directly to `main` (these are new Prod-tier files with no `dev` counterpart at these paths — nothing to merge, per this plan's Architecture note).

- [ ] **Step 1: Get the `.platform` file content pattern**

Read `workspaces/DP - Staging - Dev/Build_Silver_InTrans.Notebook/.platform` and `workspaces/DP - Presentation - Dev/Build_Gold_PartsPromo.Notebook/.platform` to copy their exact structure (metadata schema, item type) — only the `displayName`/GUIDs inside need to change for the Prod copies, if any exist in that file; item `.platform` files in this repo typically hold `type`/`displayName` only, not workspace-specific IDs.

- [ ] **Step 2: Create `Build_Silver_InTrans.Notebook` for `DP - Staging - Prod`**

Content is **byte-identical** to the current (post-Task-3) Dev version in every cell — copy `workspaces/DP - Staging - Dev/Build_Silver_InTrans.Notebook/notebook-content.py` verbatim, changing only the METADATA block at the top:

```python
# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "<DP_Staging Prod lakehouse ID from Task 1>",
# META       "default_lakehouse_name": "DP_Staging",
# META       "default_lakehouse_workspace_id": "<DP - Staging - Prod workspace ID from Task 1>",
# META       "known_lakehouses": [
# META         {
# META           "id": "<DP_Staging Prod lakehouse ID from Task 1>"
# META         }
# META       ]
# META     }
# META   }
# META }
```

Every cell below that (the header comment, the column rename/select, the dedupe window, the merge/write logic, the verification cell) is copied exactly as-is from the Dev file — no code changes, per this plan's whole point.

- [ ] **Step 3: Create `Build_Gold_PartsPromo.Notebook` for `DP - Presentation - Prod`**

Same approach: copy `workspaces/DP - Presentation - Dev/Build_Gold_PartsPromo.Notebook/notebook-content.py` (the post-Task-3 version, with the shortcut-based `silver = spark.read.table("Silver_InTrans")` read) verbatim, changing only the METADATA block:

```python
# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "<DP_Presentation Prod lakehouse ID from Task 1>",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "<DP - Presentation - Prod workspace ID from Task 1>",
# META       "known_lakehouses": [
# META         {
# META           "id": "<DP_Presentation Prod lakehouse ID from Task 1>"
# META         }
# META       ]
# META     }
# META   }
# META }
```

Every cell below is copied exactly as-is.

- [ ] **Step 4: Commit and push both to `main`**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git status --short
# Confirm only the 4 new files under "workspaces/DP - Staging - Prod/" and
# "workspaces/DP - Presentation - Prod/" show as untracked - if anything else
# appears, stop and check for local Desktop artifact noise before continuing
# (git stash push -u, never a destructive discard - see prior sessions).
git checkout main
git pull origin main
git add "workspaces/DP - Staging - Prod/Build_Silver_InTrans.Notebook" "workspaces/DP - Presentation - Prod/Build_Gold_PartsPromo.Notebook"
git commit -m "Author Prod-tier silver and gold notebooks

Build_Silver_InTrans.Notebook (DP - Staging - Prod) and
Build_Gold_PartsPromo.Notebook (DP - Presentation - Prod), cell code
byte-identical to their Dev-tier counterparts (post the hardcoded-path
fix) - only each notebook's own default_lakehouse METADATA binding
differs, pointing at its own tier's lakehouse.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin main
git checkout dev
```

**Note:** `git checkout main` here is safe and non-destructive (a branch switch, not a discard) since Task 4 Step 4 begins from a clean working tree confirmed in `git status --short` above. If that check shows unexpected local changes, resolve them (stash, per established pattern) before switching branches.

---

### Task 5: Add the Prod-tier Silver_InTrans shortcut ✅ DONE 2026-09-08

**Files:** none (Fabric portal action)

- [ ] **Step 1: Brian confirms both Prod workspaces picked up their notebooks**

In the Fabric portal: `DP - Staging - Prod` → Source control → **Update all**, then `DP - Presentation - Prod` → Source control → **Update all**. Confirm each notebook appears in its workspace afterward.

- [ ] **Step 2: Brian runs the Prod Silver notebook first**

Open `Build_Silver_InTrans.Notebook` in `DP - Staging - Prod` and run all cells. This must happen before Step 3, since the shortcut needs `Silver_InTrans` to already exist as a table to point at.

- [ ] **Step 3: Brian adds the Silver_InTrans shortcut to DP_Presentation (Prod)**

In the Fabric portal:
1. Open workspace `DP - Presentation - Prod` → lakehouse `DP_Presentation`
2. In the **Tables** section, select **...** → **New table shortcut** → **Microsoft OneLake**
3. Browse to: workspace `DP - Staging - Prod` → lakehouse `DP_Staging` → **Tables** → select `Silver_InTrans`
4. Keep the shortcut name as `Silver_InTrans`
5. Select **Create**

- [ ] **Step 4: Confirm it appears**

Report back once `Silver_InTrans` shows with a shortcut icon in `DP - Presentation - Prod`'s `DP_Presentation` Tables list.

---

### Task 6: Run the Prod Gold notebook ✅ DONE 2026-09-08

Output: `Silver_InTrans` 6,352,677 rows (>=2022-01-01), `dim_RepairOrder` 16,251 rows, `Fact_PartsPromo` 16,918 rows, `Fact_InTrans_AllPromo` 5,008,913 rows (>=2023-01-01) — matches Dev's counts exactly. All 11 known-bad orders present, RO 1985073 shows $627.64. This is the notebook's own sanity check, not the final proof — Task 7 is that proof.

**Files:** none (Fabric portal action)

- [ ] **Step 1: Brian runs it**

Open `Build_Gold_PartsPromo.Notebook` in `DP - Presentation - Prod` and run all cells. This produces `dim_RepairOrder`, `Fact_PartsPromo`, and `Fact_InTrans_AllPromo` in the Prod tier for the first time.

- [ ] **Step 2: Report back the notebook's own output**

Report the row counts and the notebook's own built-in verification cell output (the 11-known-bad-orders sanity check) — expect the same shape of result as the Dev tier's first run (11 rows found), though the actual numbers stand on their own here, not compared to Dev's.

---

### Task 7: Independently verify Prod output ✅ DONE 2026-09-08

Both scripts pass: silver shows 20,462,845 rows (0.73% below bronze's 20,612,638 — expected), 0 duplicate `(TransId, TransDatetime)` groups, 0 orphaned rows, 9 rows for RO 1985073. Gold matches `EquipRDB` exactly for all 11 known-bad orders (differences are 1e-12 to 1e-14 floating-point noise, not real mismatches). Committed `f45a86a4`. **The Prod tier is confirmed correct against ground truth — the same rigor as the original bug investigation, not just cross-checked against Dev.**

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans_prod.py`
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo_prod.py`

Same two independent checks used for Dev (Plan 3 Task 4-ish, Plan 4's verification), pointed at the Prod IDs. **Do not skip this because Dev already passed** — this is a fresh, independent build; nothing about Dev succeeding guarantees Prod's build ran cleanly.

- [ ] **Step 1: Write the Prod silver verification script**

```python
"""
DP SILVER INTRANS VERIFICATION - PROD TIER
============================================================================
Independent check of Silver_InTrans (DP - Staging - Prod) against the
bronze shortcut it was built from - confirms the Prod silver build didn't
lose or duplicate rows, same checks as the Dev tier's
verify_silver_intrans.py, run independently rather than assumed identical.

Run manually after Task 5, Step 2 confirms the Prod Silver notebook ran
successfully.
============================================================================
"""

import duckdb

DP_STAGING_PROD_WS_ID = "<DP - Staging - Prod workspace ID>"
DP_STAGING_PROD_LH_ID = "<DP_Staging Prod lakehouse ID>"
dp_base = f"abfss://{DP_STAGING_PROD_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_PROD_LH_ID}/Tables"

SILVER_INTRANS_TABLE = "Silver_InTrans"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row counts, bronze shortcut vs. silver table (Prod) ===")
bronze_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/InTrans')").df()
silver_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')").df()
print(f"Bronze (InTrans) row count: {bronze_count['cnt'][0]:,}")
print(f"Silver (Silver_InTrans) row count: {silver_count['cnt'][0]:,}")
diff = bronze_count['cnt'][0] - silver_count['cnt'][0]
pct = diff / bronze_count['cnt'][0] * 100
print(f"Difference: {diff:,} rows ({pct:.2f}%) — small (a few %) is expected/correct; large (10%+) means something's wrong.")

print("\n=== Check 2: no duplicate (TransId, TransDatetime) in Prod silver ===")
dupes = con.execute(f"""
    SELECT TransId, TransDatetime, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')
    GROUP BY TransId, TransDatetime
    HAVING COUNT(*) > 1
""").df()
print(f"Duplicate (TransId, TransDatetime) groups: {len(dupes)} (expect 0)")

print("\n=== Check 3: orphaned rows in Prod silver ===")
orphans = con.execute(f"""
    SELECT COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}') s
    LEFT JOIN delta_scan('{dp_base}/InTrans') b
        ON s.TransId = b.trans_id AND s.TransDatetime = b.Trans_Datetime
    WHERE b.trans_id IS NULL
""").df()
print(f"Orphaned silver rows (no matching bronze row): {orphans['cnt'][0]:,} (expect 0)")

print("\n=== Check 4: RO 1985073 through Prod silver ===")
ro_check = con.execute(f"""
    SELECT Branch, Franchise, RONumber, PartNumber, TransDatetime, SaleValue
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')
    WHERE RONumber = '1985073'
    ORDER BY TransDatetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 in Prod silver: {len(ro_check)} (expect 9)")
```

- [ ] **Step 2: Write the Prod gold verification script**

```python
"""
DP GOLD PARTS PROMO VERIFICATION - PROD TIER - THE ACTUAL PROOF
============================================================================
Compares the Prod-tier dim_RepairOrder (DP - Presentation - Prod) against
EquipRDB - the real source system - for all 11 repair orders confirmed
wrong in the original investigation. Same check as Plan 4's Dev
verification, run independently against the Prod build.

Run manually after Task 6, Step 1 confirms the Prod Gold notebook ran
successfully.
============================================================================
"""

import duckdb
import pyodbc
import pandas as pd

DP_PRESENTATION_PROD_WS_ID = "<DP - Presentation - Prod workspace ID>"
DP_PRESENTATION_PROD_LH_ID = "<DP_Presentation Prod lakehouse ID>"
dp_base = f"abfss://{DP_PRESENTATION_PROD_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_PROD_LH_ID}/Tables"

KNOWN_BAD_ROS = [
    "1986984", "1981941", "1984493", "1987016", "1986996",
    "1985073", "1979395", "1985078", "1985139", "1987116", "1987002",
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

placeholders = ",".join(f"'{r}'" for r in KNOWN_BAD_ROS)
gold = con.execute(f"""
    SELECT REF_NO, TotalPartsSales, TotalPartsCost, PartsCount
    FROM delta_scan('{dp_base}/dim_RepairOrder')
    WHERE REF_NO IN ({placeholders})
""").df()

cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()
cur.execute(f"""
    SELECT REF_NO, SUM(SALE_VAL) AS SRC_TotalPartsSales, SUM(COST_VAL) AS SRC_TotalPartsCost, COUNT(*) AS SRC_PartsCount
    FROM InTrans
    WHERE PART_NO NOT LIKE '*%'
      AND FRANCHISE != 'ZP'
      AND Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
src_rows = cur.fetchall()
source = pd.DataFrame.from_records(
    [tuple(r) for r in src_rows],
    columns=["REF_NO", "SRC_TotalPartsSales", "SRC_TotalPartsCost", "SRC_PartsCount"],
)
source["REF_NO"] = source["REF_NO"].astype(str)
source["SRC_TotalPartsSales"] = source["SRC_TotalPartsSales"].astype(float)
source["SRC_TotalPartsCost"] = source["SRC_TotalPartsCost"].astype(float)

gold["REF_NO"] = gold["REF_NO"].astype(str)
merged = source.merge(gold, on="REF_NO", how="outer", indicator=True)
merged["SalesDiff"] = (merged["SRC_TotalPartsSales"] - merged["TotalPartsSales"]).abs()
merged["CostDiff"] = (merged["SRC_TotalPartsCost"] - merged["TotalPartsCost"]).abs()

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 200)
print(f"Orders checked (Prod tier): {len(merged)} (expect 11)")
print(merged.to_string(index=False))

mismatches = merged[(merged["SalesDiff"] > 0.01) | (merged["CostDiff"] > 0.01) | (merged["_merge"] != "both")]
print(f"\nOrders with a real mismatch: {len(mismatches)} (expect 0)")
if len(mismatches):
    print(mismatches.to_string(index=False))
else:
    print("All 11 previously-wrong orders match the real source exactly - Prod tier confirmed.")
```

- [ ] **Step 3: Fill in placeholders and run both**

```
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans_prod.py"
python ".claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo_prod.py"
```
Expected: silver script shows 0 duplicate groups, 0 orphans, 9 rows for RO 1985073; gold script shows `Orders with a real mismatch: 0`.

**If either fails: stop.** Do not proceed to Task 8 with an unverified Prod build — this is the entire point of not just trusting Dev's result.

- [ ] **Step 4: Commit both scripts**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans_prod.py .claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo_prod.py
git commit -m "Add Prod-tier gold/silver verification scripts

Independently confirms the Prod-tier Silver_InTrans and dim_RepairOrder
builds are correct - same checks as the Dev tier, run separately rather
than assumed identical since this is a fresh, independent build.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Populate the Variable Library's Prod values and update the reference doc

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Brian updates the Variable Library**

In `DP - Staging - Dev` → `DP - Environment Config` Variable Library:
- Set `staging_lakehouse_id`'s `Prod` value to the real `DP_Staging` Prod lakehouse GUID (from Task 1)
- Set `presentation_lakehouse_id`'s `Prod` value to the real `DP_Presentation` Prod lakehouse GUID (from Task 1)
- Save, then commit to git (Source control → Commit)

- [ ] **Step 2: Verify the commit landed (agent-executed)**

```
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git fetch origin dev
git show "origin/dev:workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary/valueSets/Prod.json"
```
Expected: both variables show real GUIDs, not `not-yet-created`.

- [ ] **Step 3: Update the reference doc**

Add a new section to `docs/architecture/data-platform-workspaces.md`, after the existing `dim_RepairOrder` / `Fact_PartsPromo` section, matching its level of detail:

```markdown
## Prod tier

Stood up 2026-09-08 (DP Prod Tier plan). Same content as the Dev tier
above, built independently and verified independently - not copied.

| Lakehouse | Workspace | Lakehouse ID | Contents |
|---|---|---|---|
| DP_Staging | DP - Staging - Prod | `<fill in>` | `Tables/InTrans` — OneLake shortcut into `JD_EquipRDB_Production_Bronze.InTrans`, same source as Dev. `Tables/Silver_InTrans` — built by the Prod-tier `Build_Silver_InTrans.Notebook`, cell code identical to Dev's. |
| DP_Presentation | DP - Presentation - Prod | `<fill in>` | `Tables/Silver_InTrans` — OneLake shortcut into `DP_Staging (Prod).Silver_InTrans`. `Tables/dim_RepairOrder`, `Tables/Fact_PartsPromo`, `Tables/Fact_InTrans_AllPromo` — built by the Prod-tier `Build_Gold_PartsPromo.Notebook`. |

Verified 2026-09-08 via `verify_shortcut_prod.py`, `verify_silver_intrans_prod.py`,
`verify_gold_parts_promo_prod.py` (`.claude/queries/adhoc/dp-bronze-verify/`) - all
independent of the Dev tier's own verification. Bronze shortcut matches JD source
exactly; silver has 0 duplicate `(TransId, TransDatetime)` groups and 0 orphaned rows;
all 11 known-bad repair orders match `EquipRDB` source exactly in the Prod tier too.

**Variable Library `Prod` value set now populated:**

| Variable | Prod value |
|---|---|
| `staging_lakehouse_id` | `<fill in>` |
| `presentation_lakehouse_id` | `<fill in>` |

**Corrected during planning (not left as a later fix):** notebooks do NOT call
`notebookutils.variableLibrary` at runtime — confirmed via current Fabric docs that
this API doesn't support cross-workspace access, which every consumer here would have
needed. Both notebooks resolve their own lakehouse via `default_lakehouse` METADATA
binding (environment-specific, same category of per-tier difference as a `.tmdl`
connection string) and reach the one genuinely cross-workspace dependency
(Gold's need for Silver_InTrans) via a OneLake shortcut instead — zero hardcoded GUIDs
in either notebook's actual code, cell code identical between tiers. The Variable
Library remains the authoritative record of the 4 lakehouse GUIDs for humans and any
future consumer that *does* support cross-workspace resolution (a Fabric pipeline, or
an item-reference shortcut variable — both Fabric-documented but not used by this
plan).
```

Fill in the two lakehouse IDs (from Task 1) and the two Variable Library values (from Step 1) before saving.

- [ ] **Step 4: Commit the reference doc update**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Record DP Prod tier: lakehouses, verification results, Variable Library values

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both Prod workspaces are clean and correct**

```
export PATH="$HOME/.local/bin:$PATH"
fab get "DP - Staging - Prod.Workspace/DP_Staging.Lakehouse" -q "id"
fab get "DP - Presentation - Prod.Workspace/DP_Presentation.Lakehouse" -q "id"
```
Expected: both match what was recorded in Task 1 and written into the reference doc in Task 8.

- [ ] **Step 2: Confirm no stray uncommitted changes in either repo**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**Do not proceed to a future plan that repoints `RP - Parts Reports` at this Prod tier until every step above is checked off and both verification scripts in Task 7 show zero mismatches.**
