# Customer Anatomy Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repoint the Customer Anatomy report (flagship, last report) from LH_Master_Data to DP_Presentation with verified parity, applying Brian's approved decisions (spec: `docs/superpowers/specs/2026-09-25-customer-anatomy-migration-design.md`).

**Architecture:** 10 existing Gold notebooks are brought up to standard and registered in waves 1–3:
- Wave 1: CustomerLookup, EngagedAcres, UniqueCustomersInvoiceLookup, EquipmentSales, PartsDetail, ServicePartsDetail.
- Wave 2: PartsInvoices, ServiceInvoices, ServiceDetail.
- Wave 3: CustomerPerformance.

Each notebook gets the UTC pin and VACUUM, and each fact is trimmed. The unique-customer lookup gets production's 2022+ window and a deterministic tie-break. Code reaches Fabric only through Git sync. The chain runs manually, parity is checked against production month by month, then Claude edits the report TMDL while Desktop is closed. Brian publishes, and Claude refreshes and verifies.

**Tech Stack:** PySpark notebooks (Fabric), Fabric Git sync (`updateFromGit`), GitHub Actions CI (config only for Dev), `fab` CLI/REST, DuckDB `delta_scan`, Power BI REST (refresh, executeQueries), TMDL/PBIP.

---

## Context every task needs

**Repos (both on branch `dev`):**
- `C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs`: the Fabric Git mirror.
- `C:/Users/bfox/Documents/Git-Projects/data-projects`: docs, plus the helpers in `tools/dp-migration/`.

**Single-writer rule.** The Dev workspaces are Fabric-Git-connected. Notebook code reaches them only one way:

**push → `wait_ci.py` → `git_sync.py <workspaceId>` → `run_item.py`.**

- **Never use `fab import`.**
- If `git_sync.py` refuses because an item changed on both sides, stop and report.
- CI for Dev only writes the pipeline config and checks that every registered notebook folder exists.
- New `.platform` files are written without a trailing newline. (This plan creates none.)

**Helpers** (`C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/`):

| Script | Exit codes |
|---|---|
| `run_item.py <ws> <id> RunNotebook\|Refresh` | 0 completed, 1 failed, 2 timeout, 3 already running, 4 ambiguous |
| `wait_ci.py` | 0 when the CI run for fabric-workspace-docs HEAD succeeds |
| `git_sync.py <ws>` | 0 when synced |
| `folder_check.py` | 0 when every registered notebook is in its repo folder |

Task 1 adds `git_status.py`, `refresh_model.py` and `dax_query.py`.

**Hygiene and safety:**
- **Stage only the named paths.** Both repos have many unrelated Desktop-session dirty files, so never use `-A`, `.` or `-u`.
- **Non-fast-forward push:** `git fetch origin && git merge origin/dev`, then push again (no rebase, no force).
- **Commit trailer:** `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Subagents use their own model's name.
- **Hook false positives:** Bash hooks and auto mode sometimes block commands that contain `VAR=$(...)`, `sleep`, or printenv/"exfiltration"-looking text. When that happens, run the *identical* command from a `.py`/`.sh` file in the session scratchpad, and mention it in the report.
- **Scratchpad** (can be wiped at any time; keep nothing durable there): `C:/Users/bfox/AppData/Local/Temp/claude/c--Users-bfox-Documents-Git-Projects-data-projects/ed03239b-4817-4e80-8f42-4dd2204a7945/scratchpad`.

**IDs.**

*Workspaces and lakehouses:*

| Item | ID |
|---|---|
| DP - Presentation - Dev workspace | `73fd5443-240e-410a-990a-98827f32c087` |
| DP_Presentation lakehouse | `966efc8a-16f9-423b-aa43-e368fcd8fb91` |
| SQL endpoint | `18effb0e-7bc2-47a1-854c-f4f2e8129145` |
| DP - Staging - Dev workspace | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` |
| DP_Staging lakehouse | `876255e0-d462-4697-adc1-4a655f5bb101` |
| LH_Master_Data workspace (production) | `b48cdb35-7ce3-46de-96df-d70db77649cb` |
| LH_Master_Data lakehouse (production) | `3e74497b-8c51-4a1a-91a1-888c59118f48` |
| RP - Dev workspace | `e888a4dc-a02d-4fd4-839d-5daa5763ab44` |
| Customer Anatomy semantic model (RP - Dev) | `2ecbf6e3-060e-440e-9131-4e8b25a4e25d` |
| Customer Anatomy report (RP - Dev) | `0d3d53ff-2b75-42f5-87e3-89277ae83d3f` |

*Customer Anatomy Gold notebooks* (Presentation workspace):

| Notebook | ID | Repo folder | Wave |
|---|---|---|---|
| Build_Gold_CustomerLookup | `056084ba-ec30-4c37-acd1-eb51da6cc566` | `Fact Tables/Customer Anatomy` | 1 |
| Build_Gold_EngagedAcres | `86b9f279-305b-4ab3-9a93-fcd76480dfd5` | `Fact Tables/Customer Anatomy` | 1 |
| Build_Gold_UniqueCustomersInvoiceLookup | `2548aec8-3aaa-4b62-8570-56f39fae50b5` | `Dimensions` | 1 |
| Build_Gold_EquipmentSales | `27755fb8-dc0a-41e3-8b07-bde87829a33f` | `Fact Tables/Customer Anatomy` | 1 |
| Build_Gold_PartsDetail | `4f00f98f-2016-4293-9cd4-8e6b3d50a06b` | `Fact Tables/Customer Anatomy` | 1 |
| Build_Gold_ServicePartsDetail | `26e83f00-20d1-402d-9263-658dc16d3330` | `Fact Tables/Customer Anatomy` | 1 |
| Build_Gold_PartsInvoices | `0dde6998-a579-43e3-9697-ac22041e2e48` | `Fact Tables/Customer Anatomy` | 2 |
| Build_Gold_ServiceInvoices | `d3b06ee6-15b4-4541-8f7c-ca63e232f9c7` | `Fact Tables/Customer Anatomy` | 2 |
| Build_Gold_ServiceDetail | `cff5ba34-c6bb-497c-a817-5793d6763855` | `Fact Tables/Customer Anatomy` | 2 |
| Build_Gold_CustomerPerformance | `3ee492c2-bc45-40ab-bafe-5059f7727c4d` | `Fact Tables/Customer Anatomy` | 3 |

*Shared Gold dims* (registered, Presentation workspace):

| Notebook | ID |
|---|---|
| Build_Gold_CustomerList | `6cbd37e5-0c13-4a78-a2b0-13ee4692ae87` |
| Build_Gold_Parts | `ce5345f4-b25d-4478-beaa-2c4aa576849f` |
| Build_Gold_DateTable | `47923626-8236-4d9b-aae8-08386fda863b` |
| Build_Gold_BranchLocation | `6b7e48fd-75f5-4e73-80d8-5002f959fcf9` |

