# Parts Availability DP Feed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Progress:**
> - **Task 1 done 2026-10-14.**
>   - Live library: **"Test - Part Availability"**, drive `b!tcqE3JbkKUmlmTEjy7gj4XI0tGXDKMdFnHT3pX8sg5ypBE-GVUXlR6x3boZKPrXj`. Confirmed by Brian's screenshot: written hourly by the pipeline's SPN.
>   - Staging library: **"Parts Availability - Staging"**, drive `b!tcqE3JbkKUmlmTEjy7gj4XI0tGXDKMdFnHT3pX8sg5wFlfmiv7XBTq2VKzZHgJWh`.
>   - `.env.test` written (staging drive, `PARTS_LOOKUP_SOURCE=dp-dev`, no Teams webhook).
> - **Task 2 done 2026-10-14** (commits 070d0cfa, 1f965f4e, 0c8487c2). The code review tightened the plan's code:
>   - per pair, at most 10 keys missing from one side and at most 200 differing keys (instead of 500 bad keys);
>   - raw-key duplicates on either side fail;
>   - `ExtractedAtUtc` must be exactly one non-null value;
>   - unpaired LH loads fail on Prod;
>   - `compare_pair(con, lh_files, dp_files)` has a real-parquet test;
>   - usage exits 3, the default date is local, and compaction log files are skipped.
> - **Task 3 done 2026-10-14** (Brian, fabric-workspace-docs d27b316b).
>   - Bindings: ODBC `70ea8af2…`, Lakehouse `ec4b2ec8…`.
>   - First Dev load: 1,069,316 rows, one `ExtractedAtUtc` (20:17:22 UTC), 0 duplicate keys, 14 trailing-space part numbers.
>   - Table path: `Tables/PartsAvailability`.
>   - Brian also committed 3 phantom "Modified" dataflows (218a78c5): the only change was the trailing newline.
> - **Task 4 done** (0fa1ea91). Task 5 done (392102f7, 26da5d84).
>   - Review additions: functions prefixed `parts_`; an overlapping-run cause; AADSTS/"not authorized" classified as credentials; the Teams post points to the email.
>   - Plan Tasks 6 and 7 were updated to match: `parts_parse_trigger_time`, pipeline load timeout 20 min, `concurrency: 1`.
> - **Task 6 done** (6542484b).
>   - Dev IDs: `Notify_PartsAvailability` `db37de52-3bde-43ba-9330-a3f81a6a01f3`, `df_PartsAvailability_Raw` `6c7d76cf-2811-47a4-afb1-ceea562982ad`.
>   - The test alert was approved by Brian as is.
>   - DP - Presentation - Dev has 4 pre-existing workspace-only changes, not ours: Build_Gold_PartMasterHistory, Build_Gold_ServiceTimeSheets, DP_Presentation, Pipeline_DP_Refresh.
> - **Task 7 done** (dafcf50b).
>   - Dev pipeline `a5867491-fd58-4d58-b950-4755c48eaa35`.
>   - First Dev run: Load Succeeded in about 2¾ min.
> - **Task 8 done** (82d98a04, 48144dd9). The review added a guard: the deploy fails if a pipeline ID swap matches nothing (a stale Dev ID would point Prod at the Dev dataflow), plus an ordering test.
> - **Task 9 done 2026-10-14.** Dev pipeline runs at 15:50 and 16:50 CDT were paired with LH's loads from the same minute: PASS.
>
>   | Pair (CDT) | Rows LH / DP | Missing on one side | Rows that differ | Duplicate keys |
>   |---|---|---|---|---|
>   | 15:50 | 1,069,325 / 1,069,325 | 0 / 0 | 10 (qty) | 0 |
>   | 16:50 | 1,069,351 / 1,069,351 | 0 / 0 | **0** | 0 |
>
>   The Dev `Pipeline_DP_Refresh` items run for `df_PartsAvailability_Raw` finished `ok` (it also refreshes all Dev report models in `items` mode, ~14 min).
> - **Task 10 done** (ab4e6955). Task 11 code done (58477ee7); its run steps wait for Brian's Dev access grant.
> - **Task 12 done** (7b7bd08d, 57f02fca, 45070c57). The review added:
>   - pytz pinned;
>   - `last_published.json` records source and library, is read tolerantly and written atomically;
>   - `run_pipeline` branch tests;
>   - **threshold 120 min** (Brian).
> - **Task 14 done** (app 495f153 on `dev`): threshold 120, window 8–18. **PR not opened:** app `dev` also carries Brian's docs-only commit b9e7065, so Brian decides.
> - **Next:** Brian grants the SPN read on DP_Staging Dev, then the Task 11 run steps and Task 13.

**Goal:** Feed the Parts Availability app from a DP_Staging ODBC dataflow (`df_PartsAvailability_Raw` → `PartsAvailability`), loaded hourly by a small pipeline with a custom failure email, instead of LH_Master_Data. Retire the last LH schedule.

**Architecture:**
- **Fabric:** a Dataflow Gen2 in DP - Staging copies today's exact ODBC query and adds `ExtractedAtUtc`. `Pipeline_PartsAvailability` (DP - Presentation, rendered like `Pipeline_DP_Refresh`) runs it hourly, 06:50–16:50 on weekdays. On failure it runs `Notify_PartsAvailability`, which emails and posts to Teams through the DP notify machinery.
- **Gateway PC:** its Python pipeline (`.claude/queries/adhoc/parts-lookup-static-prototype/`) switches its source to DP, refuses bad tables, skips unchanged data, and stamps `_meta.json` with the data's real load time.
- **App:** `BUSINESS_END_HOUR` 20 → 18.

**Tech Stack:** Fabric Dataflow Gen2 (M), Fabric Data Pipelines (JSON rendered from Python), PySpark notebook (rendered), Python 3.13 (DuckDB, pandas, msal, requests), pytest, React/TypeScript + vitest (app).

**Spec:** `docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md`

**Repos and branches:**
| Repo | Path | Branch |
|---|---|---|
| data-projects (this repo) | `C:\Users\bfox\Documents\Git-Projects\data-projects` | `dev` (the Gateway PC runs a clone of `dev`) |
| fabric-workspace-docs | `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs` | `dev` → PR → `main` → "Deploy DP backend" |
| parts-lookup-app | `C:\Users\bfox\Documents\Git-Projects\parts-lookup-app` | `dev` → PR → `main` → `deploy.ps1` on the Server 2016 box |

**Rules (from CLAUDE.md):**
- **Commits:** stage only the named files; all three repos hold unrelated uncommitted work.
- **Dev workspaces:**
  - never `fab import` into Dev;
  - Git sync is the only writer: `python tools/dp-migration/git_sync.py <workspaceId>`;
  - a push to `dev` in fabric-workspace-docs also runs CI, which writes `Files/config/dp_refresh_dag.json` to Dev.
- **No deletes** of Fabric items, SharePoint files or Git content without Brian's explicit OK.
- **The live app, its SharePoint library and the Gateway PC's schedule are mission-critical.** Change them only in the cutover task, with Brian's OK. No heavy queries against anything live during business hours.
- **Commit trailer:** the `git commit -m "..."` commands below show only the subject. Add a second `-m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"` to every one.
- **Bash hook:** in this environment, Bash commands containing heredocs or some `python -c` strings are blocked by a false "printenv" hook. Put such code in a scratch `.py` file under the session scratchpad and run that.

**IDs used throughout:**
| Thing | ID |
|---|---|
| DP - Staging - Dev / DP_Staging (Dev) | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` / `876255e0-d462-4697-adc1-4a655f5bb101` |
| DP - Staging - Prod / DP_Staging (Prod) | `189e5c0a-548a-4feb-93d6-dda9ebbe96c1` / `6713bd45-a4ad-47e6-8bff-1bb0415e9784` |
| DP - Presentation - Dev / Prod | `73fd5443-240e-410a-990a-98827f32c087` / `7836042d-adb1-4846-b70d-bd42980054c5` |
| LH_Master_Data workspace / lakehouse | `b48cdb35-7ce3-46de-96df-d70db77649cb` / `3e74497b-8c51-4a1a-91a1-888c59118f48` |
| LH `df_InMaster_PartsLookup_Raw` | `ec4dd817-742a-4258-8ee3-002670c55101` |
| Gateway ODBC connection `dsn=EquipRDB64` | `70ea8af2-b529-4843-aee6-28297801fe71` (gateway cluster `d98a8d2c-d0df-4a42-a281-aab18e49dbd7`) |
| Gateway PC SPN "Parts Lookup Refresh Pipeline" | app `678f50be-0c5a-4e5b-8b46-6357dfb30a23`, object `b639885b-5efd-46ba-8077-2e36f6653936` |

---

## File map

**data-projects (`P` = `.claude/queries/adhoc/parts-lookup-static-prototype/`)**
| File | Change | Responsibility |
|---|---|---|
| `tools/dp-migration/parts_availability_check.py` | Create | Read-only DP-vs-LH comparison of hourly loads |
| `tools/dp-migration/test_parts_availability_check.py` | Create | Tests for its pure functions |
| `P/refresh_logic.py` | Create | Pure helpers: sources, guards, skip decision, `_meta` contents, upload order |
| `P/test_refresh_logic.py` | Create | Tests for `refresh_logic.py` |
| `P/config.py` | Modify | `PARTS_LOOKUP_ENV_FILE`, `SOURCE` |
| `P/extract.py` | Rewrite | Read the chosen source, run the guards, write `extract_meta.json` |
| `P/run_refresh.py` | Modify | Skip if unchanged, `_meta` = data time, record `last_published.json` |
| `P/upload.py` | Modify | Upload `_meta.json` last |
| `P/check_staleness.py` | Modify | Message and docstring for the data-age meaning |
| `P/verify_publish.py` | Create | Compare a library's published files with the local output |
| `P/.gitignore`, `P/.env.example` | Modify | New state files, test env file |
| `P/README.md`, `P/GATEWAY-PC-PIPELINE-DEPLOYMENT.md` | Modify | Docs |
| `projects/parts lookup tool - app/ARCHITECTURE.md` | Modify | Current architecture at the top |
| `docs/architecture/lh-master-data-retirement.md`, `docs/architecture/jd-bronze-raw-sources-catalog.md` | Modify | Docs |

**fabric-workspace-docs**
| File | Change | Responsibility |
|---|---|---|
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_PartsAvailability_Raw.Dataflow/` | Create (Brian in the UI, committed from the workspace) | The ODBC load |
| `deploy/dp_refresh_dag.json` | Modify | DAG item (`manual`), freshness check |
| `deploy/parts_alert.py` | Create | Pure: failure classification, next load time, alert text, messages |
| `deploy/test_parts_alert.py` | Create | Tests |
| `deploy/parts_alert_glue.py` | Create | Fabric-only body of `Notify_PartsAvailability` |
| `deploy/render_orchestrator.py` | Modify | New notebook kind and target; writes the new pipeline |
| `deploy/pipeline_render.py` | Modify | `parts_pipeline()`, Dev IDs |
| `deploy/test_render_orchestrator.py`, `deploy/test_pipeline_render.py` | Modify | Tests |
| `workspaces/DP - Presentation - Dev/Orchestration/Notify_PartsAvailability.Notebook/` | Generated | Notifier |
| `workspaces/DP - Presentation - Dev/Pipelines/Pipeline_PartsAvailability.DataPipeline/` | Generated | Pipeline |
| `deploy/prod_scope.py`, `deploy/test_prod_scope.py` | Modify | Always deploy the new pipeline and notifier |
| `deploy/deploy_backend.py`, `deploy/test_deploy_backend.py` | Modify | Notebooks before pipelines; dataflow and notifier ID swaps |
| `docs/TABLE-LINEAGE.md` | Regenerated | |
| `OPERATIONS-GUIDE.md`, `docs/TROUBLESHOOTING.md` | Modify | Runbook |

**parts-lookup-app**
| File | Change |
|---|---|
| `src/services/dataService.ts` | `BUSINESS_END_HOUR` 20 → 18, comments |
| `src/__tests__/dataService.test.ts` | Window tests |

---

## Task 1: Confirm the live library and create a staging library

**Why:** test publishes must never reach the library the app reads. The Gateway PC's `.env` names "Test - Part Availability" in `LIBRARY_BASE`, so that is probably the live library.

**Files:**
- Create (scratch, not committed): `<scratchpad>/list_drives.py`
- Create (gitignored): `P/.env.test`
- Modify: `P/.gitignore`

- [ ] **Step 1: List the site's document libraries**, using the pipeline's own service principal (read-only). Write `<scratchpad>/list_drives.py`:

```python
import os, sys
P = r"C:\Users\bfox\Documents\Git-Projects\data-projects\.claude\queries\adhoc\parts-lookup-static-prototype"
os.chdir(P)
sys.path.insert(0, P)
import requests
import config
from upload import GRAPH_BASE, get_access_token

token = get_access_token()
r = requests.get(f"{GRAPH_BASE}/sites/{config.SITE_ID}/drives", headers={"Authorization": f"Bearer {token}"}, timeout=30)
r.raise_for_status()
for d in r.json()["value"]:
    mark = "  <-- pipeline .env DRIVE_ID" if d["id"] == config.DRIVE_ID else ""
    print(f"{d['name']!r:45} {d['id']} {d['webUrl']}{mark}")
```

Run: `python <scratchpad>/list_drives.py`
Expected: the site's libraries, one marked as the pipeline's `DRIVE_ID`. Note its name.

- [ ] **Step 2: Ask Brian which drive the deployed app reads.** Either way works:
  - In the app's `.env` on the Server 2016 box (path in `parts-lookup-app/docs/WINDOWS-SERVER-2016-DEPLOYMENT.md`): `Select-String VITE_GRAPH_DRIVE_ID <path>\.env`.
  - Or open `https://go-parts.spitractor.com`, press F12, go to Network, search any part, and read `/drives/<id>/` in the request URL.

  Record the answer in the plan's progress note. **Expected:** it equals the pipeline's `DRIVE_ID`. If it doesn't, stop and tell Brian: the Gateway PC would be publishing somewhere the app doesn't read.

- [ ] **Step 3: Brian creates the staging library.** On the same SharePoint site (South Plains Implement - Report Site): New → Document library → name **`Parts Availability - Staging`**. Since it's in the same site, the service principal's existing site permission covers it.

- [ ] **Step 4: Re-run Step 1** and note the new library's drive ID.

- [ ] **Step 5: Write `P/.env.test`** with a scratch script, so no secret is printed. Write `<scratchpad>/make_env_test.py`:

```python
import re, sys
from pathlib import Path
P = Path(r"C:\Users\bfox\Documents\Git-Projects\data-projects\.claude\queries\adhoc\parts-lookup-static-prototype")
staging_drive = sys.argv[1]
lines = []
for line in (P / ".env").read_text(encoding="utf-8").splitlines():
    key = line.split("=", 1)[0].strip()
    if key == "DRIVE_ID":
        line = f"DRIVE_ID={staging_drive}"
    elif key == "LIBRARY_BASE":
        line = "LIBRARY_BASE=https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite/Parts%20Availability%20%20Staging"
    elif key == "TEAMS_WEBHOOK_URL":
        continue  # test runs must never post to the live alerts channel
    lines.append(line)
lines.append("PARTS_LOOKUP_SOURCE=dp-dev")
(P / ".env.test").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("wrote .env.test with keys:", [l.split("=", 1)[0] for l in lines if "=" in l])
```

