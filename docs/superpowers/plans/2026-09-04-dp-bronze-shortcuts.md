# DP Bronze Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Staging lakehouse in `DP - Staging - Dev` and a OneLake shortcut into `JD_EquipRDB_Production_Bronze.InTrans`, so the new backend has zero-copy access to a complete, correctly-captured `InTrans` table — the specific input Plan 3 (Silver Layer) needs to fix the original Parts Promo bug.

**Architecture:** One Lakehouse (`DP_Staging`) in `DP - Staging - Dev`, holding a single OneLake shortcut (`Tables/InTrans`) pointing at `JD_EquipRDB_Production_Bronze` in the `JD_FabricOneLake` workspace. Scoped to `InTrans` only and Dev only — per the design spec's medallion pattern, bronze is zero-copy shortcuts, not a re-ingestion pipeline, and per the rollout plan, everything gets proven in Dev before touching Prod. Other Equip-sourced tables and the non-Equip sources (`jdis_Part_Information`, `dim_EngagedAcres`, Commodity Code Groups) are explicitly out of scope here — nothing in the Parts Promo pilot needs them; add them in a later plan when a report actually requires them.

**Tech Stack:** Microsoft Fabric CLI (`fab`) for lakehouse creation, Fabric portal for the shortcut (no verified CLI syntax for cross-workspace Tables shortcuts — same reasoning as Plan 1's git-connect step), DuckDB for verification.

**Known execution pattern (established in Plan 1):** every mutating `fab`/git command gets auto-blocked by this session's sandbox classifier, but runs fine when Brian runs it directly in his own terminal. This plan skips the dispatch-subagent-then-get-blocked step from Plan 1 and hands mutating steps to Brian directly; verification, DuckDB checks, and git commits to `data-projects` are agent-executed.

---

### Task 1: Create the Staging lakehouse

**Files:** none (Fabric tenant infrastructure)

- [ ] **Step 1: Brian creates the lakehouse**

Run in your own terminal (not this session — same reason as Plan 1's workspace creation):
```
fab mkdir "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse"
```
Expected: command completes with no error.

- [ ] **Step 2: Verify (agent-executed)**

Once Brian confirms Step 1 is done, run:
```
fab get "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse" -q "id"
```
Expected: a GUID (the lakehouse ID). Record it — needed for Task 4.

---

### Task 2: Create the OneLake shortcut to `InTrans`

**Files:** none (Fabric portal action)

- [ ] **Step 1: Brian creates the shortcut**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev` → lakehouse `DP_Staging`
2. In the **Tables** section, select **...** → **New table shortcut** (or **New shortcut**, depending on the portal version) → **Microsoft OneLake**
3. Browse to: workspace `JD_FabricOneLake` → lakehouse `JD_EquipRDB_Production_Bronze` → **Tables** → select `InTrans`
4. Keep the shortcut name as `InTrans` (matches source, no reason to rename)
5. Select **Create** (or **Next** → **Create**, depending on the flow)

- [ ] **Step 2: Confirm it appears**

In the lakehouse's Tables list, `InTrans` should now show with a shortcut icon (distinct from a regular table). Report back once visible — no CLI/API check needed for this step, the DuckDB verification in Task 3 is the real proof.

---

### Task 3: Verify the shortcut is complete (agent-executed)

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py` (scratch verification script, kept in-repo since it documents exactly how this was checked — not a scratchpad throwaway)

- [ ] **Step 1: Write the verification script**

```python
"""
DP BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms the DP_Staging.InTrans OneLake shortcut (created in Plan 2, Task 2)
is a complete, accurate zero-copy reference to
JD_EquipRDB_Production_Bronze.InTrans — not a partial or stale copy.

Three checks:
1. Row count and date range match a direct query of the JD Bronze source
2. The specific RO 1985073 spot check (9 rows, matching the printed invoice)
   still resolves correctly through the shortcut — this is the exact case
   that proved JD Bronze doesn't have the original watermark-drop bug
   (see docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md)
3. JD's PL_EquipRDB_To_Fabric_Full pipeline is still refreshing nightly,
   so the shortcut's freshness is being maintained upstream

Run manually — not part of any scheduled pipeline.
============================================================================
"""

import duckdb

JD_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"      # JD_FabricOneLake workspace
JD_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"      # JD_EquipRDB_Production_Bronze lakehouse
jd_base = f"abfss://{JD_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_LH_ID}/Tables"

# Fill in after Task 1, Step 2:
DP_STAGING_WS_ID = "<DP - Staging - Dev workspace ID>"
DP_STAGING_LH_ID = "<DP_Staging lakehouse ID from Task 1>"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count / date range, JD source vs. DP shortcut ===")
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
print("\nDP_Staging shortcut:")
print(dp_stats.to_string())

match = (jd_stats["RowCount"][0] == dp_stats["RowCount"][0]
         and jd_stats["MaxTS"][0] == dp_stats["MaxTS"][0])
print(f"\nRow count and max timestamp match: {match}")

print("\n=== Check 2: RO 1985073 spot check through the shortcut ===")
ro_check = con.execute(f"""
    SELECT BRANCH, FRANCHISE, REF_NO, PART_NO, Trans_Datetime, SALE_VAL
    FROM delta_scan('{dp_base}/InTrans')
    WHERE REF_NO = '1985073'
    ORDER BY Trans_Datetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 through shortcut: {len(ro_check)} (expect 9, matching source)")

print("\n=== Check 3: is PL_EquipRDB_To_Fabric_Full still refreshing nightly? ===")
freshness = con.execute(f"""
    SELECT MAX(Trans_Datetime) AS MaxTS FROM delta_scan('{jd_base}/InTrans')
""").df()
print(freshness.to_string())
print("Compare MaxTS to today's date — should be within the last 1-2 days given the nightly Full reload.")
```

- [ ] **Step 2: Fill in the two placeholder IDs**

Replace `DP_STAGING_WS_ID` and `DP_STAGING_LH_ID` with the real values from Task 1, Step 2's output before running.

- [ ] **Step 3: Run it**

```
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py"
```

Expected: Check 1 shows identical row counts and max timestamps between JD source and the DP shortcut; Check 2 shows exactly 9 rows for RO 1985073 (the same 9 confirmed against the printed invoice during the original investigation); Check 3 shows a timestamp within the last couple of days.

**If any check fails** (row counts differ, RO 1985073 shows fewer than 9 rows, or the timestamp is stale/old): stop, do not proceed to Task 4. A shortcut should be an exact zero-copy mirror — any mismatch means something is wrong with the shortcut itself (wrong table selected, wrong lakehouse) or JD's own pipeline has stopped refreshing, and that needs to be understood before building anything on top of it.

- [ ] **Step 4: Commit the verification script**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py
git commit -m "Add DP bronze shortcut verification script

Confirms DP_Staging.InTrans (OneLake shortcut into
JD_EquipRDB_Production_Bronze) is a complete, accurate zero-copy
reference — row counts, RO 1985073 spot check, and source freshness.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Update the reference doc and Variable Library

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Update the reference doc**

Add the lakehouse ID (from Task 1) and shortcut details to the existing `docs/architecture/data-platform-workspaces.md` — a new row/section noting `DP_Staging` lakehouse, its ID, and the `InTrans` shortcut target (`JD_EquipRDB_Production_Bronze.InTrans`).

- [ ] **Step 2: Brian updates the Variable Library**

In `DP - Staging - Dev` → `DP - Environment Config` Variable Library:
- Set `staging_lakehouse_id` to the real lakehouse GUID (from Task 1) in **both** the Default value set and the `Dev` value set (leave `Prod`'s value as `not-yet-created` — the Prod staging lakehouse doesn't exist yet)
- Save

- [ ] **Step 3: Verify the Variable Library commit (agent-executed)**

Once Brian confirms he's committed the change to git:
```
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git fetch origin dev
git show "origin/dev:workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary/variables.json"
```
Expected: `staging_lakehouse_id`'s `"value"` field shows the real GUID, not `not-yet-created`.

- [ ] **Step 4: Commit the reference doc update**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Record DP_Staging lakehouse and InTrans shortcut

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