*Silver notebooks* (Staging workspace):

| Notebook | ID |
|---|---|
| Build_Silver_Invoice | `40f2a98e-89f0-4c35-8df0-888f28f691d7` |
| Build_Silver_InTrans | `8bfdff09-5033-4c06-b9ad-1dfae9659c85` |
| Build_Silver_WkOthSub | `1de7a0c6-f05e-4cd7-b7cd-6b76e719637d` |
| Build_Silver_WkRoFile | `af3d4019-6d41-4629-8c38-376e40d422e3` |
| Build_Silver_WkInvReg | `a6bb29c0-4d7a-4a89-8cab-c67c66935773` |
| Build_Silver_VhStock | `1edc53bf-f224-4713-b8d3-16c0efe502e9` |
| Build_Silver_ArMasterCustomer | `3c26044a-6ff7-4924-a77d-c09b38f6f095` |
| Build_Silver_ArMaster | `2fcbaabe-de21-4f37-afe1-b5f7fece3460` |
| Build_Silver_Contact | `469473fb-0a99-4475-a39f-6abcdb030506` |
| Build_Silver_PartInformation | `daa8e4e4-0f31-43bd-b588-d06b1419ef83` |
| Build_Silver_BranchName | `2c3405dd-b1c7-419e-9a60-17050370620e` |

**Standard notebook edit ("hygiene"), applied to every Gold notebook in Tasks 4–7:**

*(H1)* Directly after the notebook's first `from pyspark.sql import functions as F` line, insert a blank line followed by:
```python
spark.conf.set("spark.sql.session.timeZone", "UTC")
```

*(H2)* Replace the notebook's write statement `<VAR>.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/<TABLE>")` with the version below. The `<VAR> = <VAR>.select(...)` trim line is included **only** for the 7 facts, using the KEEP list given in that task:
```python
<VAR> = <VAR>.select(<KEEP LIST>)
<VAR>.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/<TABLE>")
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/<TABLE>` RETAIN 0 HOURS")
```
Leave the existing "Gold build complete" print after the VACUUM lines as it is.

**Registration entry format.** Insert with the Edit tool after the current last entry of `deploy/dp_backend_scope.json`'s `notebooks` array: add a comma after that entry's closing `}`, then the new entry. **Never rewrite the file with `json.dump`.** Validate with `python -c "import json; json.load(open('deploy/dp_backend_scope.json', encoding='utf-8'))"`.
```json
    {"name": "<NOTEBOOK>", "tier": "gold", "cadence": "daily", "wave": <N>,
     "notebookId": "<ID>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/<FOLDER>/<NOTEBOOK>.Notebook"}
```

**Decisions already made (don't revisit):**
1. Keep the Service_Detail one-row-per-job fix.
2. Include 2022.
3. The lookup uses production's 2022+ invoice window.
4. Trim the facts.
5. Keep the correct majority branch for the 4 Tornillo/Dell City customers production mislabels.

**Unchanged by design:**
- The CustomerVehicleFlag Stock/Unknown logic.
- The InvoiceNumber + Branch join fix.
- EngagedAcres stays sourced from the CSV in Files.

---

### Task 1: Promote reusable helpers into `tools/dp-migration`

**Files:**
- Create: `data-projects/tools/dp-migration/git_status.py`, `refresh_model.py` and `dax_query.py`
- Modify: `data-projects/tools/dp-migration/README.md`

These started as throwaway scripts during Inspections, and the scratchpad has already been wiped once. They belong in the repo.

- [ ] **Step 1: Write `git_status.py`**

```python
"""Fabric Git status for one or more Git-connected workspaces.

Usage: python git_status.py [workspaceId ...]   (default: both DP Dev workspaces + RP - Dev)
Prints head/remote and every pending change (workspace side, remote side, conflict).
"""
import json
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
DEFAULT = {
    "73fd5443-240e-410a-990a-98827f32c087": "DP - Presentation - Dev",
    "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201": "DP - Staging - Dev",
    "e888a4dc-a02d-4fd4-839d-5daa5763ab44": "RP - Dev",
}


def api(path):
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    start = out.find("{")
    if start < 0:
        sys.exit(f"No JSON from fab api {path}:\n{out[-500:]}")
    return json.loads(out[start:])


targets = {w: w for w in sys.argv[1:]} or DEFAULT
for ws, label in targets.items():
    r = api(f"workspaces/{ws}/git/status")
    s = r.get("text", {})
    changes = s.get("changes", [])
    print(f"=== {label}: head={str(s.get('workspaceHead'))[:8]} remote={str(s.get('remoteCommitHash'))[:8]} changes={len(changes)}")
    for c in sorted(changes, key=lambda c: c.get("itemMetadata", {}).get("displayName") or ""):
        m = c.get("itemMetadata", {})
        print(f"  {m.get('displayName', '?'):50s} {m.get('itemType', ''):16s} ws={c.get('workspaceChange')} "
              f"remote={c.get('remoteChange')} conflict={c.get('conflictType')}")
```

- [ ] **Step 2: Write `refresh_model.py`**

```python
"""Trigger a Power BI semantic model refresh (service) and wait for the result.

Usage: python refresh_model.py <workspaceId> <datasetId> [timeoutSeconds]
Exit 0 only on Completed. A 'DMTS_MonikerWithUnboundDataSources' failure means the
model's data-source credentials must be set in the service (Brian's action).
"""
import json
import os
import subprocess
import sys
import tempfile
import time

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"


def pbi(path, method=None, body=None):
    cmd = ["fab", "api", "-A", "powerbi", path] + (["-X", method] if method else [])
    tmp = None
    if body is not None:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(body, tmp)
        tmp.close()
        cmd += ["-i", tmp.name]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    if tmp:
        os.unlink(tmp.name)
    start = out.find("{")
    return json.loads(out[start:]) if start >= 0 else {"raw": out[-600:]}


ws, ds = sys.argv[1], sys.argv[2]
timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 1800
r = pbi(f"groups/{ws}/datasets/{ds}/refreshes", "post", {"notifyOption": "NoNotification"})
print("submit:", r.get("status_code"))
if r.get("status_code") not in (200, 202):
    print(json.dumps(r, indent=1)[:1500])
    sys.exit(1)
start = time.time()
while time.time() - start < timeout:
    time.sleep(20)
    hist = pbi(f"groups/{ws}/datasets/{ds}/refreshes?$top=1").get("text", {}).get("value", [])
    if hist:
        st = hist[0].get("status")
        print(f"  {int(time.time() - start)}s: {st}")
        if st in ("Completed", "Failed", "Disabled", "Cancelled"):
            keys = ("status", "startTime", "endTime", "refreshType", "serviceExceptionJson")
            print(json.dumps({k: hist[0].get(k) for k in keys}, indent=1))
            sys.exit(0 if st == "Completed" else 1)