Run: `python <scratchpad>/make_env_test.py <staging drive id>`
Expected: `wrote .env.test with keys: ['TENANT_ID', 'CLIENT_ID', 'CLIENT_SECRET', 'SITE_ID', 'DRIVE_ID', 'LIBRARY_BASE', 'PARTS_LOOKUP_SOURCE']`. There must be no `TEAMS_WEBHOOK_URL`. (`LIBRARY_BASE` is only a label; check the real URL in Step 4's output and correct it if it differs.)

- [ ] **Step 6: Gitignore the new local files.** Replace `P/.gitignore` with:

```
*.parquet
output*/
.env
.env.*
!.env.example
refresh.log
refresh.lock
extract_meta.json
last_published.json
```

Run: `git -C c:/Users/bfox/Documents/Git-Projects/data-projects status --short -- ".claude/queries/adhoc/parts-lookup-static-prototype"`
Expected: `.gitignore` modified; `.env.test` not listed.

- [ ] **Step 7: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/.gitignore"
git commit -m "Parts Lookup pipeline: ignore test env file and new state files"
```

---

## Task 2: DP-vs-LH comparison tool

**Files:**
- Create: `tools/dp-migration/parts_availability_check.py`
- Test: `tools/dp-migration/test_parts_availability_check.py`

- [ ] **Step 1: Write the failing tests** in `tools/dp-migration/test_parts_availability_check.py`:

```python
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from parts_availability_check import full_loads, pair_loads, persistent_keys, verdict  # noqa: E402


def ms(h, m):
    return int(datetime(2026, 10, 14, h, m, tzinfo=timezone.utc).timestamp() * 1000)


def test_full_loads_keeps_whole_table_replacements_only():
    entries = [
        (5, {"operation": "ReplaceTable"}, None), (5, None, {"path": "a.parquet", "modificationTime": ms(12, 52)}),
        (5, None, {"path": "b.parquet", "modificationTime": ms(12, 52)}),
        (6, {"operation": "OPTIMIZE", "timestamp": ms(13, 0)}, None), (6, None, {"path": "c.parquet"}),
        (7, {"operation": "CREATE TABLE AS SELECT", "timestamp": ms(13, 52)}, None), (7, None, {"path": "d.parquet"}),
    ]
    loads = full_loads(entries)
    assert [l["version"] for l in loads] == [5, 7]
    assert loads[0]["adds"] == ["a.parquet", "b.parquet"]
    assert loads[0]["ts"] == datetime(2026, 10, 14, 12, 52, tzinfo=timezone.utc)
    assert loads[1]["ts"] == datetime(2026, 10, 14, 13, 52, tzinfo=timezone.utc)


def load(v, h, m):
    return {"version": v, "ts": datetime(2026, 10, 14, h, m, tzinfo=timezone.utc), "adds": []}


def test_pair_loads_matches_nearest_within_gap_and_uses_each_dp_load_once():
    lh = [load(1, 12, 52), load(2, 13, 52), load(3, 14, 52)]
    dp = [load(10, 11, 52), load(11, 12, 53), load(12, 13, 49), load(13, 15, 30)]
    pairs = pair_loads(lh, dp, max_gap_minutes=10)
    assert [(a["version"], b["version"]) for a, b in pairs] == [(1, 11), (2, 12)]


def test_persistent_keys_needs_two_consecutive_pairs():
    r = [{"bad_keys": {("1", "D", "A"), ("1", "D", "B")}},
         {"bad_keys": {("1", "D", "B")}},
         {"bad_keys": {("1", "D", "A")}}]
    assert persistent_keys(r) == {("1", "D", "B")}


def test_verdict():
    assert verdict([])[0] == 2
    ok = [{"bad_keys": {("1", "D", "A")}}, {"bad_keys": set()}]
    assert verdict(ok) == (0, [])
    code, problems = verdict([{"bad_keys": {("1", "D", "A")}}, {"bad_keys": {("1", "D", "A")}}])
    assert code == 1 and "1 key" in problems[0]
    big = {("1", "D", str(i)) for i in range(501)}
    code, problems = verdict([{"bad_keys": big}])
    assert code == 1 and "501" in problems[0]
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd c:/Users/bfox/Documents/Git-Projects/data-projects && python -m pytest tools/dp-migration/test_parts_availability_check.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'parts_availability_check'`.

- [ ] **Step 3: Write `tools/dp-migration/parts_availability_check.py`**

```python
"""Read-only: compare DP's PartsAvailability loads with LH_Master_Data's InMaster_PartsLookup_Raw loads.

Usage: python parts_availability_check.py <dev|prod> [YYYY-MM-DD]   (default: today; the date is UTC)

Both tables are whole-table Replace loads of the same ODBC query (LH weekdays 07:50-16:50 hourly; DP Prod
06:50-16:50 via Pipeline_PartsAvailability; DP Dev by hand). Every Delta commit is one complete load, so
each LH load of the day is paired with the DP load committed within 10 minutes of it, and the two snapshots
are compared on the raw key Branch + Franchise + PartNumber. There is no trimming: trailing-space twin part
numbers are real, separate rows.
Pass: no key is missing from one side or different in two consecutive pairs (one pair alone can differ by
a handful of rows, because the two queries run seconds apart), and no pair has more than 500 bad keys.
Exit 0 pass, 1 fail, 2 no pairs found.
Spec: docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md
"""
import json
import sys
from datetime import date, datetime, timedelta, timezone

import duckdb

ONELAKE = "abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"
LH = ONELAKE.format(ws="b48cdb35-7ce3-46de-96df-d70db77649cb", lh="3e74497b-8c51-4a1a-91a1-888c59118f48",
                    table="InMaster_PartsLookup_Raw")
DP = {"dev": ONELAKE.format(ws="ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", lh="876255e0-d462-4697-adc1-4a655f5bb101",
                            table="PartsAvailability"),
      "prod": ONELAKE.format(ws="189e5c0a-548a-4feb-93d6-dda9ebbe96c1", lh="6713bd45-a4ad-47e6-8bff-1bb0415e9784",
                             table="PartsAvailability")}
KEY = ["Branch", "Franchise", "PartNumber"]
COLUMNS = ["Description", "Bin", "SuperFrom", "SuperTo", "VendorCode", "SellPrice1", "Comments",
           "OnHandQty", "PendingQty", "OnOrder", "BinQty"]
MAX_GAP_MINUTES = 10
MAX_BAD_KEYS_PER_PAIR = 500


def full_loads(entries):
    """entries: (version, commitInfo dict or None, add dict or None), one per _delta_log line.
    Returns [{"version", "ts" (aware UTC), "adds"}] for commits that replaced the whole table, oldest first."""
    by_version = {}
    for version, commit, add in entries:
        c = by_version.setdefault(version, {"version": version, "op": "", "ts": None, "adds": []})
        if commit:
            c["op"] = commit.get("operation") or c["op"]
            c["ts"] = commit.get("timestamp") or c["ts"]
        if add:
            c["adds"].append(add["path"])
            c["ts"] = c["ts"] or add.get("modificationTime")
    out = []
    for version in sorted(by_version):
        c = by_version[version]
        op = c["op"].upper()
        if c["adds"] and c["ts"] and ("REPLACE" in op or "CREATE" in op):
            out.append({"version": version, "ts": datetime.fromtimestamp(c["ts"] / 1000, timezone.utc),
                        "adds": c["adds"]})
    return out


def pair_loads(lh, dp, max_gap_minutes=MAX_GAP_MINUTES):
    """[(lh_load, dp_load)]: each LH load with the nearest unused DP load committed within the gap."""
    pairs, used = [], set()
    gap = timedelta(minutes=max_gap_minutes)
    for a in lh:
        candidates = [b for b in dp if b["version"] not in used and abs(b["ts"] - a["ts"]) <= gap]
        if candidates:
            best = min(candidates, key=lambda b: abs(b["ts"] - a["ts"]))
            pairs.append((a, best))
            used.add(best["version"])
    return pairs


def persistent_keys(results):
    """Keys that are bad (one-sided or different) in two consecutive pairs."""
    out = set()
    for a, b in zip(results, results[1:]):
        out |= a["bad_keys"] & b["bad_keys"]
    return out


def verdict(results):
    """(exit code, problems)."""
    if not results:
        return 2, ["no LH/DP load pairs found for that date"]
    problems = []
    stuck = persistent_keys(results)
    if stuck:
        problems.append(f"{len(stuck)} key(s) wrong in two consecutive pairs, e.g. {sorted(stuck)[:5]}")
    for i, r in enumerate(results):
        if len(r["bad_keys"]) > MAX_BAD_KEYS_PER_PAIR:
            problems.append(f"pair {i + 1}: {len(r['bad_keys'])} bad keys (limit {MAX_BAD_KEYS_PER_PAIR})")
    return (1 if problems else 0), problems


def connect():
    con = duckdb.connect()
    con.sql("INSTALL azure; LOAD azure; INSTALL delta; LOAD delta;")
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli', ACCOUNT_NAME 'onelake');")
    con.sql("SET TimeZone = 'UTC'")
    return con


def log_entries(con, table):
    rows = con.execute(
        f"SELECT filename, commitInfo, add FROM read_json('{table}/_delta_log/*.json', filename=true, "
        f"format='newline_delimited', columns={{commitInfo: 'JSON', add: 'JSON'}})").fetchall()
    return [(int(fn.rsplit("/", 1)[1].split(".")[0]), json.loads(ci) if ci else None, json.loads(a) if a else None)
            for fn, ci, a in rows]


def compare_pair(con, lh_load, dp_load, dp_table):
    con.execute(f"CREATE OR REPLACE TABLE l AS SELECT * FROM read_parquet({[f'{LH}/{p}' for p in lh_load['adds']]!r})")
    con.execute(f"CREATE OR REPLACE TABLE d AS SELECT * FROM read_parquet({[f'{dp_table}/{p}' for p in dp_load['adds']]!r})")
    on = " AND ".join(f"l.{k} IS NOT DISTINCT FROM d.{k}" for k in KEY)
    keys = ", ".join(f"l.{k}" for k in KEY)
    dkeys = ", ".join(f"d.{k}" for k in KEY)
    only_lh = set(con.execute(f"SELECT {keys} FROM l ANTI JOIN d ON {on}").fetchall())
    only_dp = set(con.execute(f"SELECT {dkeys} FROM d ANTI JOIN l ON {on}").fetchall())
    differs = " OR ".join(f"l.{c} IS DISTINCT FROM d.{c}" for c in COLUMNS)
    diff = set(con.execute(f"SELECT {keys} FROM l JOIN d ON {on} WHERE {differs}").fetchall())
    counts = con.execute("SELECT " + ", ".join(f"count(*) FILTER (WHERE l.{c} IS DISTINCT FROM d.{c})" for c in COLUMNS)
                         + f" FROM l JOIN d ON {on}").fetchone()
    extracted = con.execute("SELECT DISTINCT ExtractedAtUtc FROM d").fetchall()
    return {"lh_ts": lh_load["ts"], "dp_ts": dp_load["ts"],
            "lh_rows": con.execute("SELECT count(*) FROM l").fetchone()[0],
            "dp_rows": con.execute("SELECT count(*) FROM d").fetchone()[0],
            "dp_dup_keys": con.execute(f"SELECT count(*) FROM (SELECT {', '.join(KEY)} FROM d GROUP BY ALL "
                                       "HAVING count(*) > 1)").fetchone()[0],
            "extracted_at": [e[0] for e in extracted],
            "only_lh": only_lh, "only_dp": only_dp, "diff": diff,
            "col_counts": {c: n for c, n in zip(COLUMNS, counts) if n},
            "bad_keys": only_lh | only_dp | diff}


def main(tier, day):
    sys.stdout.reconfigure(encoding="utf-8")
    con = connect()
    lh = [x for x in full_loads(log_entries(con, LH)) if x["ts"].date() == day]
    dp = [x for x in full_loads(log_entries(con, DP[tier])) if x["ts"].date() == day]
    print(f"{day} (UTC): LH loads {len(lh)}, DP {tier} loads {len(dp)}")
    results = []
    for a, b in pair_loads(lh, dp):
        r = compare_pair(con, a, b, DP[tier])
        results.append(r)
        print(f"  LH {a['ts']:%H:%M} v{a['version']} vs DP {b['ts']:%H:%M} v{b['version']}: rows {r['lh_rows']:,} / "
              f"{r['dp_rows']:,}; only LH {len(r['only_lh'])}, only DP {len(r['only_dp'])}, differing {len(r['diff'])} "
              f"{r['col_counts'] or ''}; DP dup keys {r['dp_dup_keys']}; ExtractedAtUtc {r['extracted_at']}")
    code, problems = verdict(results)
    for p in problems:
        print("PROBLEM:", p)
    print("PASS" if code == 0 else "FAIL")
    return code


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in DP:
        sys.exit(__doc__)
    d = date.fromisoformat(sys.argv[2]) if len(sys.argv) == 3 else datetime.now(timezone.utc).date()
    sys.exit(main(sys.argv[1], d))
```

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `python -m pytest tools/dp-migration/test_parts_availability_check.py -q`
Expected: `4 passed`.

- [ ] **Step 5: Smoke-test the LH side.** The DP table doesn't exist yet, so this proves only the log reading. Write `<scratchpad>/lh_loads.py`:

```python
import sys
sys.path.insert(0, r"C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration")
from parts_availability_check import LH, connect, full_loads, log_entries
for x in full_loads(log_entries(connect(), LH))[-5:]:
    print(x["version"], x["ts"], len(x["adds"]))
```

Run: `python <scratchpad>/lh_loads.py`
Expected: the last 5 LH loads, about an hour apart, each with 1–3 files (e.g. `428 2026-10-13 15:50:55+00:00 2`).

- [ ] **Step 6: Add a line to `tools/dp-migration/README.md`** under the tool list:

```markdown
- `parts_availability_check.py <dev|prod> [YYYY-MM-DD]`: read-only; pairs each LH `InMaster_PartsLookup_Raw` load with DP's `PartsAvailability` load from the same minute and compares them on the raw key (Parts Availability plan, Task 2). Exit 0 pass, 1 fail, 2 no pairs.
```

- [ ] **Step 7: Commit**

```bash
git add tools/dp-migration/parts_availability_check.py tools/dp-migration/test_parts_availability_check.py tools/dp-migration/README.md
git commit -m "Add parts_availability_check.py: DP vs LH hourly load comparison"
```

---

## Task 3: The dataflow in DP - Staging - Dev (Brian, in the UI)

**Why the UI:** new Dataflow Gen2 items in this repo are created in the Dev workspace and committed from it (precedent: `df_JDPriceFiles_Raw`), so Fabric generates `queryMetadata.json` and the connection bindings itself.

**Files:** created by Fabric in `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_PartsAvailability_Raw.Dataflow/` (`mashup.pq`, `queryMetadata.json`, `.platform`).

- [ ] **Step 1: Brian creates the dataflow.** In DP - Staging - Dev, folder `Raw Data - Dataflows`:
  1. New → Dataflow Gen2, named `df_PartsAvailability_Raw`.
  2. Get data → Blank query → Advanced editor; paste the M below and rename the query `PartsAvailability`.
  3. When asked for a connection, pick the existing **`dsn=EquipRDB64`** gateway connection.

```
/*
============================================================================
Query: PartsAvailability
Dataflow: df_PartsAvailability_Raw
Location: DP - Staging -> Raw Data - Dataflows
============================================================================

PURPOSE: Hourly cross-branch part availability for the Parts Availability
app (https://go-parts.spitractor.com). The Gateway PC's refresh pipeline
(data-projects .claude/queries/adhoc/parts-lookup-static-prototype/) reads
this table and publishes it to SharePoint as static files. It replaces
LH_Master_Data's df_InMaster_PartsLookup_Raw, whose SQL is copied here
exactly so the parallel run compares like with like.

GRAIN: One row per Branch + Franchise + PartNumber (VendorCode not null).
The raw key has no duplicates. Do NOT trim or upper-case PartNumber:
trailing-space twin part numbers are real, separate records.

SOURCE: SQL Anywhere (ODBC dsn=EquipRDB64 via SPI-Data-Gateway), InMaster.

WHY ODBC AND NOT JD BRONZE (measured 2026-10-13/14):
- Cost: a JD Incremental run costs ~6,500 CU(s) (it copies all 19 tables);
  this load costs ~750. Hourly Bronze would cost ~9-10x more.
- Accuracy: Pending_Qty changes do not bump InMaster.ModifiedDate, so JD's
  watermark misses them until the midnight Full load; 9 branch-92 rows
  were missing from Bronze in the aligned test.

BUSINESS RULES (Ben, 2026-07-15):
- VendorCode not null = "carried through a vendor".
- Branches 5 and 97 excluded.
- BinQty = ON_HAND_QTY - Pending_Qty (validated 99.94% against jdis BinQty).
- Comments = NOTE. OnOrder = OS_ORDER_QTY (on order with the vendor).

ExtractedAtUtc: one UTC timestamp per load (taken once, before the query).
The Gateway PC publishes it as the app's "Data as of" time and skips the
upload when it hasn't changed. The DP morning email's freshness check
watches it (an expired or disabled schedule).

No try/otherwise around Odbc.Query on purpose: the real gateway/ODBC error
must reach Pipeline_PartsAvailability's failure email.

LOADED BY: Pipeline_PartsAvailability (DP - Presentation), weekdays
06:50-16:50 hourly in Prod. Not part of Pipeline_DP_Refresh (cadence
"manual" in dp_refresh_dag.json).
============================================================================
*/
let
    ExtractedAtUtc = DateTimeZone.RemoveZone(DateTimeZone.UtcNow()),
    SQL = "
        SELECT
            BRANCH          AS Branch,
            FRANCHISE       AS Franchise,
            PART_NO         AS PartNumber,
            PART_DESC       AS Description,
            BIN_LOCATION    AS Bin,
            SUPER_FROM      AS SuperFrom,
            SUPER_TO        AS SuperTo,
            VENDOR_CODE     AS VendorCode,
            SELL_PRICE1     AS SellPrice1,
            NOTE            AS Comments,
            ON_HAND_QTY     AS OnHandQty,
            Pending_Qty     AS PendingQty,
            OS_ORDER_QTY    AS OnOrder
        FROM InMaster
        WHERE VENDOR_CODE IS NOT NULL
          AND BRANCH NOT IN ('5', '97')
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    AddBinQty = Table.AddColumn(Source, "BinQty", each [OnHandQty] - [PendingQty], Int64.Type),
    TypedTable = Table.TransformColumnTypes(AddBinQty, {
        {"Branch", type text},
        {"Franchise", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"Bin", type text},
        {"SuperFrom", type text},
        {"SuperTo", type text},
        {"VendorCode", type text},
        {"SellPrice1", type number},
        {"Comments", type text},
        {"OnHandQty", Int64.Type},
        {"PendingQty", Int64.Type},
        {"OnOrder", Int64.Type},
        {"BinQty", Int64.Type}
    }),
    AddExtractedAt = Table.AddColumn(TypedTable, "ExtractedAtUtc", each ExtractedAtUtc, type datetime)
in
    AddExtractedAt
```

- [ ] **Step 2: Brian sets the destination.** Add data destination → Lakehouse → DP - Staging - Dev / **DP_Staging** → New table **`PartsAvailability`** → Update method **Replace** → automatic settings on. Check that the 15 columns map with types text/number/int64/datetime. Publish, and let the first refresh run.

- [ ] **Step 3: Brian commits from the workspace.** DP - Staging - Dev → Source control → commit `df_PartsAvailability_Raw` to `dev`, with message "Add df_PartsAvailability_Raw (Parts Availability feed)".

- [ ] **Step 4: Pull and review**

Run: `cd c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs && git pull --ff-only origin dev && cat "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_PartsAvailability_Raw.Dataflow/queryMetadata.json"`

Expected:
- `connections` has `"path": "dsn=EquipRDB64"` with `DatasourceId` `70ea8af2-b529-4843-aee6-28297801fe71`, and a Lakehouse connection.
- `mashup.pq`'s destination navigates `workspaceId = "ab15d64d-…"`, `lakehouseId = "876255e0-…"`, `Id = "PartsAvailability"`. These are the IDs `parameter.yml` already swaps for Prod (`item_type` includes `Dataflow`).
- The SQL text in `mashup.pq` is identical to the live LH query. Compare by eye with `.claude/queries/raw-tables/InMaster_PartsLookup_Raw.pq` in data-projects; the LH header copy is in the spec.

- [ ] **Step 5: Check the Dev table** (read-only). Write `<scratchpad>/dev_table.py`:

```python
import duckdb
T = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/PartsAvailability"
con = duckdb.connect()
con.sql("INSTALL azure; LOAD azure; INSTALL delta; LOAD delta;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli', ACCOUNT_NAME 'onelake');")
con.sql("SET TimeZone = 'UTC'")
con.sql(f"CREATE VIEW t AS SELECT * FROM delta_scan('{T}')")
print(con.sql("DESCRIBE t"))
print(con.sql("SELECT count(*) AS n, count(DISTINCT ExtractedAtUtc) AS loads, min(ExtractedAtUtc), max(ExtractedAtUtc) FROM t"))
print(con.sql("SELECT count(*) AS dup_keys FROM (SELECT Branch, Franchise, PartNumber FROM t GROUP BY ALL HAVING count(*) > 1)"))
```

Run: `python <scratchpad>/dev_table.py`
Expected:
- 15 columns, with `ExtractedAtUtc` a TIMESTAMP;
- `n` about 1,069,000;
- `loads` = 1;
- `dup_keys` = 0.

If the table path isn't found, try `Tables/dbo/PartsAvailability`, and use whichever works in Tasks 2, 10 and 15. (Today's DP_Staging tables live at `Tables/<name>`.)

No commit: Fabric committed the item.

---

## Task 4: DAG entry, freshness check, lineage

**Files:**
- Modify: `fabric-workspace-docs/deploy/dp_refresh_dag.json`
- Regenerate: `fabric-workspace-docs/docs/TABLE-LINEAGE.md`

- [ ] **Step 1: Add the item.** In `deploy/dp_refresh_dag.json`, add this object to `items`, directly after the `df_Dim_BranchUserAccess` object:

```json
    {
      "name": "df_PartsAvailability_Raw",
      "type": "dataflow",
      "workspace": "staging",
      "tier": "staging",
      "cadence": "manual",
      "dependsOn": [],
      "produces": [
        "PartsAvailability"
      ]
    },
```

- [ ] **Step 2: Add the freshness check.** Append to `orchestrator.freshnessChecks`, after the JD National Change Report entry:

```json
      {
        "table": "PartsAvailability",
        "column": "ExtractedAtUtc",
        "maxAgeDays": 4,
        "label": "Parts Availability hourly load (Pipeline_PartsAvailability schedule in DP - Presentation)"
      }
```

- [ ] **Step 3: Validate**

Run: `cd c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs && python deploy/dag_check.py && python -m pytest deploy -q && python deploy/hygiene_audit.py && python deploy/table_lineage.py`
Expected:
- `dag_check` OK, with the item count one higher;
- all tests pass;
- hygiene OK;
- `docs/TABLE-LINEAGE.md` regenerated with a `PartsAvailability` row produced by `df_PartsAvailability_Raw`.

- [ ] **Step 4: Commit and push**

```bash
git add deploy/dp_refresh_dag.json docs/TABLE-LINEAGE.md
git commit -m "DAG: df_PartsAvailability_Raw (manual cadence) + PartsAvailability freshness check"
git push origin dev
```

Then run `python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/wait_ci.py c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs`.
Expected: exit 0. The CI run writes the new config to Dev `Files/config/dp_refresh_dag.json`.

---

## Task 5: Failure-alert logic (pure, tested)

**Files:**
- Create: `fabric-workspace-docs/deploy/parts_alert.py`
- Test: `fabric-workspace-docs/deploy/test_parts_alert.py`

- [ ] **Step 1: Write the failing tests** in `deploy/test_parts_alert.py`:

```python
# deploy/test_parts_alert.py
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from parts_alert import (PARTS_DEFAULT_CAUSE, classify_failure, next_load, parse_trigger_time,  # noqa: E402
                         parts_failure_alert, parts_messages)

NOTIFY = {"recipients": {"Prod": {"summary": ["s@x.com"], "alert": ["a@x.com"], "teams": ["t@x.com"]},
                         "Dev": {"summary": ["s@x.com"], "alert": ["a@x.com"], "teams": []}}}


def test_classify_credentials_before_gateway():
    cause, _ = classify_failure("The credentials provided for the Odbc source are invalid.")
    assert "sign-in" in cause


def test_classify_gateway():
    cause, action = classify_failure("DM_GWPipeline_Gateway_MashupDataAccessError: ODBC: ERROR [08001] ...")
    assert "gateway" in cause and "SPI00T4022W11" in action


def test_classify_timeout_and_capacity():
    assert "out of time" in classify_failure("Activity timed out after 00:30:00")[0]
    assert "capacity" in classify_failure("Request was throttled: capacity limit exceeded")[0]


def test_classify_unknown_falls_back():
    assert classify_failure("Something went wrong, please try again later.") == PARTS_DEFAULT_CAUSE
    assert classify_failure("") == PARTS_DEFAULT_CAUSE
    assert classify_failure(None) == PARTS_DEFAULT_CAUSE


def test_next_load_same_day_next_day_and_weekend():
    assert next_load(datetime(2026, 10, 14, 9, 55)) == datetime(2026, 10, 14, 10, 50)   # Wednesday
    assert next_load(datetime(2026, 10, 14, 6, 0)) == datetime(2026, 10, 14, 6, 50)
    assert next_load(datetime(2026, 10, 14, 16, 50)) == datetime(2026, 10, 15, 6, 50)  # exactly at the last load
    assert next_load(datetime(2026, 10, 16, 17, 0)) == datetime(2026, 10, 19, 6, 50)   # Friday evening -> Monday


def test_parse_trigger_time():
    assert parse_trigger_time("2026-10-14T14:50:00.1234567Z") == datetime(2026, 10, 14, 14, 50, tzinfo=timezone.utc)
    assert parse_trigger_time("10/14/2026 14:50:00") is None
    assert parse_trigger_time("") is None


def test_alert_text():
    a = parts_failure_alert("Prod", "Activity timed out", "run-1", datetime(2026, 10, 14, 9, 50),
                            datetime(2026, 10, 14, 9, 58))
    assert a["subject"] == "🔴 [Prod] Parts Availability: the 09:50 data load failed"
    assert "What happened" in a["html"] and "Likely cause" in a["html"] and "What to do" in a["html"]
    assert "10:50" in a["html"] and "run-1" in a["html"] and "Activity timed out" in a["html"]
    assert a["teams_text"].startswith(a["subject"]) and "Next try 10:50" in a["teams_text"]


def test_alert_escapes_html_and_names_next_day():
    a = parts_failure_alert("Prod", "<script>x</script>", "r", datetime(2026, 10, 16, 16, 50),
                            datetime(2026, 10, 16, 16, 58))
    assert "<script>" not in a["html"] and "&lt;script&gt;" in a["html"]
    assert "Mon 10/19 06:50" in a["html"]


def test_messages_go_to_alert_and_teams_only():
    a = parts_failure_alert("Prod", "x", "r", datetime(2026, 10, 14, 9, 50), datetime(2026, 10, 14, 9, 58))
    msgs = parts_messages(a, NOTIFY, "Prod")
    assert [(m["to"], m["importance"]) for m in msgs] == [(["a@x.com"], "high"), (["t@x.com"], "normal")]
    assert len(parts_messages(a, NOTIFY, "Dev")) == 1   # empty Teams list is dropped
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs && python -m pytest deploy/test_parts_alert.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'parts_alert'`.

- [ ] **Step 3: Write `deploy/parts_alert.py`.** Stdlib only, with no imports from other deploy modules. It's rendered into the notebook after `notify_core`/`notify_send`, so every name it defines starts with `parts_`/`PARTS_` or is unique.

```python
# deploy/parts_alert.py
"""Pure failure-alert logic for Pipeline_PartsAvailability (rendered into Notify_PartsAvailability).

Pipeline_PartsAvailability loads df_PartsAvailability_Raw (Equip InMaster over ODBC -> DP_Staging
PartsAvailability) hourly, weekdays 06:50-16:50 Central; the Parts Availability app's Gateway PC pipeline
publishes that table. When the load fails (after the activity's one retry), Notify_PartsAvailability emails
the alert list (high importance) and posts to the Teams channel: what happened, the likely cause, what to do.
Spec: data-projects/docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md
"""
import html as _parts_html
import re as _parts_re
from datetime import datetime, timedelta, timezone

PARTS_LOAD_TIMES = [(h, 50) for h in range(6, 17)]  # 06:50 ... 16:50 Central, Monday-Friday

# (lower-case substrings, likely cause, what to do). First match wins, so the more specific causes come first:
# a credentials error mentions "Odbc" too.
PARTS_CAUSES = [
    (("credential", "unauthorized", "forbidden", "access denied", "accessdenied", "login failed", "password"),
     "The connection's sign-in was refused.",
     "Open Fabric > Settings > Manage connections and gateways, find the dsn=EquipRDB64 connection and update "
     "its credentials. The dataflow runs as the pipeline's schedule owner (Brian), so that account must be a "
     "user of the connection."),
    (("timeout", "timed out", "time out"),
     "The load ran out of time.",
     "Usually Equip or the gateway was slow. Watch the next load; if loads keep timing out, check the gateway "
     "machine (SPI00T4022W11) and Fabric Capacity Metrics."),
    (("capacity", "throttl", "too many requests"),
     "The Fabric capacity (fabric1cap1) was too busy and rejected the work.",
     "Check Fabric Capacity Metrics for a spike at this time. The next load normally succeeds once it settles."),
    (("gateway", "dm_gwpipeline", "odbc", "equiprdb64", "sql anywhere", "communication link"),
     "Fabric could not read Equip through the on-premises data gateway (SPI-Data-Gateway, ODBC dsn=EquipRDB64).",
     "Check that the gateway is online (Fabric > Settings > Manage connections and gateways > SPI-Data-Gateway). "
     "If it is offline, check the gateway service on the Gateway PC (SPI00T4022W11) and that Equip is up."),
]
PARTS_DEFAULT_CAUSE = (
    "Fabric did not give a specific reason. A generic error such as \"Something went wrong\" is usually "
    "temporary.",
    "Nothing, if the next load succeeds. If two loads in a row fail, open the run in the Fabric Monitor and "
    "refresh df_PartsAvailability_Raw by hand in DP - Staging - Prod.")


def classify_failure(error):
    """(likely cause, what to do) for a Fabric error message."""
    low = (error or "").lower()
    for needles, cause, action in PARTS_CAUSES:
        if any(n in low for n in needles):
            return cause, action
    return PARTS_DEFAULT_CAUSE


def next_load(now_local):
    """The next scheduled load strictly after now_local (naive Central time)."""
    for offset in range(8):
        d = (now_local + timedelta(days=offset)).date()
        if d.weekday() >= 5:
            continue
        for h, m in PARTS_LOAD_TIMES:
            t = datetime(d.year, d.month, d.day, h, m)
            if t > now_local:
                return t
    raise ValueError(f"no scheduled load within a week of {now_local}")


def parse_trigger_time(text):
    """@pipeline().TriggerTime ('2026-10-14T14:50:00.1234567Z') as aware UTC, or None if unreadable."""
    m = _parts_re.match(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", text or "")
    return datetime.fromisoformat(m.group(1)).replace(tzinfo=timezone.utc) if m else None


def parts_failure_alert(env, error, run_id, failed_load_local, now_local):
    """{"subject", "html", "teams_text"} for one failed load. Times are naive Central."""
    e = _parts_html.escape
    cause, action = classify_failure(error)
    load = failed_load_local.strftime("%H:%M")
    nxt = next_load(now_local)
    nxt_text = nxt.strftime("%H:%M") if nxt.date() == now_local.date() else nxt.strftime("%a %m/%d %H:%M")
    subject = f"🔴 [{env}] Parts Availability: the {load} data load failed"
    body = (
        f"<p><b>{e(subject)}</b></p>"
        "<p><b>What happened</b><br>"
        f"Pipeline_PartsAvailability could not load Equip part data into DP (df_PartsAvailability_Raw → "
        f"DP_Staging.PartsAvailability) for the {e(load)} load, even after one automatic retry. The Parts "
        "Availability app keeps working with the last good data and shows its \"Data as of\" time; it shows a "
        "stale-data banner once that data is more than 90 minutes old during business hours.</p>"
        f"<p><b>Likely cause</b><br>{e(cause)}</p>"
        f"<p><b>What to do</b><br>{e(action)}<br>The next scheduled load at {e(nxt_text)} will try again "
        "automatically.</p>"
        f"<p><b>Fabric's error message</b></p><pre>{e((error or '(none)')[:3000])}</pre>"
        f"<p style=\"color:#666\">Pipeline run {e(run_id)} · Fabric Monitor → Pipeline_PartsAvailability "
        "(DP - Presentation). Runbook: fabric-workspace-docs OPERATIONS-GUIDE.md → \"Parts Availability feed\".</p>")
    teams = f"{subject} | {cause} | Next try {nxt_text}."
    return {"subject": subject, "html": body, "teams_text": teams[:2000]}


def parts_messages(alert, notify, env):
    """High-importance email to the alert list plus a short Teams post; empty lists are dropped."""
    r = notify["recipients"][env]
    msgs = [{"to": list(r["alert"]), "subject": alert["subject"], "html": alert["html"], "importance": "high"},
            {"to": list(r["teams"]), "subject": alert["subject"],
             "html": f"<p>{_parts_html.escape(alert['teams_text'])}</p>", "importance": "normal"}]
    return [m for m in msgs if m["to"]]
```

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `python -m pytest deploy/test_parts_alert.py -q`
Expected: `9 passed`.

- [ ] **Step 5: Commit**

```bash
git add deploy/parts_alert.py deploy/test_parts_alert.py
git commit -m "parts_alert: failure classification and alert text for Pipeline_PartsAvailability"
```

---

## Task 6: `Notify_PartsAvailability` notebook (rendered) and a real test alert

**Files:**
- Create: `fabric-workspace-docs/deploy/parts_alert_glue.py`
- Modify: `fabric-workspace-docs/deploy/render_orchestrator.py`
- Modify: `fabric-workspace-docs/deploy/test_render_orchestrator.py`
- Generated: `workspaces/DP - Presentation - Dev/Orchestration/Notify_PartsAvailability.Notebook/`

- [ ] **Step 1: Update the render test first.** In `deploy/test_render_orchestrator.py`, change the first assertion of `test_committed_notebooks_are_current` to:

```python
    assert {t["kind"] for t in TARGETS} == {"orchestrator", "notifier", "parts_notifier"}
```

Run: `python -m pytest deploy/test_render_orchestrator.py -q`
Expected: FAIL (the kinds set has no `parts_notifier` yet).

- [ ] **Step 2: Write `deploy/parts_alert_glue.py`**

```python
# deploy/parts_alert_glue.py
# Fabric-only body of Notify_PartsAvailability: Pipeline_PartsAvailability runs it when the
# df_PartsAvailability_Raw load fails after its retry. Reads orchestrator.notify from this lakehouse's
# Files/config/dp_refresh_dag.json (default lakehouse DP_Presentation) and sends through notify_send as
# SPN-Fabric-Refresh-Automation. Fails if any message could not be sent, so the run shows it.
import json
from datetime import datetime
from zoneinfo import ZoneInfo

PARTS_CENTRAL = ZoneInfo("America/Chicago")
try:
    ENV = notebookutils.runtime.context.get("currentWorkspaceName").rsplit(" - ", 1)[1]
except Exception:
    ENV = "unknown"

now_local = datetime.now(PARTS_CENTRAL).replace(tzinfo=None)
triggered = parts_parse_trigger_time(triggered_at)
failed_load_local = triggered.astimezone(PARTS_CENTRAL).replace(tzinfo=None) if triggered else now_local

CONFIG = json.loads(notebookutils.fs.head("Files/config/dp_refresh_dag.json", 20_000_000))
NOTIFY = (CONFIG.get("orchestrator") or {}).get("notify")
if not NOTIFY:
    raise RuntimeError("orchestrator.notify missing from Files/config/dp_refresh_dag.json")
alert = parts_failure_alert(ENV, error_message or "(no error message)", run_id or "", failed_load_local, now_local)
messages = parts_messages(alert, NOTIFY, ENV)
errors = send_notifications(messages, NOTIFY)
print(alert["subject"])
if errors:
    raise RuntimeError("Notify_PartsAvailability could not send: " + " | ".join(errors))
print("sent", len(messages), "message(s)")
```

- [ ] **Step 3: Register the new kind and target** in `deploy/render_orchestrator.py`.

  (a) Add this entry to `TARGETS`, after the `notifier` entry:

```python
    {"kind": "parts_notifier",
     "path": "workspaces/DP - Presentation - Dev/Orchestration/Notify_PartsAvailability.Notebook",
     "lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91", "lakehouse_name": "DP_Presentation",
     "workspace": "73fd5443-240e-410a-990a-98827f32c087"},
```

  (b) After `NOTIFY_MARKDOWN`, add:

```python
PARTS_NOTIFY_PARAMETERS = '''error_message = ""
run_id = ""
triggered_at = ""
'''
PARTS_NOTIFY_MARKDOWN = '''# # Notify_PartsAvailability
# Parts Availability load-failure notifier. GENERATED by fabric-workspace-docs/deploy/render_orchestrator.py
# from notify_core.py + notify_send.py + parts_alert.py + parts_alert_glue.py: edit those files and re-render,
# never this notebook. Pipeline_PartsAvailability runs it when df_PartsAvailability_Raw fails (after one retry):
# it emails the alert list and posts to the Teams channel through Microsoft Graph as
# SPN-Fabric-Refresh-Automation, using orchestrator.notify from Files/config/dp_refresh_dag.json.
# Spec: data-projects/docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md
'''
```

  (c) Add to `KINDS`:

```python
    "parts_notifier": {"displayName": "Notify_PartsAvailability", "parameters": PARTS_NOTIFY_PARAMETERS,
                       "markdown": PARTS_NOTIFY_MARKDOWN,
                       "code": ["notify_core.py", "notify_send.py", "parts_alert.py", "parts_alert_glue.py"]},
```

  (d) In the module docstring, add after the Notify_DP_Refresh sentence: `Notify_PartsAvailability (Presentation): notify_core.py + notify_send.py + parts_alert.py + parts_alert_glue.py.`

- [ ] **Step 4: Render and test**

Run: `python deploy/render_orchestrator.py && python -m pytest deploy -q`
Expected:
- `rendered …/Notify_PartsAvailability.Notebook` (plus its new `.platform`);
- all tests pass, including `test_every_code_cell_parses` for the new notebook.

- [ ] **Step 5: Commit, push and sync Dev**

```bash
git add deploy/parts_alert_glue.py deploy/render_orchestrator.py deploy/test_render_orchestrator.py "workspaces/DP - Presentation - Dev/Orchestration/Notify_PartsAvailability.Notebook"
git commit -m "Notify_PartsAvailability: rendered failure notifier for the Parts Availability load"
git push origin dev
```

Run: `python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/wait_ci.py c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs && python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/git_sync.py 73fd5443-240e-410a-990a-98827f32c087`
Expected: both exit 0.

- [ ] **Step 6: Get the Dev IDs of the notifier and the dataflow**

Run:

```bash
export PATH="$HOME/.local/bin:$PATH"
fab get "DP - Presentation - Dev.Workspace/Orchestration.Folder/Notify_PartsAvailability.Notebook" -q id
fab get "DP - Staging - Dev.Workspace/Raw Data - Dataflows.Folder/df_PartsAvailability_Raw.Dataflow" -q id
```

Expected: two GUIDs; record both in the plan's progress note. If the folder path form fails, list the items with `fab api "workspaces/<wsId>/items"` and find them by `displayName`.

- [ ] **Step 7: Send a real test alert from Dev.** It goes to the Dev recipients: Brian's alert address, plus the Teams list if Dev has one.

Run:

```bash
python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/run_item.py 73fd5443-240e-410a-990a-98827f32c087 <notifier Dev id> RunNotebook 900 --param "error_message=TEST ONLY - DM_GWPipeline_Gateway_MashupDataAccessError: ODBC: ERROR [08001] (simulated)" --param "run_id=test-$(date +%Y%m%d%H%M)" --param "triggered_at=2026-10-14T14:50:00.0000000Z"
```

Expected:
- exit 0;
- Brian receives "🔴 [Dev] Parts Availability: the 09:50 data load failed", classified as the gateway cause, with the next load time.
- **Ask Brian whether the wording and layout are what he wants;** adjust `parts_alert.py` (tests first) until he's happy.

---

## Task 7: `Pipeline_PartsAvailability` (rendered)

**Files:**
- Modify: `fabric-workspace-docs/deploy/pipeline_render.py`
- Modify: `fabric-workspace-docs/deploy/render_orchestrator.py`
- Modify: `fabric-workspace-docs/deploy/test_pipeline_render.py`
- Generated: `workspaces/DP - Presentation - Dev/Pipelines/Pipeline_PartsAvailability.DataPipeline/` (`pipeline-content.json`, `.platform`)

- [ ] **Step 1: Write the failing tests.** Append to `deploy/test_pipeline_render.py`, and extend its import lines:

```python
from pipeline_render import PARTS_DATAFLOW, PARTS_NOTIFIER, PARTS_PIPELINE_PATH, STAGING_WS, parts_pipeline  # noqa: E402
from render_orchestrator import PARTS_NOTIFY_PARAMETERS  # noqa: E402


def test_parts_pipeline_wiring():
    a = _by_name(parts_pipeline())
    assert set(a) == {"Load_PartsAvailability", "Notify_Load_Failed", "Fail_Load"}
    load = a["Load_PartsAvailability"]
    assert load["type"] == "RefreshDataflow" and "externalReferences" not in load
    assert load["typeProperties"]["dataflowId"] == PARTS_DATAFLOW
    assert load["typeProperties"]["workspaceId"] == STAGING_WS
    assert load["policy"]["retry"] == 1 and load["policy"]["retryIntervalInSeconds"] == 120
    assert load["policy"]["timeout"] == "0.00:20:00"
    assert parts_pipeline()["properties"]["concurrency"] == 1
    n = a["Notify_Load_Failed"]
    assert n["typeProperties"]["notebookId"] == PARTS_NOTIFIER
    assert n["externalReferences"] == {"connection": NOTEBOOK_CONNECTION}
    assert n["dependsOn"] == [{"activity": "Load_PartsAvailability", "dependencyConditions": ["Failed"]}]
    assert set(n["typeProperties"]["parameters"]) <= _param_names(PARTS_NOTIFY_PARAMETERS)
    assert a["Fail_Load"]["dependsOn"] == [{"activity": "Notify_Load_Failed", "dependencyConditions": ["Completed"]}]


def test_parts_pipeline_expression_references_exist():
    p = parts_pipeline()
    names = set(_by_name(p))
    for s in _strings(p):
        for name in ACTIVITY_CALL_RE.findall(s):
            assert name in names, f"expression references unknown activity {name!r}: {s!r}"


def test_committed_parts_pipeline_is_current():
    committed = json.loads((REPO / PARTS_PIPELINE_PATH).read_text(encoding="utf-8"))
    diffs = list(_diff_paths(committed, parts_pipeline()))
    assert not diffs, "Pipeline_PartsAvailability is stale: run python deploy/render_orchestrator.py\n" + "\n".join(diffs)
```

Run: `python -m pytest deploy/test_pipeline_render.py -q`
Expected: FAIL with `ImportError: cannot import name 'PARTS_DATAFLOW'`.

- [ ] **Step 2: Add the pipeline to `deploy/pipeline_render.py`.** Put the constants after `NOTIFIER`, using the two Dev IDs from Task 6 Step 6:

```python
PARTS_PIPELINE_PATH = ("workspaces/DP - Presentation - Dev/Pipelines/Pipeline_PartsAvailability.DataPipeline/"
                       "pipeline-content.json")
PARTS_DATAFLOW = "<df_PartsAvailability_Raw Dev item ID from Task 6 Step 6>"
PARTS_NOTIFIER = "<Notify_PartsAvailability Dev item ID from Task 6 Step 6>"
```

(Write the real GUIDs in the file; the angle-bracket text above only marks where they come from.) Then add at the end of the file:

```python
def parts_pipeline() -> dict:
    """Pipeline_PartsAvailability: hourly load of df_PartsAvailability_Raw for the Parts Availability app,
    scheduled in Prod (weekdays 06:50-16:50 Central). The dataflow runs as the schedule owner (Dataflow Gen2
    refuses service principals); on failure Notify_PartsAvailability emails/posts the alert as the SPN and the
    run ends Failed. Prod: deploy_backend.py swaps PARTS_DATAFLOW and PARTS_NOTIFIER for their Prod IDs.
    Spec: data-projects/docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md"""
    load = {"name": "Load_PartsAvailability", "type": "RefreshDataflow", "dependsOn": [],
            # one retry after 2 min: the one LH failure in 31 runs (2026-10-08) was transient. A load normally
            # takes ~2 min; 20 min x 2 attempts + 2 min keeps a failing run inside its hour (no overlap).
            "policy": _policy("0.00:20:00", retry=1, interval=120),
            "typeProperties": {"dataflowId": PARTS_DATAFLOW, "workspaceId": STAGING_WS,
                               "notifyOption": "NoNotification", "dataflowType": "DataflowFabric",
                               "executeMashupQueriesOnly": True}}
    notify = _notebook("Notify_Load_Failed", PARTS_NOTIFIER, PRESENTATION_WS,
                       {"error_message": _param("@activity('Load_PartsAvailability').error.message"),
                        "run_id": _param("@pipeline().RunId"),
                        "triggered_at": _param("@string(pipeline().TriggerTime)")},
                       [_dep("Load_PartsAvailability", "Failed")], timeout="0.00:15:00", retry=1, interval=60)
    fail = {"name": "Fail_Load", "type": "Fail", "dependsOn": [_dep("Notify_Load_Failed", "Completed")],
            "typeProperties": {"message": _expr("@activity('Load_PartsAvailability').error.message"),
                               "errorCode": "PartsAvailabilityLoadFailed"}}
    # concurrency 1: a run that starts while the previous one is still going queues instead of overlapping
    return {"properties": {"activities": [load, notify, fail], "concurrency": 1}}
```

- [ ] **Step 3: Write the pipeline from `render_orchestrator.main()`.** Change the import line to:

```python
from pipeline_render import PARTS_PIPELINE_PATH, PIPELINE_PATH, parts_pipeline, pipeline
```

Replace the pipeline part of `main()` (from `cfg = json.loads(...)` to the end of the function) with:

```python
    cfg = json.loads((DEPLOY / "dp_refresh_dag.json").read_text(encoding="utf-8"))
    _write_pipeline(PIPELINE_PATH, pipeline(cfg["orchestrator"]["modelRefreshParallelism"]), "Pipeline_DP_Refresh")
    _write_pipeline(PARTS_PIPELINE_PATH, parts_pipeline(), "Pipeline_PartsAvailability")


def _write_pipeline(rel_path, wanted, display_name):
    path = REPO / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)
    # Compare parsed JSON: after a workspace commit Fabric may re-serialise the file (key order, spacing);
    # only rewrite when the definition really changed, so a Fabric round-trip doesn't churn the file.
    if not path.exists() or json.loads(path.read_text(encoding="utf-8")) != wanted:
        path.write_text(json.dumps(wanted, indent=2), encoding="utf-8", newline="\n")
        print("rendered", path)
    platform = path.parent / ".platform"
    if not platform.exists():
        platform.write_text(json.dumps({
            "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
            "metadata": {"type": "DataPipeline", "displayName": display_name},
            "config": {"version": "2.0", "logicalId": str(uuid.uuid4())}}, indent=2), encoding="utf-8", newline="\n")
        print("rendered", platform)
```

Also add `Pipeline_PartsAvailability.DataPipeline/pipeline-content.json: pipeline_render.py's parts_pipeline().` to the module docstring.

- [ ] **Step 4: Render and run all tests**

Run: `python deploy/render_orchestrator.py && python -m pytest deploy -q && python deploy/dag_check.py`
Expected:
- the new pipeline files are rendered;
- `Pipeline_DP_Refresh` is unchanged (`git diff --stat` shows no change to its JSON);
- all tests pass; `dag_check` OK.

- [ ] **Step 5: Commit, push, sync Dev**

```bash
git add deploy/pipeline_render.py deploy/render_orchestrator.py deploy/test_pipeline_render.py "workspaces/DP - Presentation - Dev/Pipelines/Pipeline_PartsAvailability.DataPipeline"
git commit -m "Pipeline_PartsAvailability: hourly Parts Availability load with custom failure alert"
git push origin dev
```

Run `wait_ci.py`, then `git_sync.py 73fd5443-240e-410a-990a-98827f32c087`. Expected: both exit 0.

- [ ] **Step 6: Run the pipeline in Dev (success path)**

Get its ID: `fab get "DP - Presentation - Dev.Workspace/Pipelines.Folder/Pipeline_PartsAvailability.DataPipeline" -q id`.
Then run: `python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/run_item.py 73fd5443-240e-410a-990a-98827f32c087 <pipeline id> Pipeline 1800`

Expected:
- exit 0 (Completed);
- in the Fabric Monitor, `Load_PartsAvailability` Succeeded and `Notify_Load_Failed` and `Fail_Load` Skipped;
- Task 3 Step 5's script then shows a new `ExtractedAtUtc`.

If `run_item.py` rejects job type `Pipeline`, Brian runs it with **Run** in the pipeline editor.

---

## Task 8: Prod deploy support

**Files:**
- Modify: `fabric-workspace-docs/deploy/prod_scope.py`, `deploy/test_prod_scope.py`
- Modify: `fabric-workspace-docs/deploy/deploy_backend.py`, `deploy/test_deploy_backend.py`

- [ ] **Step 1: Update the tests first.**

  (a) In `deploy/test_prod_scope.py` → `test_prod_items_maps_items_to_their_workspace_folders`, add after the `pl = …` line:

```python
    n2 = _item(tmp_path, "DP - Presentation - Dev", "Orchestration/Notify_PartsAvailability.Notebook", "Notebook",
               "Notify_PartsAvailability")
    pl2 = _item(tmp_path, "DP - Presentation - Dev", "Pipelines/Pipeline_PartsAvailability.DataPipeline",
                "DataPipeline", "Pipeline_PartsAvailability")
```

  and change the last assertion to:

```python
    assert sorted(result["presentation"]) == sorted([g, o2, n, pl, n2, pl2])
```

  Any other test in that file that builds the `ALWAYS` items needs the same two `_item` lines; run the file and add them where it reports `FileNotFoundError … Notify_PartsAvailability`.

  (b) In `deploy/test_deploy_backend.py` → `test_main_prod_deploys_staging_then_presentation_and_writes_dag_only`, replace everything from the comment `# deploy called twice: …` down to (and including) the "staging stage's parameter.yml must NOT …" assertion with:

```python
    # three deploys: staging (Notebook+Dataflow), presentation notebooks, then presentation pipelines
    assert len(deploy_calls) == 3
    assert deploy_calls[0]["workspace_id"] == deploy_backend.WORKSPACE_IDS["prod"]["staging"]
    assert deploy_calls[0]["item_type_in_scope"] == ["Notebook", "Dataflow"]
    assert deploy_calls[1]["workspace_id"] == deploy_backend.WORKSPACE_IDS["prod"]["presentation"]
    assert deploy_calls[1]["item_type_in_scope"] == ["Notebook"]
    assert deploy_calls[2]["workspace_id"] == deploy_backend.WORKSPACE_IDS["prod"]["presentation"]
    assert deploy_calls[2]["item_type_in_scope"] == ["DataPipeline"]

    # every item a pipeline calls is looked up in Dev and Prod (after the notebooks were published)
    ws = deploy_backend.WORKSPACE_IDS
    assert find_item_id_calls == [
        {"workspace_id": ws[env][tier], "display_name": name, "item_type": item_type}
        for tier, name, item_type in deploy_backend.PIPELINE_ID_SWAPS
        for env in ("dev", "prod")]

    # only the pipeline stage's parameter.yml got the swaps
    pipeline_stage = deploy_calls[2]["repository_directory"]
    parameter_text = (pipeline_stage / "parameter.yml").read_text(encoding="utf-8")
    for tier, name, _ in deploy_backend.PIPELINE_ID_SWAPS:
        assert f'  - find_value: "dev-{tier}-{name}"' in parameter_text
        assert f'      prod: "prod-{tier}-{name}"' in parameter_text
    assert '    item_type: "DataPipeline"' in parameter_text
    for stage in (deploy_calls[0], deploy_calls[1]):
        assert "dev-staging-Run_DP_Refresh" not in (stage["repository_directory"] / "parameter.yml").read_text(
            encoding="utf-8")
    assert ("staging", "df_PartsAvailability_Raw", "Dataflow") in deploy_backend.PIPELINE_ID_SWAPS
    assert ("presentation", "Notify_PartsAvailability", "Notebook") in deploy_backend.PIPELINE_ID_SWAPS
```

Run: `python -m pytest deploy/test_prod_scope.py deploy/test_deploy_backend.py -q`
Expected: FAIL (the new items aren't in `ALWAYS`; `PIPELINE_ID_SWAPS` doesn't exist).

- [ ] **Step 2: `deploy/prod_scope.py`.** Extend `ALWAYS`:

```python
ALWAYS = [("staging", "Notebook", "Run_DP_Refresh"),
          ("presentation", "Notebook", "Run_DP_Refresh"),
          ("presentation", "Notebook", "Notify_DP_Refresh"),
          ("presentation", "DataPipeline", "Pipeline_DP_Refresh"),
          ("presentation", "Notebook", "Notify_PartsAvailability"),
          ("presentation", "DataPipeline", "Pipeline_PartsAvailability")]
```

Update the module docstring's list to say "the two Run_DP_Refresh orchestrators, the two notifiers, Pipeline_DP_Refresh and Pipeline_PartsAvailability".

- [ ] **Step 3: `deploy/deploy_backend.py`.** Add after `LAKEHOUSE_IDS`:

```python
# Items the Prod pipelines call by their real item ID (a Notebook activity with a connection, and a
# RefreshDataflow activity, store the ID, not the logicalId), so each needs a Dev -> Prod swap:
# (tier, display name, Fabric type).
PIPELINE_ID_SWAPS = (("staging", "Run_DP_Refresh", "Notebook"),
                     ("presentation", "Run_DP_Refresh", "Notebook"),
                     ("presentation", "Notify_DP_Refresh", "Notebook"),
                     ("presentation", "Notify_PartsAvailability", "Notebook"),
                     ("staging", "df_PartsAvailability_Raw", "Dataflow"))
```

Replace the presentation part of the Prod branch (from the comment `# Pipeline_DP_Refresh's notebook activities carry a connection…` through the `print(f"Deployed {len(items['presentation'])} …")` call) with:

```python
        # Presentation notebooks first, so a brand-new notebook a pipeline calls has a Prod ID to swap to;
        # then the pipelines, with every Dev item ID they reference swapped for its Prod ID.
        notebook_stage = stage_items(REPO_ROOT, items["presentation"])
        deploy(workspace_id=ids["presentation"], repository_directory=notebook_stage,
               item_type_in_scope=["Notebook"], environment=environment)
        rules = [(find_item_id(WORKSPACE_IDS["dev"][tier], name, item_type),
                  find_item_id(ids[tier], name, item_type), "DataPipeline")
                 for tier, name, item_type in PIPELINE_ID_SWAPS]
        pipeline_stage = stage_items(REPO_ROOT, items["presentation"])
        append_rules(pipeline_stage / "parameter.yml", rules)
        deploy(workspace_id=ids["presentation"], repository_directory=pipeline_stage,
               item_type_in_scope=["DataPipeline"], environment=environment)
        print(f"Deployed {len(items['presentation'])} items to the {environment} presentation workspace "
              f"({len(rules)} item ID swaps for the pipelines).")
```

Check the order of `find_item_id` calls against the test: for each swap it looks up Dev, then Prod, which matches the comprehension above.

- [ ] **Step 4: Run all tests**

Run: `python -m pytest deploy -q && python deploy/dag_check.py`
Expected: all pass.

- [ ] **Step 5: Commit and push**

```bash
git add deploy/prod_scope.py deploy/test_prod_scope.py deploy/deploy_backend.py deploy/test_deploy_backend.py
git commit -m "Prod deploy: Pipeline_PartsAvailability + notifier; notebooks before pipelines; dataflow ID swap"
git push origin dev
```

Run `wait_ci.py`. Expected: exit 0.

---

## Task 9: Dev validation against LH (same minute)

- [ ] **Step 1: Pair 1.** At **hh:50** during business hours (LH's scheduled load fires then), start the Dev pipeline as in Task 7 Step 6. Start it within one minute of :50.
- [ ] **Step 2: Pair 2.** Repeat at the next hour's :50, so persistence across consecutive pairs is exercised.
- [ ] **Step 3: Compare**

Run: `python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/parts_availability_check.py dev`
Expected:
- 2 pairs;
- rows equal or within a handful;
- `only LH` / `only DP` 0 or a handful;
- `differing` a handful at most (mostly BinQty/OnOrder);
- DP dup keys 0; one ExtractedAtUtc per load;
- `PASS`.

  If `FAIL`, stop and investigate with Brian before going further. A structural difference (types, a column always different, many one-sided keys) means the query or types differ from LH.

- [ ] **Step 4: Freshness check path in Dev.** Run the Dev `Pipeline_DP_Refresh` with `mode=items`, `items=df_PartsAvailability_Raw` (Brian in the UI, or the `fab api` jobs call used for Dev runs). The pipeline is in DP - Presentation - Dev.
Expected:
- the run completes;
- the Dev summary email lists `df_PartsAvailability_Raw` as Succeeded;
- no "Parts Availability hourly load" freshness warning (data is from today);
- no "freshness check on PartsAvailability could not run" warning.

- [ ] **Step 5: Record the results** in this plan's progress note and commit the plan file:

```bash
git -C c:/Users/bfox/Documents/Git-Projects/data-projects add docs/superpowers/plans/2026-10-14-parts-availability-dp-feed.md
git -C c:/Users/bfox/Documents/Git-Projects/data-projects commit -m "Parts Availability plan: Dev validation results"
```

---

## Task 10: Gateway PC pipeline: pure helpers (`refresh_logic.py`)

**Files** (`P` = `c:/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/parts-lookup-static-prototype`):
- Create: `P/refresh_logic.py`
- Test: `P/test_refresh_logic.py`

- [ ] **Step 1: Write the failing tests** in `P/test_refresh_logic.py`:

```python
from datetime import datetime, timezone

import pytest

from refresh_logic import (MIN_ROWS, build_meta, has_extracted_at, should_skip, source_path, to_utc_iso,
                           upload_order, validate_extract)


def test_source_paths():
    assert source_path("lh").endswith("/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/InMaster_PartsLookup_Raw")
    assert source_path("dp") == ("abfss://189e5c0a-548a-4feb-93d6-dda9ebbe96c1@onelake.dfs.fabric.microsoft.com/"
                                 "6713bd45-a4ad-47e6-8bff-1bb0415e9784/Tables/PartsAvailability")
    assert "876255e0-d462-4697-adc1-4a655f5bb101" in source_path("dp-dev")
    assert not has_extracted_at("lh") and has_extracted_at("dp") and has_extracted_at("dp-dev")
    with pytest.raises(ValueError, match="unknown source"):
        source_path("prod")


def test_to_utc_iso_treats_naive_as_utc():
    assert to_utc_iso(datetime(2026, 10, 14, 11, 50, 3)) == "2026-10-14T11:50:03+00:00"
    aware = datetime(2026, 10, 14, 11, 50, tzinfo=timezone.utc)
    assert to_utc_iso(aware) == "2026-10-14T11:50:00+00:00"


def test_validate_extract_ok():
    t = datetime(2026, 10, 14, 11, 50)
    assert validate_extract(1_068_934, [t], 0, require_extracted_at=True) == []
    assert validate_extract(1_068_934, [], 0, require_extracted_at=False) == []


def test_validate_extract_failures():
    t = datetime(2026, 10, 14, 11, 50)
    assert "rows" in validate_extract(MIN_ROWS - 1, [t], 0, True)[0]
    assert "duplicate" in validate_extract(1_068_934, [t], 3, True)[0]
    assert "ExtractedAtUtc" in validate_extract(1_068_934, [t, datetime(2026, 10, 14, 12, 50)], 0, True)[0]
    assert "ExtractedAtUtc" in validate_extract(1_068_934, [None], 0, True)[0]
    assert "ExtractedAtUtc" in validate_extract(1_068_934, [], 0, True)[0]
    assert len(validate_extract(10, [], 2, True)) == 3


def test_should_skip_only_when_the_same_load_was_already_published():
    assert should_skip("2026-10-14T11:50:03+00:00", "2026-10-14T11:50:03+00:00")
    assert not should_skip("2026-10-14T12:50:03+00:00", "2026-10-14T11:50:03+00:00")
    assert not should_skip("2026-10-14T11:50:03+00:00", None)
    assert not should_skip(None, None)


def test_build_meta():
    assert build_meta("A", "B") == {"generatedAt": "A", "publishedAt": "B"}


def test_upload_order_puts_meta_last():
    files = ["out/_meta.json", "out/RE1.json.gz", "out/_manifest.json", "out/AB.json.gz"]
    assert upload_order(files) == ["out/AB.json.gz", "out/RE1.json.gz", "out/_manifest.json", "out/_meta.json"]
    assert upload_order(["out/AB.json.gz"]) == ["out/AB.json.gz"]
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd "c:/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/parts-lookup-static-prototype" && python -m pytest test_refresh_logic.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'refresh_logic'`.

- [ ] **Step 3: Write `P/refresh_logic.py`**

```python
"""
PARTS LOOKUP REFRESH PIPELINE - PURE HELPERS
============================================================================
No network, no config import: unit-tested in test_refresh_logic.py.
Added 2026-10 for the move from LH_Master_Data to DP (spec:
docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md).

- SOURCES: the tables extract.py can read. "lh" is the old LH_Master_Data
  table; "dp" is DP_Staging's PartsAvailability in Prod (loaded hourly by
  Pipeline_PartsAvailability, weekdays 06:50-16:50); "dp-dev" is the Dev
  copy, for tests. Only the DP tables carry ExtractedAtUtc (the load time).
- validate_extract(): the guards that stop a partial or broken table from
  ever being published.
- should_skip(): run_refresh.py publishes a load only once; runs that find
  the same ExtractedAtUtc as the last publish (no new load, or a failed
  load) skip the 18-minute partition + upload.
- build_meta(): _meta.json's generatedAt is the DATA's load time, so the
  app's "Data as of" and its stale banner (and check_staleness.py) measure
  how old the data really is.
- upload_order(): _meta.json goes last, so "Data as of" never moves ahead
  of the files it describes.
============================================================================
"""

import os
from datetime import timezone

ONELAKE = "abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"
SOURCES = {
    # name: (workspace ID, lakehouse ID, table, has ExtractedAtUtc)
    "lh": ("b48cdb35-7ce3-46de-96df-d70db77649cb", "3e74497b-8c51-4a1a-91a1-888c59118f48",
           "InMaster_PartsLookup_Raw", False),
    "dp": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784",
           "PartsAvailability", True),
    "dp-dev": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101",
               "PartsAvailability", True),
}
MIN_ROWS = 1_000_000  # ~1,069,000 rows in 2026-10; far fewer means a partial or broken load
META_FILE = "_meta.json"


def source_path(name: str) -> str:
    if name not in SOURCES:
        raise ValueError(f"unknown source {name!r}; expected one of {sorted(SOURCES)}")
    ws, lh, table, _ = SOURCES[name]
    return ONELAKE.format(ws=ws, lh=lh, table=table)


def has_extracted_at(name: str) -> bool:
    return SOURCES[name][3]


def to_utc_iso(value) -> str:
    """A datetime (naive = UTC, as the dataflow writes it) as ISO 8601 with +00:00."""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def validate_extract(row_count: int, extracted_values: list, duplicate_keys: int,
                     require_extracted_at: bool) -> list:
    """Reasons not to publish this extract (empty list = OK)."""
    errors = []
    if row_count < MIN_ROWS:
        errors.append(f"only {row_count:,} rows (expected at least {MIN_ROWS:,}) - refusing to publish a "
                      "partial table")
    if duplicate_keys:
        errors.append(f"{duplicate_keys:,} duplicate Branch+Franchise+PartNumber keys")
    if require_extracted_at and (len(extracted_values) != 1 or extracted_values[0] is None):
        errors.append(f"ExtractedAtUtc should hold exactly one non-null value, found {extracted_values!r}")
    return errors


def should_skip(extracted_at, last_published) -> bool:
    return extracted_at is not None and extracted_at == last_published


def build_meta(extracted_at: str, published_at: str) -> dict:
    return {"generatedAt": extracted_at, "publishedAt": published_at}


def upload_order(paths: list) -> list:
    """Sorted, with _meta.json last."""
    return sorted(paths, key=lambda p: (os.path.basename(p) == META_FILE, p))
```

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `python -m pytest test_refresh_logic.py -q`
Expected: `7 passed`.

- [ ] **Step 5: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/refresh_logic.py" ".claude/queries/adhoc/parts-lookup-static-prototype/test_refresh_logic.py"
git commit -m "Parts Lookup pipeline: pure helpers for the DP source (guards, skip, meta, upload order)"
```

---

## Task 11: `config.py` and `extract.py`

**Files:**
- Modify: `P/config.py`
- Rewrite: `P/extract.py`

- [ ] **Step 1: `P/config.py`.** Replace `load_dotenv()` with:

```python
# PARTS_LOOKUP_ENV_FILE picks another env file, e.g. .env.test (the staging SharePoint library, no Teams
# webhook, PARTS_LOOKUP_SOURCE=dp-dev) for test runs from Brian's PC. Default: .env.
load_dotenv(os.environ.get("PARTS_LOOKUP_ENV_FILE", ".env"))
```

and append at the end of the file:

```python
# Which table extract.py reads (see refresh_logic.SOURCES): "lh" until the DP cutover, then "dp".
# An env file can override it per machine or per test run (PARTS_LOOKUP_SOURCE=dp-dev).
SOURCE = os.environ.get("PARTS_LOOKUP_SOURCE", "lh")
```

Also update the docstring: "Values come from a local .env file (or the file named by PARTS_LOOKUP_ENV_FILE) …".

- [ ] **Step 2: Rewrite `P/extract.py`**

```python
"""
PARTS LOOKUP REFRESH PIPELINE - EXTRACT
============================================================================
Reads the Parts Availability table chosen by config.SOURCE (see
refresh_logic.SOURCES) from OneLake via DuckDB, as the pipeline's own
service principal (see config.py / .env), so it runs unattended.

Before saving anything it runs refresh_logic.validate_extract(): at least
1,000,000 rows, no duplicate Branch+Franchise+PartNumber (raw values, no
trimming: trailing-space twin part numbers are real rows), and for the DP
sources exactly one ExtractedAtUtc. A failed guard exits non-zero, so
run_refresh.py logs and alerts and publishes nothing.

Writes partslookup_extract.parquet (the 12 columns partition.py publishes)
and extract_meta.json: {"source", "extractedAtUtc", "rows"}. extractedAtUtc
is the DP load's own ExtractedAtUtc; the LH table has none, so for "lh" it
is the time of this extract (the old behaviour, kept for rollback).
============================================================================
"""

import json
import time
from datetime import datetime, timezone

import duckdb

import config
from refresh_logic import has_extracted_at, source_path, to_utc_iso, validate_extract

OUT_PATH = "partslookup_extract.parquet"
META_OUT = "extract_meta.json"
COLUMNS = ("PartNumber, Branch, Franchise, Description, VendorCode, Bin, BinQty, OnOrder, SellPrice1, "
           "SuperTo, SuperFrom, Comments")


def main() -> None:
    path = source_path(config.SOURCE)
    con = duckdb.connect()
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
    con.execute("SET TimeZone = 'UTC';")
    con.execute(
        f"""
        CREATE SECRET (
            TYPE azure,
            PROVIDER service_principal,
            TENANT_ID '{config.TENANT_ID}',
            CLIENT_ID '{config.CLIENT_ID}',
            CLIENT_SECRET '{config.CLIENT_SECRET}'
        );
        """
    )

    start = time.time()
    con.execute(f"CREATE TABLE src AS SELECT * FROM delta_scan('{path}')")
    row_count = con.execute("SELECT count(*) FROM src").fetchone()[0]
    duplicate_keys = con.execute(
        "SELECT count(*) FROM (SELECT Branch, Franchise, PartNumber FROM src GROUP BY ALL HAVING count(*) > 1)"
    ).fetchone()[0]
    needs_extracted_at = has_extracted_at(config.SOURCE)
    values = ([r[0] for r in con.execute("SELECT DISTINCT ExtractedAtUtc FROM src").fetchall()]
              if needs_extracted_at else [])
    errors = validate_extract(row_count, values, duplicate_keys, needs_extracted_at)
    if errors:
        raise SystemExit(f"Extract guard failed for source {config.SOURCE!r}: " + "; ".join(errors))

    extracted_at = to_utc_iso(values[0]) if needs_extracted_at else datetime.now(timezone.utc).isoformat()
    df = con.execute(f"SELECT {COLUMNS} FROM src").df()
    df.to_parquet(OUT_PATH, index=False)
    with open(META_OUT, "w", encoding="utf-8") as f:
        json.dump({"source": config.SOURCE, "extractedAtUtc": extracted_at, "rows": row_count}, f)

    print(f"Extracted {row_count:,} rows from {config.SOURCE} in {time.time() - start:.1f} sec; "
          f"data as of {extracted_at}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Brian grants the service principal read access to DP_Staging Dev.** In DP - Staging - Dev, open the **DP_Staging** lakehouse → Share → enter "Parts Lookup Refresh Pipeline" → tick **Read all OneLake data** → Grant.
  - If the dialog won't accept a service principal, give it the **Viewer** workspace role instead (Manage access) and retry Step 4.
  - If Viewer can't read OneLake files, use **Contributor**, which is what it has on LH_Master_Data today.

  Record which level worked.

- [ ] **Step 4: Run the extract against Dev with the test env file**

Run: `cd "c:/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/parts-lookup-static-prototype" && PARTS_LOOKUP_ENV_FILE=.env.test python extract.py && python -c "import json; print(json.load(open('extract_meta.json')))"`

Expected:
- `Extracted 1,06x,xxx rows from dp-dev in NN sec; data as of 2026-10-…+00:00`;
- the meta shows `source` `dp-dev` and the same `extractedAtUtc` as the Dev table's `ExtractedAtUtc`.

If the `python -c` is blocked by the hook, open `extract_meta.json` with Read instead.

- [ ] **Step 5: Run the extract in LH mode (rollback path)**

Run: `PARTS_LOOKUP_ENV_FILE=.env.test PARTS_LOOKUP_SOURCE=lh python extract.py`
Expected: `Extracted 1,06x,xxx rows from lh …`, with no guard failure. The shell variable wins over the file, because `load_dotenv` doesn't override existing variables.

- [ ] **Step 6: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/config.py" ".claude/queries/adhoc/parts-lookup-static-prototype/extract.py"
git commit -m "Parts Lookup pipeline: selectable source (lh/dp/dp-dev) with publish guards and extract_meta.json"
```

---

## Task 12: `run_refresh.py`, `upload.py`, `check_staleness.py`, `.env.example`

**Files:**
- Modify: `P/run_refresh.py`
- Modify: `P/upload.py`
- Modify: `P/check_staleness.py`
- Modify: `P/.env.example`

- [ ] **Step 1: `P/upload.py`.** Add `from refresh_logic import upload_order` after `import config`, and in `main()` replace the `files = sorted(...)` expression with:

```python
    files = upload_order(
        glob.glob(os.path.join(SOURCE_DIR, "*.json"))
        + glob.glob(os.path.join(SOURCE_DIR, "*.json.gz"))
    )
```

Add to the comment above it: `_meta.json is uploaded last (refresh_logic.upload_order), so the app's "Data as of" never moves ahead of the partition files.`

- [ ] **Step 2: `P/run_refresh.py`: imports and constants.**
  - Add `from refresh_logic import build_meta, should_skip` after the `import config` try-block. It must come after that block, because the block exits on a broken config before anything else.
  - Replace the `STEPS = [...]` line with:

```python
EXTRACT_META_PATH = "extract_meta.json"     # written by extract.py: {"source", "extractedAtUtc", "rows"}
LAST_PUBLISHED_PATH = "last_published.json"  # written here after a fully successful upload
```

- [ ] **Step 3: Replace `write_meta_file` and `run_pipeline`** with the following:

```python
def now_utc_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def read_json_key(path: str, key: str):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f).get(key)
    except FileNotFoundError:
        return None


def write_meta_file(extracted_at: str) -> None:
    """Write output/2char/_meta.json: generatedAt = the data's load time (ExtractedAtUtc from the DP table,
    via extract_meta.json), publishedAt = now. upload.py uploads it last. The app's "Data as of" and stale
    banner, and check_staleness.py, all read generatedAt, so they measure how old the data really is -
    not when this script last ran (until 2026-10 it was the run time, which made a failed upstream load
    look fresh)."""
    meta_path = os.path.join("output", "2char", "_meta.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(build_meta(extracted_at, now_utc_iso()), f)


def run_step(step: str) -> bool:
    """Run one step script; log its output (upload.py: last line only). False (logged + alerted) on failure."""
    try:
        result = subprocess.run(
            [sys.executable, step],
            capture_output=True,
            text=True,
            timeout=STEP_TIMEOUT_SEC,
        )
    except subprocess.TimeoutExpired as exc:
        partial_stderr = redact((exc.stderr or "").strip())[-500:]
        log_failure(
            f"FAILED at {step}: exceeded {STEP_TIMEOUT_SEC}s timeout and was "
            f"killed. Partial stderr: {partial_stderr}"
        )
        return False

    if result.returncode != 0:
        safe_stderr = redact(result.stderr.strip())[-500:]
        log_failure(f"FAILED at {step}: {safe_stderr}")
        return False

    lines = redact(result.stdout.strip()).splitlines()
    if step == "upload.py":
        # Real-time per-file progress (~1,250 lines/run) is useful when upload.py is run standalone for live
        # debugging, but copying all of it into refresh.log would bloat it unboundedly at hourly cadence -
        # keep only the final summary line, matching extract.py/partition.py's already-concise output.
        lines = lines[-1:] if lines else []
    for line in lines:
        log(f"  [{step}] {line}")
    return True


def run_pipeline() -> int:
    log("=== refresh run starting ===")
    if not run_step("extract.py"):
        log("=== refresh run FAILED ===")
        return 1

    extracted_at = read_json_key(EXTRACT_META_PATH, "extractedAtUtc")
    if not extracted_at:
        log_failure(f"FAILED: {EXTRACT_META_PATH} has no extractedAtUtc")
        log("=== refresh run FAILED ===")
        return 1
    if should_skip(extracted_at, read_json_key(LAST_PUBLISHED_PATH, "extractedAtUtc")):
        # No new load since the last publish (between loads, after 17:00, or the load failed - which
        # Pipeline_PartsAvailability alerts on, and check_staleness.py notices as the data ages).
        log(f"SKIPPED - source unchanged (data as of {extracted_at})")
        log("=== refresh run completed: nothing new to publish ===")
        return 0

    if not run_step("partition.py"):
        log("=== refresh run FAILED ===")
        return 1
    try:
        # After partition.py (which clears output/2char/) and before upload.py, so this cycle's upload
        # carries it.
        write_meta_file(extracted_at)
    except OSError as exc:
        log_failure(f"FAILED at write_meta_file: {exc}")
        log("=== refresh run FAILED ===")
        return 1
    if not run_step("upload.py"):
        log("=== refresh run FAILED ===")
        return 1

    try:
        with open(LAST_PUBLISHED_PATH, "w", encoding="utf-8") as f:
            json.dump({"extractedAtUtc": extracted_at, "publishedAt": now_utc_iso()}, f)
    except OSError as exc:
        # Published fine; only the skip bookkeeping failed, so the next run republishes the same data.
        log_failure(f"Published, but could not write {LAST_PUBLISHED_PATH} ({exc}) - the next run will "
                    "upload the same data again")
    log(f"=== refresh run completed successfully (data as of {extracted_at}) ===")
    return 0
```

Also update the module docstring's first paragraph to: "Runs extract.py, then (unless the source hasn't changed since the last publish) partition.py and upload.py, …", and add a paragraph:

```
DP source (2026-10): extract.py reads config.SOURCE and writes
extract_meta.json with the load's ExtractedAtUtc. A run whose
ExtractedAtUtc equals last_published.json's is SKIPPED (logged, exit 0),
so the 18-minute upload only happens when there is a new load.
_meta.json's generatedAt is the load time, not this run's time.
```

- [ ] **Step 4: `P/check_staleness.py`.**
  - Replace the docstring's schedule sentence ("Run on its own Task Scheduler task, offset ~45 minutes … Mon-Fri 8am-8pm window …") with: `Runs on its own Task Scheduler task at :45 past each hour, 07:45-17:45 Mon-Fri (the refresh runs 07:00-17:00, the loads 06:50-16:50). Since 2026-10 generatedAt is the data's load time (ExtractedAtUtc), so this also catches a failed or missing upstream load, not just a stopped task.`
  - Replace the failure message with:

```python
        run_refresh.log_failure(
            f"STALE CHECK: data is {age_minutes:.0f} min old (threshold "
            f"{STALE_THRESHOLD_MINUTES} min) - newest published data is from "
            f"{generated_at.isoformat()}. Check Pipeline_PartsAvailability (DP - Presentation - Prod; "
            "it emails on a failed load) and the 'Parts Lookup Refresh' task on this PC."
        )
```

- [ ] **Step 5: `P/.env.example`.** Append:

```
# Optional (2026-10): which table extract.py reads - lh | dp | dp-dev (default in config.py).
# PARTS_LOOKUP_SOURCE=dp
# Test runs: copy this file to .env.test with the STAGING library's DRIVE_ID, no TEAMS_WEBHOOK_URL and
# PARTS_LOOKUP_SOURCE=dp-dev, then run with PARTS_LOOKUP_ENV_FILE=.env.test.
```

- [ ] **Step 6: Run the unit tests again** (the code under test is unchanged; this catches import mistakes).

Run: `python -m pytest test_refresh_logic.py -q && python -c "import ast,sys; [ast.parse(open(f,encoding='utf-8').read()) for f in ['run_refresh.py','upload.py','check_staleness.py','extract.py','config.py']]; print('parse ok')"`
Expected: `7 passed`, `parse ok`.

- [ ] **Step 7: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/run_refresh.py" ".claude/queries/adhoc/parts-lookup-static-prototype/upload.py" ".claude/queries/adhoc/parts-lookup-static-prototype/check_staleness.py" ".claude/queries/adhoc/parts-lookup-static-prototype/.env.example"
git commit -m "Parts Lookup pipeline: skip unchanged loads, _meta = data load time, upload _meta last"
```

---

## Task 13: End-to-end test publish (Dev source → staging library)

**Files:**
- Create: `P/verify_publish.py`

- [ ] **Step 1: Write `P/verify_publish.py`**

```python
"""
PARTS LOOKUP REFRESH PIPELINE - VERIFY A PUBLISH
============================================================================
Downloads _meta.json, _manifest.json, the largest partition file and a
fixed random sample of others from the SharePoint library in the current
env file (PARTS_LOOKUP_ENV_FILE, default .env) and compares their decoded
JSON with the local output/2char/ files. Read-only on SharePoint.

Usage: python verify_publish.py [sample_size]     (default 20)
Exit 0 when every checked file matches.
============================================================================
"""

import glob
import gzip
import json
import os
import random
import sys

import requests

import config
from upload import GRAPH_BASE, get_access_token

LOCAL_DIR = os.path.join("output", "2char")


def download(name: str, token: str) -> bytes:
    url = f"{GRAPH_BASE}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}/root:/{name}:/content"
    r = requests.get(url, headers={"Authorization": f"Bearer {token}"}, timeout=(10, 120))
    r.raise_for_status()
    return r.content


def decode(name: str, data: bytes):
    return json.loads(gzip.decompress(data) if name.endswith(".gz") else data)


def main(sample_size: int = 20) -> int:
    token = get_access_token()
    paths = glob.glob(os.path.join(LOCAL_DIR, "*.json*"))
    parts = sorted(os.path.basename(p) for p in paths if not os.path.basename(p).startswith("_"))
    largest = os.path.basename(max(paths, key=os.path.getsize))
    sample = random.Random(0).sample(parts, min(sample_size, len(parts)))
    names = ["_meta.json", "_manifest.json", largest] + [n for n in sample if n != largest]
    bad = 0
    for name in names:
        with open(os.path.join(LOCAL_DIR, name), "rb") as f:
            local = decode(name, f.read())
        same = local == decode(name, download(name, token))
        bad += not same
        print(f"{'OK ' if same else 'BAD'} {name}")
    print("library:", config.LIBRARY_BASE)
    print("remote _meta.json:", decode("_meta.json", download("_meta.json", token)))
    print("PASS" if not bad else f"FAIL ({bad} file(s) differ)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 20))
```

- [ ] **Step 2: Make sure the run will publish.** Brian's PC's own copy has never run the new code, so there's no `last_published.json` yet. Check: `ls last_published.json` should report no such file.

- [ ] **Step 3: Full run against Dev → staging library**

Run: `cd "c:/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/parts-lookup-static-prototype" && PARTS_LOOKUP_ENV_FILE=.env.test python run_refresh.py`

Expected, in about 20 minutes, at the end of `refresh.log`:
- `[extract.py] Extracted … from dp-dev … data as of <Dev ExtractedAtUtc>`;
- the partition summary;
- `[upload.py] Uploaded ~1,38x files …`;
- `=== refresh run completed successfully (data as of …) ===`.

There's no Teams post, because `.env.test` has no webhook.

- [ ] **Step 4: Verify the publish**

Run: `PARTS_LOOKUP_ENV_FILE=.env.test python verify_publish.py`
Expected:
- every line `OK`;
- `library:` shows the **staging** library;
- remote `_meta.json` `generatedAt` equals the Dev `ExtractedAtUtc`, with a `publishedAt`;
- `PASS`.

- [ ] **Step 5: Skip run**

Run: `PARTS_LOOKUP_ENV_FILE=.env.test python run_refresh.py`
Expected: within about 30 seconds, `SKIPPED - source unchanged (data as of …)` and `=== refresh run completed: nothing new to publish ===`.

- [ ] **Step 6: Guard drill (no publish).** Run the real `extract.py` with the row minimum raised past the real row count, so the guard must refuse. Run:

`PARTS_LOOKUP_ENV_FILE=.env.test python -c "import refresh_logic; refresh_logic.MIN_ROWS = 10**9; import runpy; runpy.run_path('extract.py', run_name='__main__')"`

Expected: exit non-zero with `Extract guard failed for source 'dp-dev': only 1,06x,xxx rows (expected at least 1,000,000,000) …`. If the hook blocks `python -c`, put those two lines in `<scratchpad>/guard_drill.py` (with `os.chdir` to `P`) and run that.

- [ ] **Step 7: Clean up local test state** (local generated files only, nothing in Git or SharePoint): delete `extract_meta.json` and `last_published.json` in `P`. Leaving them would make Brian's PC's disabled fallback copy believe a Dev load was published.

- [ ] **Step 8: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/verify_publish.py"
git commit -m "Parts Lookup pipeline: verify_publish.py (compare a library's files with the local output)"
git push origin dev
```

---

## Task 14: App: stale banner window 08:00–18:00

**Files** (repo `c:/Users/bfox/Documents/Git-Projects/parts-lookup-app`, branch `dev`):
- Modify: `src/__tests__/dataService.test.ts`
- Modify: `src/services/dataService.ts:205-231`

- [ ] **Step 1: Change the tests first.** In `src/__tests__/dataService.test.ts`, replace the test `'is never flagged stale during the 8pm hour (last scheduled trigger may still be running)'` with:

```ts
  it('is still checked at 5:30pm (inside the 8am-6pm window)', async () => {
    const { isDataStale } = await freshDataService();
    const fiveThirtyPm = new Date('2026-08-26T17:30:00');
    expect(isDataStale(minutesAgo(fiveThirtyPm, 100), fiveThirtyPm)).toBe(true);
  });

  it('is never flagged stale from 6pm (the last load is 16:50; it passes 90 min around 18:20)', async () => {
    const { isDataStale } = await freshDataService();
    const sixPm = new Date('2026-08-26T18:00:00');
    expect(isDataStale(minutesAgo(sixPm, 500), sixPm)).toBe(false);
  });
```

- [ ] **Step 2: Run the tests to make sure the 6pm one fails**

Run: `cd c:/Users/bfox/Documents/Git-Projects/parts-lookup-app && npm test -- dataService`
Expected: FAIL on `is never flagged stale from 6pm` (the window still runs to 20:00).

  Also (Brian, 2026-10-14) the threshold goes from 90 to **120 minutes**, so update the threshold tests:
  - In `'is stale when older than the threshold, during business hours'`, use 150 minutes instead of 120.
  - Rename `'is not stale exactly at the threshold boundary (90 min)'` to `(120 min)` and use 120.
  - Add `'is not stale at 100 minutes (a healthy hour peaks near 90)'`, expecting `false`.

- [ ] **Step 3: Change `src/services/dataService.ts`**:
  - `const STALE_THRESHOLD_MINUTES = 90;` → `const STALE_THRESHOLD_MINUTES = 120;`. Update its comment: generatedAt is the load start (hh:50) and a publish lands around (hh+1):20, so a healthy hour peaks near 90 minutes; it must match `check_staleness.py`.
  - `const BUSINESS_END_HOUR = 20;` → `const BUSINESS_END_HOUR = 18;`
  - In the `isDataStale` doc comment, replace "Deliberately never flags staleness outside Mon-Fri 8am-8pm local time -" with "Deliberately never flags staleness outside Mon-Fri 8am-6pm local time (since 2026-10 the data loads hourly 06:50-16:50 and `generatedAt` is the load time, so the last load passes 90 minutes around 18:20) -".

- [ ] **Step 4: Run all tests and lint**

Run: `npm test && npm run lint`
Expected: all pass, lint clean.

- [ ] **Step 5: Commit and push `dev`** (not deployed yet; that's Task 16)

```bash
git add src/services/dataService.ts src/__tests__/dataService.test.ts
git commit -m "Stale banner window 8am-6pm: data now loads 06:50-16:50 and generatedAt is the load time"
git push origin dev
```

- [ ] **Step 6: Open the PR `dev → main`** (Brian merges it in Task 16):

```bash
gh pr create --base main --head dev --title "Stale banner window 8am-6pm (Parts Availability DP feed)" --body "Part of the Parts Availability move to DP (data-projects spec 2026-10-14-parts-availability-dp-feed-design.md). The data now loads hourly 06:50-16:50 and _meta.json's generatedAt becomes the load time, so the last load passes the 90-minute threshold around 18:20; the banner window ends at 18:00 instead of 20:00. Harmless before the cutover (the pipeline still stamps run time).

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Task 15: Prod release of the DP items

- [ ] **Step 1: Preview and PR**

Run: `cd c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs && python deploy/merge_preview.py`
Expected: the diff lists only this plan's items, plus anything else already on `dev`. Show Brian anything unexpected.

Then open the PR `dev → main` with the template `.github/PULL_REQUEST_TEMPLATE/dev_to_main.md`: `gh pr create --base main --head dev --title "Parts Availability DP feed" --body-file <filled template>`. In the template's prerequisites section, list:
- **first:** run `Pipeline_PartsAvailability` once in Prod;
- **then:** set its schedule (Task 15 Step 4);
- **service principal access:** grant Prod DP_Staging access to the "Parts Lookup Refresh Pipeline" SPN (Step 5).

- [ ] **Step 2: Brian merges** ("Create a merge commit") and runs **Deploy DP backend**.

  Then run:

```bash
python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/wait_ci.py c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs
git fetch origin && git merge --ff-only origin/main && git push origin dev
```

Expected: the deploy log says `(5 item ID swaps for the pipelines)`.

- [ ] **Step 3: Check the Prod items, and that the pipeline's IDs were swapped.** Write `<scratchpad>/prod_items.py`:

```python
import json, subprocess, os, base64
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
def api(path, method=None):
    out = subprocess.run(["fab", "api", path] + (["-X", method] if method else []), capture_output=True, text=True, encoding="utf-8").stdout
    i = out.find("{"); return json.loads(out[i:out.rfind("}") + 1])
STG, PRS = "189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "7836042d-adb1-4846-b70d-bd42980054c5"
names = {"df_PartsAvailability_Raw", "Notify_PartsAvailability", "Pipeline_PartsAvailability"}
found = {}
for ws in (STG, PRS):
    for it in api(f"workspaces/{ws}/items")["text"]["value"]:
        if it["displayName"] in names:
            found[it["displayName"]] = (ws, it["id"]); print(it["type"], it["displayName"], it["id"])
ws, pid = found["Pipeline_PartsAvailability"]
d = api(f"workspaces/{ws}/items/{pid}/getDefinition", "post")
body = next(base64.b64decode(p["payload"]).decode() for p in d["text"]["definition"]["parts"] if p["path"] == "pipeline-content.json")
print("dataflow ID is Prod:", found["df_PartsAvailability_Raw"][1] in body)
print("notifier ID is Prod:", found["Notify_PartsAvailability"][1] in body)
print("staging WS is Prod:", STG in body)
```

Run: `python <scratchpad>/prod_items.py`
Expected: three items listed; all three checks `True`.

- [ ] **Step 4: Brian's Prod steps.**
  1. Open `Pipeline_PartsAvailability` in DP - Presentation - Prod and press **Run**. Expected: Succeeded. This first load creates `PartsAvailability` in Prod DP_Staging.
  2. **Schedule:** Weekly; Monday–Friday; times 06:50, 07:50, 08:50, 09:50, 10:50, 11:50, 12:50, 13:50, 14:50, 15:50, 16:50; time zone Central; start today; **end date as late as the picker allows**. **Leave Fabric's failure notification off** (the pipeline sends its own).
  3. Tell Claude the schedule is saved.

  Then confirm the schedule (end date and times) with the `jobs/Pipeline/schedules` call used in Task 2's investigation:
  `fab api "workspaces/7836042d-adb1-4846-b70d-bd42980054c5/items/<pipeline id>/jobs/Pipeline/schedules"`.
  Expected: `enabled: true`, 11 times, the 5 weekdays, and a far-future `endDateTime`. Record the end date in the progress note.

- [ ] **Step 5: Brian grants SPN read access to DP_Staging Prod,** at the same level that worked in Task 11 Step 3.

- [ ] **Step 6: Check the first Prod load**

Run: `python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/parts_availability_check.py prod`
Expected: at least one pair (if the first load was within 10 minutes of an LH :50 load; otherwise wait for the first scheduled load), and `PASS`.

---

## Task 16: Parallel run (3 business days)

- [ ] **Step 1: Each afternoon after 17:00,** run `python c:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/parts_availability_check.py prod`.
  - **Expected:** 10 pairs (07:50–16:50) and `PASS`. Record each day's result line in the progress note.
  - **A `FAIL`:** investigate before continuing.
  - **A missing pair:** check both pipelines' runs. A failed DP load should also have produced the custom alert email.

- [ ] **Step 2 (day 1): Put the new Gateway PC code on the PC in LH mode.**
  1. Brian, on the Gateway PC (RDP or VS Code tunnel): `cd C:\data-projects; git pull origin dev`.
  2. `config.py`'s default is still `"lh"`, so behaviour is unchanged except for the guards, `_meta` going last and the new `publishedAt` field.
  3. Watch the next hourly run in `refresh.log`: `completed successfully (data as of <the run's own time>)`.
  4. **Expected:** the app still shows fresh data. Because LH mode stamps run time, `last_published.json` never matches and **nothing skips in LH mode**; that's expected.

- [ ] **Step 3 (day 1): Deploy the app's 18:00 window.**
  1. Brian merges the app PR from Task 14.
  2. On the Server 2016 box, run `deploy.ps1`.
  3. Check that `https://go-parts.spitractor.com` loads and a lookup works.
  4. Harmless in LH mode: the pipeline still stamps fresh times until 20:00, so no banner can show.

- [ ] **Step 4 (day 2): One staging publish from the Prod DP source.**

Run (from Brian's PC): `PARTS_LOOKUP_ENV_FILE=.env.test PARTS_LOOKUP_SOURCE=dp python run_refresh.py && PARTS_LOOKUP_ENV_FILE=.env.test python verify_publish.py`
Expected:
- `from dp … data as of <latest Prod ExtractedAtUtc>`;
- the upload completes;
- `verify_publish` `PASS`, with `library:` the **staging** library.

Then delete `extract_meta.json` and `last_published.json` locally, as in Task 13 Step 7.

- [ ] **Step 5: Tell Brian the parallel run passed** and agree a cutover evening.

---

## Task 17: Cutover (a weekday evening, after the 17:00 run has finished, ~17:20)

Every step needs Brian's go-ahead at the time.

- [ ] **Step 1: Flip the default source.** In `P/config.py` change `SOURCE = os.environ.get("PARTS_LOOKUP_SOURCE", "lh")` to `SOURCE = os.environ.get("PARTS_LOOKUP_SOURCE", "dp")`, and the comment above it to `# Which table extract.py reads (see refresh_logic.SOURCES): "dp" since the cutover on <date>; "lh" to roll back.`

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/config.py"
git commit -m "Parts Lookup pipeline: read DP (cutover)"
git push origin dev
```

- [ ] **Step 2: Brian on the Gateway PC: pull, then publish once by hand.**

```powershell
cd C:\data-projects
git pull origin dev
cd .claude\queries\adhoc\parts-lookup-static-prototype
python run_refresh.py
Get-Content refresh.log -Tail 8
```

Expected:
- `[extract.py] Extracted … from dp … data as of <today 21:5x UTC>` (16:50 Central);
- the upload completes;
- `completed successfully (data as of …)`.

In the app, "Data as of" shows today ~4:50 PM.

- [ ] **Step 3: Brian updates the two tasks' triggers** on the Gateway PC (PowerShell; `Get-Credential` keeps the password out of history):

```powershell
$cred = Get-Credential -UserName "SPI\bfox" -Message "Domain password - the tasks run whether or not you're logged on"

$refresh = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 7:00AM
$refresh.Repetition = (New-ScheduledTaskTrigger -Once -At 7:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Hours 10 -Minutes 1)).Repetition
Set-ScheduledTask -TaskName "Parts Lookup Refresh" -Trigger $refresh -User $cred.UserName -Password $cred.GetNetworkCredential().Password

$stale = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 7:45AM
$stale.Repetition = (New-ScheduledTaskTrigger -Once -At 7:45AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Hours 10 -Minutes 1)).Repetition
Set-ScheduledTask -TaskName "Parts Lookup Staleness Check" -Trigger $stale -User $cred.UserName -Password $cred.GetNetworkCredential().Password

foreach ($t in "Parts Lookup Refresh", "Parts Lookup Staleness Check") {
  $task = Get-ScheduledTask -TaskName $t
  $task.Triggers | Select-Object StartBoundary, @{n='Every';e={$_.Repetition.Interval}}, @{n='For';e={$_.Repetition.Duration}}
  ($task | Get-ScheduledTaskInfo).NextRunTime
}
```

Expected:
- Refresh: StartBoundary 07:00, Every `PT1H`, For `PT10H1M`, next run tomorrow 07:00 (or Monday).
- Staleness: the same at 07:45.
- The action and "run whether user is logged on or not" are unchanged; check in Task Scheduler → Properties.

- [ ] **Step 4: Next morning, watch the first day**
  - 06:50: the `Pipeline_PartsAvailability` run Succeeded (Fabric Monitor).
  - 07:00: `refresh.log` shows `from dp … data as of <today 11:50 UTC>`, published by about 07:20.
  - 07:45: `STALE CHECK: OK`.
  - **08:00: open the app. There must be no stale banner, and "Data as of" must be 6:50 AM.**
  - Hourly through 17:00: `completed successfully` after each load.
  - Evening: no banner after 18:00.

  Record the results in the progress note.

**Rollback (if needed, while the LH schedule is still on):**
1. Revert Step 1, push, and `git pull` on the Gateway PC.
2. Put the triggers back to 08:00 for 12 hours (Step 3 with `-At 8:00AM` / `8:45AM` and `-Hours 12`).
3. Run `python run_refresh.py` once.

---

## Task 18: Retire the LH feed (after ~5 clean business days on DP)

- [ ] **Step 1: Confirm 5 clean days.** That means:
  - DP loads all succeeded (no alert emails, or each explained);
  - `refresh.log` has no failures;
  - no stale banner reports.

  **Then ask Brian for the OK** to switch off `df_InMaster_PartsLookup_Raw`'s schedule.

- [ ] **Step 2: Brian disables (not deletes) the LH schedule:** LH_Master_Data → `df_InMaster_PartsLookup_Raw` → Schedule → Off. Verify:

Run: `fab api "workspaces/b48cdb35-7ce3-46de-96df-d70db77649cb/items/ec4dd817-742a-4258-8ee3-002670c55101/jobs/Refresh/schedules"`
Expected: `"enabled": false`.

- [ ] **Step 3: Update `docs/architecture/lh-master-data-retirement.md`.**
  - Replace the Parts Availability consumer row with:
    `| **Parts Availability** app | DP_Staging \`PartsAvailability\` (Pipeline_PartsAvailability, hourly) since <cutover date> | **Off LH** <date>. The LH table \`InMaster_PartsLookup_Raw\` is frozen; nothing reads it |`
  - Replace the `df_InMaster_PartsLookup_Raw` schedule row's status with:
    `**OFF <date>** (Brian), after 5 clean days on DP. Replaced by DP's df_PartsAvailability_Raw + Pipeline_PartsAvailability (plan docs/superpowers/plans/2026-10-14-parts-availability-dp-feed.md)`
  - Change the status note to say all 14 LH schedules are off.

- [ ] **Step 4: Hand Brian the cleanup list** for a separate decision. **Nothing is deleted in this plan.**
  - `parts-lookup-app` Fabric App (AppBackend + SQLDatabase + SQLEndpoint) in RP - Fabric Apps;
  - LH items: `df_InMaster_PartsLookup_Raw`, `df_InMaster_PartsLookup_Incremental`, `df_PartsLookup_Sync`, `df_PartsLookup_Sync_Incremental`, `Pipeline_Parts_Lookup_App`, `Pipeline_PartsLookup_Incremental`, `Update_Watermark_PartsLookup`, `Parts_Availability_App_WaterMark`;
  - the LH table `InMaster_PartsLookup_Raw`;
  - the disabled "Parts Lookup Refresh" fallback task on Brian's PC (it would now read DP too; keep or remove);
  - the "Parts Lookup Refresh Pipeline" service principal's **Contributor** role on LH_Master_Data (no longer needed).

- [ ] **Step 5: Commit**

```bash
git add docs/architecture/lh-master-data-retirement.md
git commit -m "LH retirement: Parts Availability off LH; df_InMaster_PartsLookup_Raw schedule off"
```

---

## Task 19: Docs and memory

- [ ] **Step 1: `projects/parts lookup tool - app/ARCHITECTURE.md`.** Insert at the top, after the title, the section below. Then rename the next heading `## Data Flow` to `## History (superseded): the Fabric App design, 2026-07 to 2026-08` and demote the old sections under it by one heading level.

```markdown
## Current architecture (2026-10)

The app is a React PWA served by IIS on Windows Server 2016 (`https://go-parts.spitractor.com`), signed in with MSAL. It reads **static gzipped JSON files from SharePoint** through Microsoft Graph with each user's own token. It no longer uses Fabric Apps (Rayfin) or a SQL database. The `parts-lookup-app` Fabric App still exists, unused; deleting it needs Brian's OK.

```
Equip InMaster (ODBC dsn=EquipRDB64, SPI-Data-Gateway)
  → df_PartsAvailability_Raw (DP - Staging)        weekdays 06:50–16:50 hourly, via Pipeline_PartsAvailability (DP - Presentation)
  → DP_Staging.PartsAvailability (+ ExtractedAtUtc)
  → Gateway PC SPI00T4022W11, Task Scheduler       weekdays 07:00–17:00 hourly: run_refresh.py → extract → partition → upload
  → SharePoint library (~1,380 prefix files + _manifest.json + _meta.json)
  → app (Data as of = _meta.json generatedAt = the load's ExtractedAtUtc)
```

- **Alerts:**
  - a failed load sends an email plus a Teams post (`Notify_PartsAvailability`: what happened, likely cause, what to do);
  - Gateway PC failures and data older than 90 minutes post to Teams;
  - app downtime posts to Teams;
  - the DP morning email warns if `PartsAvailability` is more than 4 days old.
- **Why ODBC and not JD Bronze:** cost (about 750 CU(s) per load against about 6,500 per JD Incremental run) and accuracy (Pending_Qty changes don't bump JD's watermark).
- **References:**
  - spec `docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md`;
  - pipeline code `.claude/queries/adhoc/parts-lookup-static-prototype/`;
  - runbook fabric-workspace-docs `OPERATIONS-GUIDE.md` → "Parts Availability feed".
```

- [ ] **Step 2: `P/README.md`.** Add a section after the title:

```markdown
## Production status (2026-10)

This folder is the live refresh pipeline for the Parts Availability app, not just the August prototype:
- It runs on the Gateway PC (see `GATEWAY-PC-PIPELINE-DEPLOYMENT.md`).
- Since the DP cutover it reads `DP_Staging.PartsAvailability` (`config.SOURCE`, default `"dp"`).
- It skips runs whose `ExtractedAtUtc` was already published, and writes the load time to `_meta.json`.

**Tests:** `python -m pytest test_refresh_logic.py -q`.
**Test publishes:**
- `PARTS_LOOKUP_ENV_FILE=.env.test python run_refresh.py` uploads to the "Parts Availability - Staging" library (no Teams alerts);
- `verify_publish.py` checks a publish.
```

- [ ] **Step 3: `P/GATEWAY-PC-PIPELINE-DEPLOYMENT.md`.**
  - In "Where it lives", change the scheduled-tasks cell to `Parts Lookup Refresh (hourly, Mon-Fri 07:00-17:00), Parts Lookup Staleness Check (hourly at :45, 07:45-17:45), Parts Availability App Uptime Check (every 15 min, all day)`.
  - Add a section "DP cutover (<date>)" containing:
    - Task 17 Step 3's PowerShell;
    - the files `extract_meta.json` and `last_published.json` (what each holds, and that deleting `last_published.json` forces the next run to republish);
    - the rollback steps from Task 17;
    - the line "The service principal reads DP_Staging Prod (access: <level from Task 11 Step 3>)".

- [ ] **Step 4: `docs/architecture/jd-bronze-raw-sources-catalog.md`.** Replace the `df_InMaster_PartsLookup_Raw` row in the InMaster consolidation table with:

```markdown
| `df_InMaster_PartsLookup_Raw` | `InMaster_PartsLookup_Raw` | **Replaced <cutover date>; schedule off <date>** | Parts Availability now reads DP_Staging `PartsAvailability` from `df_PartsAvailability_Raw` (ODBC, hourly). Deliberately not Bronze: hourly JD Incremental would cost ~9-10x, and Pending_Qty changes don't bump JD's watermark (measured 2026-10-13/14; spec 2026-10-14-parts-availability-dp-feed-design.md) |
```

- [ ] **Step 5: fabric-workspace-docs `OPERATIONS-GUIDE.md`.** Add a section "Parts Availability feed":

```markdown
## Parts Availability feed

- **What:** `Pipeline_PartsAvailability` (DP - Presentation) refreshes `df_PartsAvailability_Raw` (DP - Staging, ODBC `dsn=EquipRDB64`) into `DP_Staging.PartsAvailability`.
  - **When:** weekdays 06:50–16:50 hourly (Prod schedule, owned by Brian; the dataflow runs as the schedule owner).
  - **Downstream:** the Gateway PC (`SPI00T4022W11`) publishes the table to SharePoint for the app at 07:00–17:00.
  - **Not part of** `Pipeline_DP_Refresh` (`cadence: manual`).
- **A failed load:** `Notify_PartsAvailability` emails the alert list and posts to Teams with the likely cause and what to do. The app keeps showing the last good data. The next load retries automatically.
- **Run it by hand:** open `Pipeline_PartsAvailability` → Run. Or refresh the dataflow alone; the Gateway PC picks the new load up at its next hourly run, or run `python run_refresh.py` there.
- **Schedule end date:** <from Task 15 Step 4>. Fabric schedules stop silently at their end date; the DP morning email's freshness check warns after 4 days without a load.
- **Check against LH** (until LH is deleted): `python tools/dp-migration/parts_availability_check.py prod` (data-projects).
```

- [ ] **Step 6: fabric-workspace-docs `docs/TROUBLESHOOTING.md`.** Add rows to the refresh table:

```markdown
| "🔴 [Prod] Parts Availability: the HH:50 data load failed" email | `df_PartsAvailability_Raw` failed after one retry; the email names the likely cause | Follow the email's "What to do"; the next hourly load retries. Two in a row: run Pipeline_PartsAvailability by hand and check the gateway |
| Parts Availability shows the stale banner during business hours | No new load published for 90+ minutes: a failed load (check for the alert email), the Gateway PC task not running, or an expired schedule | Fabric Monitor → Pipeline_PartsAvailability; Gateway PC `refresh.log`; the schedule's end date |
```

- [ ] **Step 7: Commit both repos**

```bash
cd c:/Users/bfox/Documents/Git-Projects/data-projects
git add "projects/parts lookup tool - app/ARCHITECTURE.md" ".claude/queries/adhoc/parts-lookup-static-prototype/README.md" ".claude/queries/adhoc/parts-lookup-static-prototype/GATEWAY-PC-PIPELINE-DEPLOYMENT.md" docs/architecture/jd-bronze-raw-sources-catalog.md docs/superpowers/plans/2026-10-14-parts-availability-dp-feed.md
git commit -m "Docs: Parts Availability on DP (architecture, Gateway PC runbook, Bronze catalog)"
git push origin dev
cd c:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs
git add OPERATIONS-GUIDE.md docs/TROUBLESHOOTING.md
git commit -m "Ops guide + troubleshooting: Parts Availability feed"
git push origin dev
```

- [ ] **Step 8: Memory.**
  - Rewrite `C:\Users\bfox\.claude\projects\c--Users-bfox-Documents-Git-Projects-data-projects\memory\project_parts_lookup_tool.md` as a short current-state note: the static-file app on IIS + SharePoint, the DP feed (pipeline, schedule, alerts), the Gateway PC pipeline, the cleanup list pending Brian's decision, and links to the spec, plan and ARCHITECTURE.md. Drop the superseded Fabric App narrative; it lives in ARCHITECTURE.md's history section.
  - Update its `MEMORY.md` line to `- [Parts Availability](project_parts_lookup_tool.md) — static-file app; fed from DP (Pipeline_PartsAvailability, hourly) since <date>; LH feed off`.
  - Update the MEMORY.md "LH_Master_Data retirement" line to "all 14 schedules OFF".
```