print("TIMEOUT")
sys.exit(2)
```

- [ ] **Step 3: Write `dax_query.py`**

```python
"""Run a DAX query against a published semantic model (Power BI executeQueries).

Usage: python dax_query.py <workspaceId> <datasetId> <file.dax>
Prints the result rows as JSON.
"""
import json
import os
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
ws, ds, dax_file = sys.argv[1], sys.argv[2], sys.argv[3]
body = {"queries": [{"query": open(dax_file, encoding="utf-8").read()}], "serializerSettings": {"includeNulls": True}}
tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
json.dump(body, tmp)
tmp.close()
out = subprocess.run(["fab", "api", "-A", "powerbi", f"groups/{ws}/datasets/{ds}/executeQueries", "-X", "post", "-i", tmp.name],
                     capture_output=True, text=True, encoding="utf-8").stdout
os.unlink(tmp.name)
r = json.loads(out[out.find("{"):])
if r.get("status_code") != 200:
    print(json.dumps(r, indent=1)[:2000])
    sys.exit(1)
for t in r["text"]["results"][0]["tables"]:
    print(json.dumps(t["rows"], indent=1))
```

- [ ] **Step 4: Update the README**

Add these lines to `README.md`'s tool list:
```markdown
- `git_status.py [wsId ...]`: Fabric Git status (defaults: DP Presentation/Staging Dev + RP - Dev).
- `refresh_model.py <wsId> <datasetId>`: service refresh of a semantic model; exit 0 only on Completed.
- `dax_query.py <wsId> <datasetId> <file.dax>`: run a DAX query against a published model.
- `customer_anatomy_parity.py`: Customer Anatomy DP-vs-production parity (Customer Anatomy plan, Task 8).
- `edit_customer_anatomy_tmdl.py`: Customer Anatomy repoint/trim script (Customer Anatomy plan, Task 9).
```

- [ ] **Step 5: Smoke-test (read-only) and commit**

Run `python tools/dp-migration/git_status.py`. Expected:
- Presentation lists only the 3 `Utilities_*` notebooks.
- Staging and RP - Dev show 0 changes.

Don't run `refresh_model.py` or `dax_query.py` yet; `py_compile` them instead.
```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add tools/dp-migration/git_status.py tools/dp-migration/refresh_model.py tools/dp-migration/dax_query.py tools/dp-migration/README.md
git commit -m "Add git_status, refresh_model, dax_query helpers to tools/dp-migration

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 2: Refresh inputs (manual; schedules are paused)

**Files:** none. This task only runs items.

- [ ] **Step 1: Run the Silver notebooks one at a time** (Staging workspace `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`). Stop on the first failure and report it.

In this order: Invoice, InTrans, WkOthSub, WkRoFile, WkInvReg, VhStock, ArMasterCustomer, ArMaster, Contact, PartInformation, BranchName.
```bash
T="/c/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration"
for id in 40f2a98e-89f0-4c35-8df0-888f28f691d7 8bfdff09-5033-4c06-b9ad-1dfae9659c85 1de7a0c6-f05e-4cd7-b7cd-6b76e719637d \
          af3d4019-6d41-4629-8c38-376e40d422e3 a6bb29c0-4d7a-4a89-8cab-c67c66935773 1edc53bf-f224-4713-b8d3-16c0efe502e9 \
          3c26044a-6ff7-4924-a77d-c09b38f6f095 2fcbaabe-de21-4f37-afe1-b5f7fece3460 469473fb-0a99-4475-a39f-6abcdb030506 \
          daa8e4e4-0f31-43bd-b588-d06b1419ef83 2c3405dd-b1c7-419e-9a60-17050370620e; do
  python "$T/run_item.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 "$id" RunNotebook || { echo "FAILED: $id"; break; }
done
```
(If the loop is hook-blocked, put it in a scratchpad `.sh` file unchanged.)

- [ ] **Step 2: Run the 4 shared dims** (Presentation workspace), one at a time: CustomerList, Parts, DateTable, BranchLocation.
```bash
for id in 6cbd37e5-0c13-4a78-a2b0-13ee4692ae87 ce5345f4-b25d-4478-beaa-2c4aa576849f 47923626-8236-4d9b-aae8-08386fda863b 6b7e48fd-75f5-4e73-80d8-5002f959fcf9; do
  python "$T/run_item.py" 73fd5443-240e-410a-990a-98827f32c087 "$id" RunNotebook || { echo "FAILED: $id"; break; }
done
```

- [ ] **Step 3: Check freshness (DuckDB)**

```python
import duckdb
con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
S = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/"
for t, col in [("Silver_Invoice", "InvoiceDate"), ("Silver_InTrans", "TransDatetime"), ("Silver_WkOthSub", "ModifiedDate"),
               ("Silver_WkRoFile", "CreatedOn"), ("Silver_WkInvReg", None), ("Silver_VhStock", None)]:
    agg = f", MAX({col})" if col else ""
    print(t, con.sql(f"SELECT COUNT(*){agg} FROM delta_scan('{S}{t}')").fetchone())
```
Expected: every MAX date falls within the last 1–2 days. `Silver_Invoice` in particular was at 09-04 before this refresh.

---

### Task 3: Unique-customer lookup: 2022+ window and deterministic tie-break (wave 1)

**Files:**
- Modify: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_UniqueCustomersInvoiceLookup.Notebook/notebook-content.py`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

This was simulated on 2026-09-25: it reproduces production's **542 customers exactly**, with **exactly 4** group differences. Those 4 are the approved true-majority corrections: 10762 → Tornillo, 1136 → Dell City, 2550 → Tornillo, 70794 → Tornillo.

- [ ] **Step 1: Header note.** After the line `# the first match in that combine order, matching production's own` and the line that follows it (`# Table.Distinct behavior on the combined table).`), insert:
```python
#
# 2026-09-25 (Customer Anatomy migration, Brian's decisions 3 and 5):
# - Invoice patterns only consider InvoiceDate >= 2022-01-01, matching
#   production's raw Invoice window (DP's Silver_Invoice goes back to 1998;
#   unwindowed it flagged 176 extra customers). The InTrans branch-majority
#   count uses TransDatetime >= 2018-01-01, production's InTrans_Incremental range.
# - A customer matching several order-number patterns gets the highest-
#   priority group (same order as the CASE below: Manuel/MR Tractor, Jim
#   Justice, David Arizmendi, Danny G, Oscar) - deterministic, and matches
#   production (e.g. 4 and 25227 -> Manuel/MR Tractor).
# - Tornillo/Dell City keeps the TRUE majority branch. Production mislabels
#   4 customers (10762, 1136, 2550, 70794) because its Table.Sort +
#   Table.Distinct without Table.Buffer doesn't keep the sorted first row.
#   Correction kept per Brian - production bug fixed.
```

- [ ] **Step 2: Imports, window and reads.** Replace:
```python
from pyspark.sql import functions as F

invoice = spark.read.table("Silver_Invoice")
ar_customer = spark.read.table("Silver_ArMasterCustomer")
intrans = spark.read.table("Silver_InTrans")
```
with:
```python
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark.conf.set("spark.sql.session.timeZone", "UTC")

INVOICE_START = "2022-01-01"   # production's raw Invoice window (decision 3)
INTRANS_START = "2018-01-01"   # production's InTrans_Incremental range

invoice = spark.read.table("Silver_Invoice").filter(F.col("InvoiceDate") >= F.to_timestamp(F.lit(INVOICE_START)))
ar_customer = spark.read.table("Silver_ArMasterCustomer")
intrans = spark.read.table("Silver_InTrans").filter(F.col("TransDatetime") >= F.to_timestamp(F.lit(INTRANS_START)))
```

- [ ] **Step 3: Deterministic invoice tie-break.** Replace:
```python
invoice_customers = (
    invoice_grouped
    .select("CustomerNumber", "UniqueCustomerGroup")
    .dropDuplicates(["CustomerNumber"])
)
```
with:
```python
GROUP_PRIORITY = {"Manuel/MR Tractor": 1, "Jim Justice": 2, "David Arizmendi": 3, "Danny G": 4, "Oscar": 5}
priority_map = F.create_map(*[F.lit(x) for kv in GROUP_PRIORITY.items() for x in kv])
pattern_window = Window.partitionBy("CustomerNumber").orderBy(F.col("_GroupPriority").asc())
invoice_customers = (
    invoice_grouped
    .select("CustomerNumber", "UniqueCustomerGroup")
    .distinct()
    .withColumn("_GroupPriority", priority_map[F.col("UniqueCustomerGroup")])
    .withColumn("_pattern_rank", F.row_number().over(pattern_window))
    .filter(F.col("_pattern_rank") == 1)
    .select("CustomerNumber", "UniqueCustomerGroup")
)
```

- [ ] **Step 4: Tidy up.**
  - Delete the now-duplicate later line `from pyspark.sql.window import Window` (in the TradeType cell).
  - Change the print `(expect ~513 per production's own documentation)` to `(expect 542 - production parity 2026-09-25)`.
  - Apply **hygiene H2** to the write (no trim; `<VAR>` = `lookup_unique_customers_invoice`, `<TABLE>` = `lookup_UniqueCustomers_Invoice`).
  - The UTC pin (H1) is already included in Step 2.

- [ ] **Step 5: Register (wave 1, folder `Dimensions`)**, using the entry format with name `Build_Gold_UniqueCustomersInvoiceLookup` and ID `2548aec8-3aaa-4b62-8570-56f39fae50b5`.

- [ ] **Step 6: Commit, push, sync, run**
```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_UniqueCustomersInvoiceLookup.Notebook/notebook-content.py" deploy/dp_backend_scope.json
git commit -m "UniqueCustomersInvoiceLookup: production 2022+ window, deterministic pattern tie-break, UTC, VACUUM; register wave 1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
T="/c/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration"
python "$T/wait_ci.py" && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087 && \
python "$T/run_item.py" 73fd5443-240e-410a-990a-98827f32c087 2548aec8-3aaa-4b62-8570-56f39fae50b5 RunNotebook
```

- [ ] **Step 7: Verify against production (a gate)**
```python
import duckdb
con = duckdb.connect()
con.sql("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
DP = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/lookup_UniqueCustomers_Invoice"
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/lookup_UniqueCustomers_Invoice"
con.sql(f"CREATE TABLE d AS SELECT CAST(CustomerNumber AS VARCHAR) c, UniqueCustomerGroup g FROM delta_scan('{DP}')")
con.sql(f"CREATE TABLE p AS SELECT CAST(CustomerNumber AS VARCHAR) c, UniqueCustomerGroup g FROM delta_scan('{LH}')")
print("dp rows", con.sql("SELECT COUNT(*) FROM d").fetchone(), "prod rows", con.sql("SELECT COUNT(*) FROM p").fetchone())
print("dp_only", con.sql("SELECT * FROM d WHERE c NOT IN (SELECT c FROM p)").fetchall())
print("prod_only", con.sql("SELECT * FROM p WHERE c NOT IN (SELECT c FROM d)").fetchall())
print("group diffs", con.sql("SELECT c, d.g, p.g FROM d JOIN p USING (c) WHERE d.g <> p.g ORDER BY c").fetchall())
```
**Expected, exactly:**
- Both sides have 542 rows.
- `dp_only` and `prod_only` are both empty.
- `group diffs` equals `[('10762','Tornillo','Dell City'), ('1136','Dell City','Tornillo'), ('2550','Tornillo','Dell City'), ('70794','Tornillo','Dell City')]`.

**Any other result is a stop:** report it and don't adjust the code to force a match. (Production's lookup refreshes daily. If a brand-new customer appears on both sides, that's fine; report it.)

---

### Task 4: CustomerLookup and EngagedAcres: hygiene plus registration (wave 1)

**Files:**
- Modify: `.../Fact Tables/Customer Anatomy/Build_Gold_CustomerLookup.Notebook/notebook-content.py`
- Modify: `.../Fact Tables/Customer Anatomy/Build_Gold_EngagedAcres.Notebook/notebook-content.py`
- Modify: `deploy/dp_backend_scope.json`

- [ ] **Step 1: Apply hygiene H1 and H2 (no trim)** to both notebooks:
  - CustomerLookup: `<VAR>` = `customer_lookup`, `<TABLE>` = `CustomerLookup`.
  - EngagedAcres: `<VAR>` = `dim_engaged_acres`, `<TABLE>` = `dim_EngagedAcres`.
- [ ] **Step 2: Register both (wave 1, folder `Fact Tables/Customer Anatomy`)** with IDs `056084ba-ec30-4c37-acd1-eb51da6cc566` and `86b9f279-305b-4ab3-9a93-fcd76480dfd5`.
- [ ] **Step 3: Commit (the 2 notebook files and the config), push, `wait_ci`, `git_sync`, then run CustomerLookup and then EngagedAcres** with `run_item.py`. Commit message: `CustomerLookup, EngagedAcres: UTC, VACUUM; register wave 1`. Expected: both show `Completed`.

---

### Task 5: Wave 1 facts: EquipmentSales, PartsDetail, ServicePartsDetail

**Files:** the three notebooks in `Fact Tables/Customer Anatomy/`, plus `deploy/dp_backend_scope.json`.

- [ ] **Step 1: Apply H1 and H2 with these KEEP lists:**

EquipmentSales (`<VAR>` = `fact_equipment_sales`, `<TABLE>` = `Fact_Equipment_Sales`):
```python
fact_equipment_sales = fact_equipment_sales.select(
    "StockNumber", "CustomerKey", "SaleDateKey", "Territory", "SaleDate", "Year",
    "SalesValue", "TotalBaseCost", "TotalTradeAllowance", "SaleYear", "SaleMonth",
)
```
PartsDetail (`fact_parts_detail`, `Fact_Parts_Detail`):
```python
fact_parts_detail = fact_parts_detail.select(
    "CustomerKey", "TransDateKey", "TransDatetime", "Branch", "Franchise", "PartNumber", "Description",
    "Qty", "SaleValue", "CostValue", "LineMargin", "IsSundryPart", "InvoiceNumber",
)
```
ServicePartsDetail (`fact_service_parts_details`, `Fact_Service_Parts_Details`):
```python
fact_service_parts_details = fact_service_parts_details.select(
    "BranchCode", "InvoiceNumber", "PartNumber", "Description", "Franchise", "Quantity", "SaleValue",
)
```
- [ ] **Step 2: Register all three (wave 1, folder `Fact Tables/Customer Anatomy`)** with IDs `27755fb8-dc0a-41e3-8b07-bde87829a33f`, `4f00f98f-2016-4293-9cd4-8e6b3d50a06b` and `26e83f00-20d1-402d-9263-658dc16d3330`.
- [ ] **Step 3: Commit, push, `wait_ci`, `git_sync`, and run all three one at a time.** Commit message: `Customer Anatomy wave 1 facts: trim, UTC, VACUUM; register`.
- [ ] **Step 4: DuckDB `DESCRIBE` each table.** The column sets must equal the KEEP lists exactly: 11, 13 and 7 columns.

---

### Task 6: Wave 2 facts: PartsInvoices, ServiceInvoices, ServiceDetail

**Files:** the three notebooks, plus `deploy/dp_backend_scope.json`.

- [ ] **Step 1: Apply H1 and H2 with these KEEP lists:**

PartsInvoices (`fact_parts_invoices`, `Fact_Parts_Invoices`):
```python
fact_parts_invoices = fact_parts_invoices.select(
    "InvoiceNumber", "CustomerKey", "InvoiceDateKey", "Territory", "InvoiceDate", "Branch",
    "PartsCostValue", "PartsSaleValue", "PartsMargin", "InvoiceYear", "InvoiceMonth",
)
```
ServiceInvoices (`fact_service_invoices`, `Fact_Service_Invoices`):
```python
fact_service_invoices = fact_service_invoices.select(
    "InvoiceNumber", "CustomerKey", "InvoiceDateKey", "Territory", "InvoiceDate", "Branch",
    "LabourCostValue", "LabourSaleValue", "LabourMargin", "PartsCostValue", "PartsSaleValue",
    "TotalNetSales", "TotalCost", "TotalMargin", "InvoiceYear", "InvoiceMonth",
)
```
ServiceDetail (`fact_service_detail`, `Fact_Service_Detail`):
```python
fact_service_detail = fact_service_detail.select(
    "CustomerKey", "InvoiceDateKey", "InvoiceDate", "Branch", "JobCode", "JobType", "WorkCategory",
    "IsFieldRepair", "ActLabor", "InvLabor", "LaborMargin", "ActParts", "InvParts", "PartsMargin",
    "TotalInvoiced", "TotalJobMargin", "InvoiceNumber", "IsWarrantyJob",
)
```
- [ ] **Step 2: ServiceDetail's verification cell uses the dropped `DetailSource`.**

First, directly after `print(f"Fact_Service_Detail rows: {fact_count:,}")`, insert:
```python
print("DetailSource breakdown (before trim; expect both 'Job Detail' and 'WO Summary'):")
fact_service_detail.groupBy("DetailSource").count().show(truncate=False)
```
Then delete this block from the verification cell:
```python
source_breakdown = spark.sql("""
    SELECT DetailSource, COUNT(*) AS n FROM delta.`Tables/Fact_Service_Detail` GROUP BY DetailSource
""").toPandas()
print("\nDetailSource breakdown (expect both 'Job Detail' and 'WO Summary'):")
print(source_breakdown.to_string())
```
- [ ] **Step 3: Register all three (wave 2)** with IDs `0dde6998-a579-43e3-9697-ac22041e2e48`, `d3b06ee6-15b4-4541-8f7c-ca63e232f9c7` and `cff5ba34-c6bb-497c-a817-5793d6763855`.
- [ ] **Step 4: Commit, push, `wait_ci`, `git_sync`, and run the three one at a time** (PartsInvoices, ServiceInvoices, ServiceDetail). Commit message: `Customer Anatomy wave 2 facts: trim, UTC, VACUUM; register`.
- [ ] **Step 5: `DESCRIBE` each table** to confirm 11, 16 and 18 columns, exactly the KEEP lists.

---

### Task 7: Wave 3: CustomerPerformance

**Files:** `.../Build_Gold_CustomerPerformance.Notebook/notebook-content.py`, `deploy/dp_backend_scope.json`

- [ ] **Step 1: Apply H1 and H2** (`fact_customer_performance`, `Fact_CustomerPerformance`) with this KEEP list:
```python
fact_customer_performance = fact_customer_performance.select(
    "CustomerKey", "PeriodDateKey", "Territory",
    "PartsSales", "PartsCost", "PartsMargin", "ServiceSales", "ServiceCost", "ServiceMargin",
    "EquipmentSales", "EquipmentCost", "EquipmentMargin",
    "TotalSales", "TotalCost", "TotalMargin", "TotalTransactionCount",
)
```
- [ ] **Step 2: Register (wave 3)** with ID `3ee492c2-bc45-40ab-bafe-5059f7727c4d`.
- [ ] **Step 3: Commit, push, `wait_ci`, `git_sync`, run, refresh the SQL endpoint metadata, and check folders.**
```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
python "$T/folder_check.py"
python "$T/git_status.py"
```
Expected:
- `0 mismatch(es) across 53 registered notebooks`.
- Git status: Presentation shows only the 3 `Utilities_*` notebooks, and nothing else is pending.
- `DESCRIBE Fact_CustomerPerformance` gives exactly 16 columns.

---

### Task 8: Parity against production (stop gate)

**Files:** Create `data-projects/tools/dp-migration/customer_anatomy_parity.py`

- [ ] **Step 1: Write the script**

```python
"""Customer Anatomy parity: DP_Presentation vs production LH_Master_Data, complete months only.

Expected differences (spec, decisions 1/2/5):
  Service_Detail: prod ~2x DP for 2023+ (prod doubling bug); DP adds 2022
  Equipment_Sales: DP adds 2022; 2023+ identical
  CustomerPerformance: 2022 gains equipment; service follows Service_Invoices
  Service_Invoices: small diffs from the reused-InvoiceNumber fix (key-level list printed)
  Parts_Detail: DP higher in Aug 2026 (prod InTrans gap); older small diffs listed key-level
  lookup: identical except the 4 approved Tornillo/Dell City corrections
"""
import sys
from datetime import date, timedelta

import duckdb

sys.stdout.reconfigure(encoding="utf-8")
con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
DP = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/"
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/"
LAST = date.today().replace(day=1) - timedelta(days=1)
print(f"Complete months through {LAST}\n")


def show(title, sql, limit=80):
    cur = con.sql(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    print(f"=== {title} ({len(rows)} rows)\n  " + " | ".join(cols))
    for r in rows[:limit]:
        print("  " + " | ".join("" if v is None else str(v) for v in r))
    if len(rows) > limit:
        print(f"  ... {len(rows) - limit} more")
    print()


def monthly(table, date_expr, measures):
    agg = ", ".join(f"ROUND(SUM(CAST({m} AS DOUBLE)), 2) AS {m}" for m in measures)
    for tag, base in (("dp", DP), ("prod", LH)):
        con.sql(f"""CREATE OR REPLACE TABLE {table}_{tag} AS
            SELECT strftime({date_expr}, '%Y-%m') AS ym, COUNT(*) AS n, {agg}
            FROM delta_scan('{base}{table}') WHERE {date_expr} <= DATE '{LAST}' GROUP BY 1""")
    diffs = ", ".join(f"ROUND(COALESCE(d.{m},0) - COALESCE(p.{m},0), 2) AS d_{m}" for m in measures)
    show(f"{table} by month (dp - prod)", f"""
        SELECT COALESCE(d.ym, p.ym) AS ym, d.n AS dp_n, p.n AS prod_n, {diffs}
        FROM {table}_dp d FULL OUTER JOIN {table}_prod p ON d.ym = p.ym ORDER BY 1""", limit=200)


monthly("Fact_CustomerPerformance", "make_date(CAST(PeriodDateKey/10000 AS INT), CAST(PeriodDateKey/100 % 100 AS INT), 1)",
        ["PartsSales", "ServiceSales", "EquipmentSales", "TotalSales"])
monthly("Fact_Parts_Invoices", "CAST(InvoiceDate AS DATE)", ["PartsSaleValue", "PartsCostValue"])
monthly("Fact_Service_Invoices", "CAST(InvoiceDate AS DATE)", ["LabourSaleValue", "PartsSaleValue", "TotalNetSales"])
monthly("Fact_Equipment_Sales", "CAST(SaleDate AS DATE)", ["SalesValue", "TotalBaseCost"])
monthly("Fact_Parts_Detail", "CAST(TransDatetime AS DATE)", ["SaleValue", "CostValue"])
monthly("Fact_Service_Detail", "CAST(InvoiceDate AS DATE)", ["InvLabor", "InvParts", "TotalInvoiced"])
# Fact_Service_Parts_Details has no date column - compare totals (both sides are full snapshots).
show("Fact_Service_Parts_Details totals", f"""
    SELECT 'dp' side, COUNT(*), ROUND(SUM(CAST(SaleValue AS DOUBLE)),2), ROUND(SUM(CAST(Quantity AS DOUBLE)),2) FROM delta_scan('{DP}Fact_Service_Parts_Details')
    UNION ALL SELECT 'prod', COUNT(*), ROUND(SUM(CAST(SaleValue AS DOUBLE)),2), ROUND(SUM(CAST(Quantity AS DOUBLE)),2) FROM delta_scan('{LH}Fact_Service_Parts_Details')""")

show("Service_Detail 2023+: prod rows / DP rows per year (expect ~2.0)", f"""
    SELECT YEAR(CAST(d.InvoiceDate AS DATE)) y, COUNT(*) dp_rows,
           (SELECT COUNT(*) FROM delta_scan('{LH}Fact_Service_Detail') p WHERE YEAR(CAST(p.InvoiceDate AS DATE)) = YEAR(CAST(d.InvoiceDate AS DATE))) prod_rows
    FROM delta_scan('{DP}Fact_Service_Detail') d WHERE CAST(d.InvoiceDate AS DATE) <= DATE '{LAST}' GROUP BY 1 ORDER BY 1""")

show("Service_Invoices keys only on one side (complete months)", f"""
    WITH d AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, strftime(CAST(InvoiceDate AS DATE),'%Y-%m') ym, ROUND(CAST(TotalNetSales AS DOUBLE),2) v
               FROM delta_scan('{DP}Fact_Service_Invoices') WHERE CAST(InvoiceDate AS DATE) <= DATE '{LAST}'),
         p AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, strftime(CAST(InvoiceDate AS DATE),'%Y-%m') ym, ROUND(CAST(TotalNetSales AS DOUBLE),2) v
               FROM delta_scan('{LH}Fact_Service_Invoices') WHERE CAST(InvoiceDate AS DATE) <= DATE '{LAST}')
    SELECT 'dp_only' side, * FROM (SELECT * FROM d EXCEPT ALL SELECT * FROM p)
    UNION ALL SELECT 'prod_only', * FROM (SELECT * FROM p EXCEPT ALL SELECT * FROM d) ORDER BY ym, inv""", limit=60)

show("Parts_Detail line-level differences by year (complete months)", f"""
    WITH d AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, PartNumber pn, CAST(TransDatetime AS DATE) dt, ROUND(CAST(SaleValue AS DOUBLE),2) v
               FROM delta_scan('{DP}Fact_Parts_Detail') WHERE CAST(TransDatetime AS DATE) <= DATE '{LAST}'),
         p AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, PartNumber pn, CAST(TransDatetime AS DATE) dt, ROUND(CAST(SaleValue AS DOUBLE),2) v
               FROM delta_scan('{LH}Fact_Parts_Detail') WHERE CAST(TransDatetime AS DATE) <= DATE '{LAST}')
    SELECT side, YEAR(dt) y, COUNT(*) n, ROUND(SUM(v),2) sale FROM (
        SELECT 'dp_only' side, * FROM (SELECT * FROM d EXCEPT ALL SELECT * FROM p)
        UNION ALL SELECT 'prod_only', * FROM (SELECT * FROM p EXCEPT ALL SELECT * FROM d)) GROUP BY 1,2 ORDER BY 1,2""")

show("lookup_UniqueCustomers_Invoice differences", f"""
    WITH d AS (SELECT CAST(CustomerNumber AS VARCHAR) c, UniqueCustomerGroup g FROM delta_scan('{DP}lookup_UniqueCustomers_Invoice')),
         p AS (SELECT CAST(CustomerNumber AS VARCHAR) c, UniqueCustomerGroup g FROM delta_scan('{LH}lookup_UniqueCustomers_Invoice'))
    SELECT COALESCE(d.c, p.c) c, d.g dp, p.g prod FROM d FULL OUTER JOIN p ON d.c = p.c
    WHERE d.c IS NULL OR p.c IS NULL OR d.g <> p.g ORDER BY 1""")

for t in ("dim_CustomerList", "dim_EngagedAcres", "dim_BranchLocation", "dim_DateTable", "dim_Parts"):
    show(f"{t} row counts", f"SELECT 'dp', COUNT(*) FROM delta_scan('{DP}{t}') UNION ALL SELECT 'prod', COUNT(*) FROM delta_scan('{LH}{t}')")
```

- [ ] **Step 2: Run it**, saving the output to the scratchpad, and read the whole output. If a query errors, make only the smallest fix that keeps the same measurement (for example a CAST), and report it. `Fact_Service_Parts_Details` has no date column, so it's compared as whole-table totals, and differences there include the 11-day staleness.

- [ ] **Step 3: Classify every difference against the spec's expected table.**
  - Anything outside that table needs a key-level explanation. Pull example keys and trace them to Silver or production, as was done for Inspections.
  - The small Parts_Detail differences for 2022–2025 **must** be explained, not assumed. For example: production InTrans duplicates that Silver's MERGE dedup removed, or lines in production only.

- [ ] **Step 4: Stop gate (controller).** Commit the script (`git add tools/dp-migration/customer_anatomy_parity.py`), then present the results to Brian with every difference classified. **Anything unexplained is a stop.** Continue only after Brian accepts.

---

### Task 9: Create the `.pbip` and edit the report TMDL (Desktop must be closed)

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Customer Anatomy.pbip`
- Modify: the 13 table TMDLs under `workspaces/RP - Dev/Customer Anatomy.SemanticModel/definition/tables/`
- Create: `data-projects/tools/dp-migration/edit_customer_anatomy_tmdl.py`

- [ ] **Step 1: Controller asks Brian:** "Is Customer Anatomy closed in Power BI Desktop?" Wait for confirmation.

- [ ] **Step 2: `.pbip`**, the same JSON as Inspections, with `"path": "Customer Anatomy.Report"`:
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Customer Anatomy.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [ ] **Step 3: Write the edit script**

```python
"""Repoint Customer Anatomy to DP_Presentation and trim unused columns. Run only with Desktop CLOSED."""
import re
import sys
from pathlib import Path

SM = Path(r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Customer Anatomy.SemanticModel/definition")
OLD_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")'
NEW_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")'

KEEP = {
    "Fact_CustomerPerformance": ["CustomerKey", "TotalSales", "PartsSales", "TotalCost", "PeriodDateKey", "PartsCost", "PartsMargin",
                                 "ServiceSales", "ServiceCost", "ServiceMargin", "EquipmentSales", "EquipmentCost",
                                 "EquipmentMargin", "TotalMargin", "TotalTransactionCount", "Territory"],
    "Fact_Equipment_Sales": ["StockNumber", "CustomerKey", "SaleDateKey", "Territory", "SaleDate", "Year", "SalesValue",
                             "TotalBaseCost", "TotalTradeAllowance"],
    "Fact_Parts_Detail": ["CustomerKey", "TransDateKey", "TransDatetime", "Branch", "Franchise", "PartNumber", "Description",
                          "Qty", "SaleValue", "CostValue", "LineMargin", "IsSundryPart", "InvoiceNumber"],
    "Fact_Parts_Invoices": ["InvoiceNumber", "CustomerKey", "InvoiceDateKey", "Territory", "InvoiceDate", "Branch",
                            "PartsCostValue", "PartsSaleValue", "PartsMargin"],
    "Fact_Service_Detail": ["CustomerKey", "InvoiceDateKey", "InvoiceDate", "Branch", "JobCode", "JobType", "WorkCategory",
                            "IsFieldRepair", "ActLabor", "InvLabor", "LaborMargin", "ActParts", "InvParts", "PartsMargin",
                            "TotalInvoiced", "TotalJobMargin", "InvoiceNumber", "IsWarrantyJob"],
    "Fact_Service_Invoices": ["InvoiceNumber", "CustomerKey", "InvoiceDateKey", "Territory", "InvoiceDate", "Branch",
                              "LabourCostValue", "LabourSaleValue", "LabourMargin", "PartsCostValue", "PartsSaleValue",
                              "TotalNetSales", "TotalCost", "TotalMargin"],
    "Fact_Service_Parts_Details": ["BranchCode", "InvoiceNumber", "PartNumber", "Description", "Franchise", "Quantity", "SaleValue"],
    "dim_BranchLocation": ["Branch", "BranchID", "LocationID"],
    "dim_CustomerList": ["CustomerKey", "AccountNumber", "CustomerNumber", "DisplayName", "CompanyName", "TradeType",
                         "AccountStatus", "Territory", "CreditLimit", "AccountBalance", "CreditTerm", "City", "State",
                         "PrimaryPhone", "BusinessPhone", "MobilePhone", "Aging30", "Aging60", "Aging90", "IsKeyCustomer",
                         "CreditUtilization", "FinancialRiskLevel", "HasOverdueBalance", "CustomerTier"],
    "dim_DateTable": ["DateKey", "Date", "Year", "Month", "SortableMonthYear"],
    "dim_EngagedAcres": ["CustomerNumber", "EngagementLevel", "EstimatedAcres", "EngagedAcreBreadth", "EngagedAcreDepth",
                         "HighlyEngagedAcres", "PrepareAcres", "PlantAcres", "ApplyAcres", "HarvestAcres"],
    "dim_Parts": ["PartNumber", "Description", "Franchise"],
    "lookup_UniqueCustomers_Invoice": ["CustomerNumber", "UniqueCustomerGroup"],
}
EXPECTED_REMOVED = {"Fact_CustomerPerformance": 2, "Fact_Equipment_Sales": 27, "Fact_Parts_Detail": 10,
                    "Fact_Parts_Invoices": 24, "Fact_Service_Detail": 18, "Fact_Service_Invoices": 21,
                    "Fact_Service_Parts_Details": 6, "dim_BranchLocation": 13, "dim_CustomerList": 31,
                    "dim_DateTable": 62, "dim_EngagedAcres": 0, "dim_Parts": 19, "lookup_UniqueCustomers_Invoice": 0}
# Gold returns more columns than the model keeps for these, so their query selects explicitly.
SELECT_COLUMNS = {"dim_BranchLocation", "dim_CustomerList", "dim_DateTable", "dim_Parts",
                  "Fact_Parts_Invoices", "Fact_Service_Invoices", "Fact_Equipment_Sales"}

COL_RE = re.compile(r"^\tcolumn ('([^']+)'|(\S+))(\s*=.*)?$")
TOP_RE = re.compile(r"^\t[^\t]")


def rewrite_columns(lines, table):
    out, kept, removed = [], [], []
    i = 0
    while i < len(lines):
        m = COL_RE.match(lines[i])
        if not m:
            out.append(lines[i])
            i += 1
            continue
        name, is_calc = m.group(2) or m.group(3), bool(m.group(4))
        j = i + 1
        while j < len(lines) and not TOP_RE.match(lines[j]):
            j += 1
        if is_calc or name in KEEP[table]:
            out.extend(lines[i:j])
            kept.append(name)
        else:
            while out and out[-1].startswith("\t///"):
                out.pop()
            removed.append(name)
        i = j
    return out, kept, removed


def main():
    ok = True
    for table, keep in KEEP.items():
        path = SM / "tables" / f"{table}.tmdl"
        raw = path.read_bytes().decode("utf-8")
        eol = "\r\n" if "\r\n" in raw else "\n"
        text = raw.replace("\r\n", "\n")
        assert text.count(OLD_SRC) == 1, f"{table}: expected exactly 1 source string"
        text = text.replace(OLD_SRC, NEW_SRC)
        if table in SELECT_COLUMNS:
            old = (f'\t\t\t\t    dbo_{table} = Source{{[Schema="dbo",Item="{table}"]}}[Data]\n'
                   f'\t\t\t\tin\n\t\t\t\t    dbo_{table}')
            cols = ", ".join(f'"{c}"' for c in keep)
            new = (f'\t\t\t\t    dbo_{table} = Source{{[Schema="dbo",Item="{table}"]}}[Data],\n'
                   f'\t\t\t\t    #"Selected Columns" = Table.SelectColumns(dbo_{table}, {{{cols}}})\n'
                   f'\t\t\t\tin\n\t\t\t\t    #"Selected Columns"')
            assert text.count(old) == 1, f"{table}: partition tail not found exactly once"
            text = text.replace(old, new)
        lines, kept, removed = rewrite_columns(text.split("\n"), table)
        missing = [c for c in keep if c not in kept]
        print(f"{table}: removed {len(removed)} (expected {EXPECTED_REMOVED[table]}), missing keeps {missing}")
        if missing or len(removed) != EXPECTED_REMOVED[table]:
            ok = False
            print("   removed:", removed)
            continue
        path.write_bytes(eol.join(lines).encode("utf-8"))
    leftovers = [p.name for p in SM.rglob("*.tmdl") if "LH_Master_Data" in p.read_text(encoding="utf-8")]
    print("files still referencing LH_Master_Data:", leftovers)
    sys.exit(0 if ok and not leftovers else 1)


if __name__ == "__main__":
    main()
```
If the script exits 1, run `git checkout -- "workspaces/RP - Dev/Customer Anatomy.SemanticModel"`, fix the cause, and re-run. Never loosen KEEP or EXPECTED_REMOVED to force a pass; report instead.

- [ ] **Step 4: Run it.** Expected: every table matches its expected removal count, nothing is missing, 0 LH_Master_Data references, exit 0.

- [ ] **Step 5: Review.**
  - `git diff --stat` shows only the 13 table files.
  - `grep -c "DP_Presentation\|Table.SelectColumns"` across `tables/` totals **20**: 13 sources plus 7 SelectColumns.
  - No `//` lines, and no BOM (the first 3 bytes are not EF BB BF).
  - Show the new partition for dim_CustomerList and for Fact_Parts_Invoices.

- [ ] **Step 6: Controller reconfirms Desktop is closed**, then stages exactly the `.pbip` and the 13 table files, commits and pushes, and runs `wait_ci.py`. Also commit the edit script in data-projects.
  - Commit message: `Customer Anatomy: add .pbip, repoint to DP_Presentation, trim unused columns`.

---

### Task 10: Brian publishes (Brian's step; don't dispatch)

- [ ] **Step 1: Give Brian these steps:**
  1. **RP - Dev → Source control → Update all first.** Skipping this caused the Inspections conflict.
  2. `git pull` fabric-workspace-docs `dev`, then open `workspaces/RP - Dev/Customer Anatomy.pbip`.
  3. Refresh all. Check the Executive Summary, the drill-through pages and the unique-customer / engaged-acres visuals against production. **Expected differences:**
     - Service job-level measures are about half of production's (the doubling fix).
     - 2022 now includes equipment.
     - 4 customers show a different Tornillo/Dell City group.
  4. Publish to RP - Dev, replacing the existing report.
- [ ] **Step 2: Wait for Brian to confirm the publish.** Brian doesn't commit yet; Task 11 refreshes first.

---

### Task 11: Service refresh, post-publish checks and docs

**Files:** `data-projects/docs/architecture/report-migration-catalog.md`, plus memory.

- [ ] **Step 1: Refresh the model in the service.**
```bash
python "$T/refresh_model.py" e888a4dc-a02d-4fd4-839d-5daa5763ab44 2ecbf6e3-060e-440e-9131-4e8b25a4e25d
```
If it fails with `DMTS_MonikerWithUnboundDataSources`, ask Brian to set the model's DP_Presentation data-source credentials (OAuth2), then retry.

- [ ] **Step 2: DAX check** (write to a scratch `.dax` file and run `dax_query.py`):
```
EVALUATE
SUMMARIZECOLUMNS(
  dim_DateTable[Year],
  "TotalSales", SUM(Fact_CustomerPerformance[TotalSales]),
  "PartsSales", SUM(Fact_CustomerPerformance[PartsSales]),
  "ServiceSales", SUM(Fact_CustomerPerformance[ServiceSales]),
  "EquipmentSales", SUM(Fact_CustomerPerformance[EquipmentSales]),
  "ServiceDetailInvoiced", SUM(Fact_Service_Detail[TotalInvoiced]),
  "UniqueCustomers", CALCULATE(COUNTROWS(dim_CustomerList), dim_CustomerList[IsUniqueCustomer] = TRUE)
)
```
Compare the yearly totals with the DP Gold totals from Task 8. They must match; the model is a straight read. `UniqueCustomers` is dim-level and repeats across years.

- [ ] **Step 3: Brian commits.** Ask Brian to commit Customer Anatomy from RP - Dev (Source control → Changes). Then run `python "$T/git_status.py" e888a4dc-a02d-4fd4-839d-5daa5763ab44` and expect 0 changes. If there's a conflict, resolve it with PreferWorkspace plus a selective commit, as for Inspections, and **tell Brian before doing it.**

- [ ] **Step 4: Pull and check the repo.**
  - `git fetch origin && git merge --ff-only origin/dev`. If any local Desktop-saved Customer Anatomy files block the merge, ask Brian before discarding them.
  - 0 `LH_Master_Data` references in `Customer Anatomy.SemanticModel`.
  - A whole-project `git status` shows nothing unexpected outside Customer Anatomy.

- [ ] **Step 5: Docs.**
  - `report-migration-catalog.md`: mark Customer Anatomy **COMPLETE**, and update the status header to say every RP - Dev report is now on DP. Add a completion section covering the decisions, the parity summary, the production bugs fixed (the Service_Detail doubling, the 2022 equipment gap, the Tornillo/Dell City mislabels) and the pre-production validation gate.
  - Memory: mark `project_customer_anatomy_migration.md` COMPLETE, and update the catalog memory and `MEMORY.md`.
  - Commit and push data-projects.
