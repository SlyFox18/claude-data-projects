# DP Refresh Redesign — Phase 1 (Config, CI Checks, Hygiene, Tuning) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register every DP producer with its dependencies in one checked config, make CI enforce that
config against the notebook code, clean up notebook hygiene and orphans, and tune the `runMultiple`
session on a large chain, so Phase 2 can build the real orchestrator on a trustworthy foundation.

**Architecture:** A new config `deploy/dp_refresh_dag.json` in fabric-workspace-docs lists every
producer (notebooks + the 2 staging dataflows) with `dependsOn`/`produces`/cadence, plus a report→table
map. A static scanner (`deploy/dag_scan.py`) reads each notebook's code and each RP - Dev model's TMDL;
a checker (`deploy/dag_config.py` + CLI `deploy/dag_check.py`) fails CI when the config and the code
disagree (missing dependency, unregistered notebook, wrong lakehouse, cycles…). The old
`dp_backend_scope.json` and the 3 DP pipelines stay untouched until Phase 2 replaces them. Tuning reuses
`Proto_RunMultiple` with a `dag_json` parameter and measures allocated cores via Spark's resource-usage API.

**Tech Stack:** Python 3.12 (CI) / 3.13 (local), pytest, GitHub Actions, Fabric REST via `fab api`,
Fabric notebooks (`notebookutils.notebook.runMultiple`), DuckDB not needed.

**Spec:** `docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md` (§4.1, §4.2, §7 Phase 1)
**Phase 0 results:** `docs/architecture/dp-refresh-prototype-results.md`

---

## Ground rules (read before any task)

- **Two repos, branch `dev` only.** `fabric-workspace-docs` (Fabric Git mirror: notebooks, `deploy/`,
  CI) and `data-projects` (tools in `tools/dp-migration/`, docs). Never commit to `main`. Both repos have
  unrelated uncommitted files: **stage only the files a task names.**
- **Pushing `fabric-workspace-docs` `dev` triggers CI** (`.github/workflows/deploy.yml`). If a push is
  rejected because remote `dev` moved (Fabric commits land there), use `git pull --rebase --autostash
  origin dev`, then push.
- **Single writer for Dev workspaces:** notebook code reaches Fabric only by push →
  `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/wait_ci.py` →
  `python .../git_sync.py <workspaceId>`. Never `fab import`. If `git_sync.py` refuses, stop and report.
- **Never delete anything in Fabric or Git without Brian's explicit OK** (Task 9 is controller-only).
- After any Gold notebook runs (they VACUUM), refresh the SQL endpoint metadata:
  `fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"`
- Don't run notebooks 4:15–6:00 AM CST.
- Bash hooks sometimes falsely block commands ("printenv", "az token"). Put the command in a script file
  in the session scratchpad
  (`C:/Users/bfox/AppData/Local/Temp/claude/c--Users-bfox-Documents-Git-Projects-data-projects/ed03239b-4817-4e80-8f42-4dd2204a7945/scratchpad`)
  and run that. Prefix direct `fab` use with `export PATH="$HOME/.local/bin:$PATH"`.

| Thing | Value |
|---|---|
| DP - Staging - Dev | workspace `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`, lakehouse DP_Staging |
| DP - Presentation - Dev | workspace `73fd5443-240e-410a-990a-98827f32c087`, lakehouse DP_Presentation |
| Proto_RunMultiple | Staging `52709f40-5484-462d-9786-a096bb32741d`, Presentation `7b221481-19b4-4506-a23c-e220ee1a6944` |
| Report models | `workspaces/RP - Dev/*.SemanticModel` (table partitions use `Sql.Database(<endpoint>, "DP_Presentation")` then `Source{[Schema="dbo",Item="<table>"]}`) |
| Staging dataflows | `df_RepairOrderDetail_Raw` → table `RepairOrderDetail`; `df_InSalPar_Audit_Raw` → `InSalPar_Audit` |

## File structure

| File | Repo | Responsibility |
|---|---|---|
| `deploy/dag_scan.py` (create) | fabric-workspace-docs | Pure static scanning: notebook reads/writes/lakehouse/dynamic flag; report model → DP tables |
| `deploy/test_dag_scan.py` (create) | fabric-workspace-docs | Tests for the scanner |
| `deploy/dag_config.py` (create) | fabric-workspace-docs | Load config; `check(config, notebooks, reports)` → error list; `tier_dag(config, model, tier)` subgraph helper |
| `deploy/test_dag_config.py` (create) | fabric-workspace-docs | Tests for the checks and subgraph |
| `deploy/dag_check.py` (create) | fabric-workspace-docs | CLI: scan repo + check config; exit 1 with messages |
| `deploy/bootstrap_dag_config.py` (create) | fabric-workspace-docs | One-time generator of the first draft config from the scan |
| `deploy/dp_refresh_dag.json` (create) | fabric-workspace-docs | **The config** (source of truth from here on) |
| `deploy/hygiene_audit.py` + `deploy/test_hygiene_audit.py` (create) | fabric-workspace-docs | Gold notebook hygiene rules (UTC pin, VACUUM per written table, no saveAsTable) |
| `.github/workflows/deploy.yml` (modify) | fabric-workspace-docs | Run pytest + dag_check before deploying |
| Gold notebooks failing hygiene (modify) | fabric-workspace-docs | Add UTC pin / VACUUM |
| `Orchestration/Proto_RunMultiple.Notebook/notebook-content.py` ×2 (modify) | fabric-workspace-docs | Add `dag_json` parameter |
| `tools/dp-migration/spark_usage.py` (create) | data-projects | Core-seconds, idle time, core efficiency for a notebook run (resource-usage API) |
| `tools/dp-migration/tune_run.py` (create) | data-projects | Run one report's chain through the prototypes at a given concurrency; print measurements |
| `docs/architecture/dp-refresh-phase1-results.md` (create) | data-projects | Config stats, hygiene fixes, orphan decisions, tuning results + recommendation |

Config schema (`deploy/dp_refresh_dag.json`) — used by every task below:

```json
{
  "items": [
    {
      "name": "Build_Gold_ServiceDetail",
      "type": "notebook",
      "workspace": "presentation",
      "tier": "gold",
      "cadence": "daily",
      "dependsOn": ["Build_Gold_ServiceInvoices", "Build_Silver_WkRoFile"],
      "produces": ["Fact_Service_Detail"],
      "extraReads": [],
      "scanIgnore": [],
      "dynamicReviewed": false
    }
  ],
  "reports": [ { "model": "Customer Anatomy", "tables": ["Fact_Service_Detail"] } ],
  "excluded": [ { "name": "Utilities_BackfillMDInvoicesNoFreightSnapshot_20260923", "reason": "one-off backfill" } ]
}
```

- `type`: `notebook` | `dataflow`. `workspace`: `staging` | `presentation`. `tier`: `staging` (dataflows),
  `silver`, `gold`. `cadence`: `daily` | `weekly` (Mondays) | `monthly` (the 1st) | `manual` (never
  scheduled; run when its code changes, e.g. a fixed calendar) | `intraday`.
- `extraReads` / `scanIgnore`: table names the scanner can't see (dynamic code) or wrongly sees.
- `dynamicReviewed: true` is required when the scanner flags the notebook as dynamic (a human checked
  its reads/writes and filled `extraReads`/`produces`).
- Optional per item: `timeoutSeconds` (int).

---

### Task 1: Notebook scanner (`dag_scan.py`, notebook part)

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\deploy\dag_scan.py`
- Create: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\deploy\test_dag_scan.py`

- [ ] **Step 1: Write the failing tests**

```python
# deploy/test_dag_scan.py
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from dag_scan import scan_notebook_source, scan_notebooks  # noqa: E402

HEADER = '''# Fabric notebook source

# METADATA ********************

# META {
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse_name": "DP_Presentation"
# META     }
# META   }
# META }

# CELL ********************

'''


def test_reads_writes_and_lakehouse():
    src = HEADER + '''spark.conf.set("spark.sql.session.timeZone", "UTC")
a = spark.read.table("Silver_WkMechWk")
b = spark.sql("SELECT * FROM Silver_WkOthSub s JOIN dim_Parts p ON s.x = p.x")
c = spark.read.format("delta").load("Tables/lookup_InspectionJobCodes")
out.write.format("delta").mode("overwrite").save("Tables/TechnicianEfficiency")
spark.sql("VACUUM delta.`Tables/TechnicianEfficiency` RETAIN 0 HOURS")
'''
    info = scan_notebook_source(src)
    assert info["lakehouse"] == "DP_Presentation"
    assert info["writes"] == {"TechnicianEfficiency"}
    assert {"silver_wkmechwk", "silver_wkothsub", "dim_parts", "lookup_inspectionjobcodes"} <= info["reads"]
    assert "technicianefficiency" not in info["reads"]  # own table (VACUUM) is not a read
    assert info["dynamic"] is False


def test_comments_and_markdown_are_ignored():
    src = HEADER + '''# df = spark.read.table("Silver_Old")
x = 1
'''
    assert "silver_old" not in scan_notebook_source(src)["reads"]


def test_dynamic_references_are_flagged():
    for line in ('t = spark.read.table(f"Silver_{name}")',
                 'df.write.save(f"Tables/{target}")',
                 'DeltaTable.forPath(spark, path)',
                 'spark.read.load("abfss://ws@onelake.dfs.fabric.microsoft.com/x")',
                 'spark.read.table(table_name)'):
        assert scan_notebook_source(HEADER + line + "\n")["dynamic"] is True, line


def test_scan_notebooks_walks_dp_workspaces(tmp_path):
    ws = tmp_path / "workspaces" / "DP - Presentation - Dev" / "Fact Tables" / "Build_Gold_X.Notebook"
    ws.mkdir(parents=True)
    (ws / ".platform").write_text('{"metadata": {"type": "Notebook", "displayName": "Build_Gold_X"}}', encoding="utf-8")
    (ws / "notebook-content.py").write_text(HEADER + 'df.write.save("Tables/Fact_X")\n', encoding="utf-8")
    other = tmp_path / "workspaces" / "RP - Dev" / "Y.Notebook"
    other.mkdir(parents=True)
    (other / "notebook-content.py").write_text(HEADER, encoding="utf-8")

    found = scan_notebooks(tmp_path)

    assert set(found) == {"Build_Gold_X"}
    assert found["Build_Gold_X"]["workspace"] == "presentation"
    assert found["Build_Gold_X"]["writes"] == {"Fact_X"}
    assert found["Build_Gold_X"]["path"] == "workspaces/DP - Presentation - Dev/Fact Tables/Build_Gold_X.Notebook"
```

- [ ] **Step 2: Run to verify failure**

Run: `cd C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/deploy && python -m pytest test_dag_scan.py -q`
Expected: FAIL, `ModuleNotFoundError: No module named 'dag_scan'`.

- [ ] **Step 3: Implement**

```python
# deploy/dag_scan.py
"""Static scan of DP notebooks (and, below, report models) for the refresh DAG.

Reads are returned lower-cased (Spark table names are case-insensitive); writes keep their spelling.
A notebook is "dynamic" when it builds table names or paths at run time, so its reads/writes can't be
fully known statically and the config must declare them (extraReads / dynamicReviewed).
"""
import json
import re
from pathlib import Path

WORKSPACES = {"DP - Staging - Dev": "staging", "DP - Presentation - Dev": "presentation"}
LAKEHOUSE_BY_WORKSPACE = {"staging": "DP_Staging", "presentation": "DP_Presentation"}

_NAME = r"([A-Za-z_][A-Za-z0-9_]*)"
READ_PATTERNS = [
    rf"spark\.read\.table\(\s*[\"']{_NAME}[\"']",
    rf"\.load\(\s*[\"'][^\"']*Tables/{_NAME}[\"']",
    rf"delta\.`[^`]*Tables/{_NAME}`",
    rf"(?i)\b(?:FROM|JOIN)\s+{_NAME}\b",
]
WRITE_PATTERNS = [
    rf"\.save\(\s*[\"'][^\"']*Tables/{_NAME}[\"']",
    rf"saveAsTable\(\s*[\"']{_NAME}[\"']",
]
DYNAMIC_PATTERNS = [
    r"Tables/\{",
    r"abfss://",
    r"DeltaTable\.forPath\(",
    r"spark\.read\.table\(\s*f[\"']",
    r"spark\.read\.table\(\s*[A-Za-z_]",
]
LAKEHOUSE_PATTERN = r'"default_lakehouse_name":\s*"([^"]+)"'


def _code(src: str) -> str:
    """Code lines only: drops META, markdown and Python comment lines (all start with '#')."""
    return "\n".join(line for line in src.splitlines() if not line.lstrip().startswith("#"))


def scan_notebook_source(src: str) -> dict:
    code = _code(src)
    writes = {m for p in WRITE_PATTERNS for m in re.findall(p, code)}
    own = {w.lower() for w in writes}
    reads = {m.lower() for p in READ_PATTERNS for m in re.findall(p, code)} - own
    lakehouse = re.search(LAKEHOUSE_PATTERN, src)
    return {
        "reads": reads,
        "writes": writes,
        "lakehouse": lakehouse.group(1) if lakehouse else None,
        "dynamic": any(re.search(p, code) for p in DYNAMIC_PATTERNS),
    }


def _display_name(item_dir: Path) -> str:
    platform = item_dir / ".platform"
    if platform.is_file():
        try:
            return json.loads(platform.read_text(encoding="utf-8"))["metadata"]["displayName"]
        except (ValueError, KeyError):
            pass
    return item_dir.name[: -len(".Notebook")]


def scan_notebooks(repo_root: Path) -> dict:
    """{displayName: {reads, writes, lakehouse, dynamic, workspace, path}} for every DP notebook."""
    found = {}
    for folder, logical in WORKSPACES.items():
        base = Path(repo_root) / "workspaces" / folder
        for content in sorted(base.rglob("*.Notebook/notebook-content.py")):
            item_dir = content.parent
            info = scan_notebook_source(content.read_text(encoding="utf-8"))
            info["workspace"] = logical
            info["path"] = item_dir.relative_to(repo_root).as_posix()
            found[_display_name(item_dir)] = info
    return found
```

- [ ] **Step 4: Run tests** — Expected: 4 passed.

- [ ] **Step 5: Run against the real repo** (read-only smoke check)

`cd C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs && python -c "import sys; sys.path.insert(0,'deploy'); from dag_scan import scan_notebooks; from pathlib import Path; s=scan_notebooks(Path('.')); print(len(s)); print(sorted(n for n,i in s.items() if i['dynamic']))"`
Expected: ~101 notebooks (99 Build/Utilities + the Proto_* ones); the dynamic list includes
`Build_Gold_MDInvoicesNoFreightSnapshot`, `Build_Gold_PartsOpenOrdersSnapshot`,
`Build_Gold_PlanterInspectionPartSales`, `Build_Silver_InTrans`, and the committed Utilities notebook.
Record the actual list in your report.

- [ ] **Step 6: Commit** (fabric-workspace-docs): `git add deploy/dag_scan.py deploy/test_dag_scan.py`,
  message `DAG scanner: notebook reads/writes/lakehouse/dynamic` + Co-Authored-By trailer. Don't push yet.

---

### Task 2: Report scanner (`dag_scan.py`, report part)

**Files:** Modify `deploy/dag_scan.py`; modify `deploy/test_dag_scan.py`.

- [ ] **Step 1: Add the failing test** (append to `test_dag_scan.py`; add `scan_reports` to the import)

```python
from dag_scan import scan_reports  # noqa: E402


def test_scan_reports_collects_dp_presentation_items(tmp_path):
    tables = tmp_path / "workspaces" / "RP - Dev" / "Labor Performance.SemanticModel" / "definition" / "tables"
    tables.mkdir(parents=True)
    (tables / "TechnicianEfficiency.tmdl").write_text(
        'Source = Sql.Database("x.datawarehouse.fabric.microsoft.com", "DP_Presentation"),\n'
        'dbo_T = Source{[Schema="dbo",Item="TechnicianEfficiency"]}[Data]\n', encoding="utf-8")
    (tables / "Data Refresh.tmdl").write_text('Source = #table({"Date"}, {})\n', encoding="utf-8")
    (tables / "Other.tmdl").write_text(
        'Source = Sql.Database("y", "LH_Master_Data"),\nx = Source{[Schema="dbo",Item="Invoice"]}[Data]\n',
        encoding="utf-8")
    empty = tmp_path / "workspaces" / "RP - Dev" / "Search.SemanticModel" / "definition" / "tables"
    empty.mkdir(parents=True)

    assert scan_reports(tmp_path) == {"Labor Performance": ["TechnicianEfficiency"]}
```

- [ ] **Step 2: Run** — Expected: FAIL (ImportError `scan_reports`).

- [ ] **Step 3: Implement** (append to `dag_scan.py`)

```python
REPORT_WORKSPACE = "RP - Dev"
_ITEM = r'Item\s*=\s*"([^"]+)"'


def scan_reports(repo_root: Path, workspace_folder: str = REPORT_WORKSPACE) -> dict:
    """{model name: sorted DP_Presentation tables} for every model that reads DP_Presentation."""
    reports = {}
    base = Path(repo_root) / "workspaces" / workspace_folder
    for model_dir in sorted(base.glob("*.SemanticModel")):
        tables = set()
        for tmdl in (model_dir / "definition" / "tables").glob("*.tmdl"):
            text = tmdl.read_text(encoding="utf-8")
            if '"DP_Presentation"' in text:
                tables.update(re.findall(_ITEM, text))
        if tables:
            reports[model_dir.name[: -len(".SemanticModel")]] = sorted(tables)
    return reports
```

- [ ] **Step 4: Run tests** — Expected: 5 passed. Smoke: print `scan_reports(Path('.'))` from the repo
  root and record the model count (expected ~23 of the 25 RP - Dev models; `Table-Column-Names-Search`
  and any model not on DP will be absent). If a model you know is migrated is missing, open one of its
  table `.tmdl` files and report the connector pattern it uses.

- [ ] **Step 5: Commit**: `deploy/dag_scan.py deploy/test_dag_scan.py`, message `DAG scanner: report model → DP tables`.

---

### Task 3: Config checks (`dag_config.py`) and CLI (`dag_check.py`)

**Files:** Create `deploy/dag_config.py`, `deploy/test_dag_config.py`, `deploy/dag_check.py`.

- [ ] **Step 1: Write the failing tests**

```python
# deploy/test_dag_config.py
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from dag_config import check, tier_dag  # noqa: E402


def nb(name, tier="gold", ws="presentation", deps=(), produces=(), **kw):
    item = {"name": name, "type": "notebook", "workspace": ws, "tier": tier, "cadence": "daily",
            "dependsOn": list(deps), "produces": list(produces)}
    item.update(kw)
    return item


def scanned(reads=(), writes=(), ws="presentation", lakehouse="DP_Presentation", dynamic=False):
    return {"reads": {r.lower() for r in reads}, "writes": set(writes), "lakehouse": lakehouse,
            "dynamic": dynamic, "workspace": ws, "path": "p"}


def base():
    config = {
        "items": [
            nb("Build_Silver_A", tier="silver", ws="staging", produces=["Silver_A"]),
            nb("Build_Gold_Dim", deps=["Build_Silver_A"], produces=["dim_X"]),
            nb("Build_Gold_Fact", deps=["Build_Gold_Dim"], produces=["Fact_X"]),
        ],
        "reports": [{"model": "R", "tables": ["Fact_X", "dim_X"]}],
        "excluded": [{"name": "Utilities_Old", "reason": "one-off"}],
    }
    notebooks = {
        "Build_Silver_A": scanned(reads=["ArMaster"], writes=["Silver_A"], ws="staging", lakehouse="DP_Staging"),
        "Build_Gold_Dim": scanned(reads=["Silver_A"], writes=["dim_X"]),
        "Build_Gold_Fact": scanned(reads=["dim_X", "Silver_A"], writes=["Fact_X"]),
        "Utilities_Old": scanned(),
    }
    reports = {"R": ["Fact_X", "dim_X"]}
    return config, notebooks, reports


def test_clean_config_has_no_errors():
    assert check(*base()) == []


def test_transitive_dependency_is_enough():
    config, notebooks, reports = base()  # Fact reads Silver_A only via Dim -> fine
    assert check(config, notebooks, reports) == []


def test_missing_dependency_is_reported():
    config, notebooks, reports = base()
    config["items"][2]["dependsOn"] = []
    errors = check(config, notebooks, reports)
    assert any("Build_Gold_Fact reads dim_x (produced by Build_Gold_Dim)" in e for e in errors)


def test_unregistered_build_notebook():
    config, notebooks, reports = base()
    notebooks["Build_Gold_New"] = scanned(writes=["Fact_New"])
    assert any("Build_Gold_New" in e and "not registered" in e for e in check(config, notebooks, reports))


def test_registered_notebook_missing_from_repo():
    config, notebooks, reports = base()
    del notebooks["Build_Gold_Fact"]
    assert any("Build_Gold_Fact" in e and "not found" in e for e in check(config, notebooks, reports))


def test_unknown_dependency_and_cycle():
    config, notebooks, reports = base()
    config["items"][1]["dependsOn"] = ["Build_Gold_Fact", "Nope"]
    errors = check(config, notebooks, reports)
    assert any("unknown dependency Nope" in e for e in errors)
    assert any("cycle" in e for e in errors)


def test_lakehouse_and_workspace_mismatch():
    config, notebooks, reports = base()
    notebooks["Build_Gold_Dim"]["lakehouse"] = "DP_Staging"
    assert any("Build_Gold_Dim" in e and "lakehouse" in e for e in check(config, notebooks, reports))


def test_produces_must_match_scanned_writes():
    config, notebooks, reports = base()
    config["items"][1]["produces"] = ["dim_Y"]
    assert any("Build_Gold_Dim" in e and "produces" in e for e in check(config, notebooks, reports))


def test_dynamic_notebook_needs_review_flag():
    config, notebooks, reports = base()
    notebooks["Build_Gold_Fact"]["dynamic"] = True
    assert any("dynamicReviewed" in e for e in check(config, notebooks, reports))
    config["items"][2]["dynamicReviewed"] = True
    assert check(config, notebooks, reports) == []


def test_silver_may_not_depend_on_gold():
    config, notebooks, reports = base()
    config["items"][0]["dependsOn"] = ["Build_Gold_Dim"]
    assert any("Build_Silver_A" in e and "tier" in e for e in check(config, notebooks, reports))


def test_duplicate_producer_and_duplicate_name():
    config, notebooks, reports = base()
    config["items"].append(nb("Build_Gold_Dim", produces=["dim_X"]))
    errors = check(config, notebooks, reports)
    assert any("duplicate" in e for e in errors)


def test_report_tables_must_match_scan_and_have_producers():
    config, notebooks, reports = base()
    reports["R"] = ["Fact_X", "dim_X", "dim_DateTable"]
    errors = check(config, notebooks, reports)
    assert any(e.startswith("report R") and "dim_datetable" in e.lower() for e in errors)


def test_bad_enum_values():
    config, notebooks, reports = base()
    config["items"][0]["cadence"] = "yearly"
    assert any("cadence" in e for e in check(config, notebooks, reports))


def test_tier_dag_for_report():
    config, _, _ = base()
    gold = tier_dag(config, "R", "gold")
    assert [a["name"] for a in gold] == ["Build_Gold_Dim", "Build_Gold_Fact"]
    assert gold[0]["dependsOn"] == []                 # cross-tier edge dropped
    assert gold[1]["dependsOn"] == ["Build_Gold_Dim"]
    assert [a["name"] for a in tier_dag(config, "R", "silver")] == ["Build_Silver_A"]
```

- [ ] **Step 2: Run** — `python -m pytest test_dag_config.py -q` → FAIL (ModuleNotFoundError).

- [ ] **Step 3: Implement `dag_config.py`**

```python
# deploy/dag_config.py
"""The DP refresh DAG config: load, check against the scanned code, and pick sub-graphs."""
import json
from pathlib import Path

CONFIG_PATH = Path(__file__).parent / "dp_refresh_dag.json"
TYPES = {"notebook", "dataflow"}
WORKSPACES = {"staging": "DP_Staging", "presentation": "DP_Presentation"}
TIERS = {"staging": 0, "silver": 1, "gold": 2}
CADENCES = {"daily", "weekly", "monthly", "manual", "intraday"}
REQUIRED = ("name", "type", "workspace", "tier", "cadence", "dependsOn", "produces")


def load_config(path: Path = CONFIG_PATH) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _closure(items_by_name: dict, name: str) -> set:
    seen, stack = set(), list(items_by_name.get(name, {}).get("dependsOn", []))
    while stack:
        dep = stack.pop()
        if dep in seen or dep not in items_by_name:
            continue
        seen.add(dep)
        stack.extend(items_by_name[dep].get("dependsOn", []))
    return seen


def _cycles(items_by_name: dict) -> list:
    errors, state = [], {}

    def visit(name, path):
        state[name] = "active"
        for dep in items_by_name[name].get("dependsOn", []):
            if dep not in items_by_name:
                continue
            if state.get(dep) == "active":
                errors.append("cycle: " + " -> ".join(path + [dep]))
            elif dep not in state:
                visit(dep, path + [dep])
        state[name] = "done"

    for name in items_by_name:
        if name not in state:
            visit(name, [name])
    return errors


def check(config: dict, notebooks: dict, reports: dict) -> list:
    errors = []
    items = config.get("items", [])
    excluded = {e["name"] for e in config.get("excluded", [])}
    names = [i.get("name") for i in items]
    for dup in sorted({n for n in names if names.count(n) > 1}):
        errors.append(f"duplicate item name {dup}")
    for dup in sorted(excluded & set(names)):
        errors.append(f"{dup} is both an item and excluded")
    by_name = {i["name"]: i for i in items if "name" in i}

    for item in items:
        name = item.get("name", "?")
        missing = [k for k in REQUIRED if k not in item]
        if missing:
            errors.append(f"{name}: missing keys {missing}")
            continue
        if item["type"] not in TYPES:
            errors.append(f"{name}: bad type {item['type']}")
        if item["workspace"] not in WORKSPACES:
            errors.append(f"{name}: bad workspace {item['workspace']}")
        if item["tier"] not in TIERS:
            errors.append(f"{name}: bad tier {item['tier']}")
        if item["cadence"] not in CADENCES:
            errors.append(f"{name}: bad cadence {item['cadence']}")
        for dep in item["dependsOn"]:
            if dep not in by_name:
                errors.append(f"{name}: unknown dependency {dep}")
            elif TIERS.get(by_name[dep].get("tier"), 0) > TIERS.get(item["tier"], 0):
                errors.append(f"{name}: tier {item['tier']} may not depend on {dep} (tier {by_name[dep]['tier']})")

    errors += _cycles(by_name)

    producer = {}
    for item in items:
        for table in item.get("produces", []):
            key = table.lower()
            if key in producer:
                errors.append(f"duplicate producer for {table}: {producer[key]} and {item['name']}")
            producer[key] = item["name"]

    for name, scan in sorted(notebooks.items()):
        if name.startswith("Build_") and name not in by_name and name not in excluded:
            errors.append(f"{name}: Build_* notebook not registered (add to items or excluded)")

    for item in items:
        if item.get("type") != "notebook" or "name" not in item:
            continue
        name = item["name"]
        scan = notebooks.get(name)
        if scan is None:
            errors.append(f"{name}: registered notebook not found in the repo")
            continue
        if scan["workspace"] != item["workspace"]:
            errors.append(f"{name}: config workspace {item['workspace']} but notebook is in {scan['workspace']}")
        expected_lh = WORKSPACES.get(item["workspace"])
        if scan["lakehouse"] != expected_lh:
            errors.append(f"{name}: default lakehouse {scan['lakehouse']} but workspace needs {expected_lh}")
        if scan["dynamic"] and not item.get("dynamicReviewed"):
            errors.append(f"{name}: builds table names at run time; review it, fill extraReads/produces, "
                          f"then set dynamicReviewed: true")
        if not scan["dynamic"] and {w.lower() for w in scan["writes"]} != {p.lower() for p in item["produces"]}:
            errors.append(f"{name}: produces {sorted(item['produces'])} but the code writes {sorted(scan['writes'])}")
        own = {p.lower() for p in item["produces"]}
        ignore = {t.lower() for t in item.get("scanIgnore", [])}
        reads = (scan["reads"] | {t.lower() for t in item.get("extraReads", [])}) - own - ignore
        upstream = _closure(by_name, name)
        for table in sorted(reads):
            source = producer.get(table)
            if source and source != name and source not in upstream:
                errors.append(f"{name} reads {table} (produced by {source}) but doesn't depend on it")

    declared = {r["model"]: {t.lower() for t in r["tables"]} for r in config.get("reports", [])}
    for model, tables in sorted(reports.items()):
        scanned_tables = {t.lower() for t in tables}
        if model not in declared:
            errors.append(f"report {model}: reads DP tables but isn't in config reports")
            continue
        if declared[model] != scanned_tables:
            errors.append(f"report {model}: config tables differ from the model: "
                          f"missing {sorted(scanned_tables - declared[model])}, "
                          f"extra {sorted(declared[model] - scanned_tables)}")
        for table in sorted(scanned_tables - set(producer)):
            errors.append(f"report {model}: table {table} has no producer in items")
    return errors


def tier_dag(config: dict, model: str, tier: str) -> list:
    """Items of one tier needed by a report (producers of its tables + upstream), dependency-ordered,
    with dependsOn limited to the same tier. Used by tuning runs and, later, the orchestrator."""
    by_name = {i["name"]: i for i in config["items"]}
    producer = {t.lower(): i["name"] for i in config["items"] for t in i["produces"]}
    report = next(r for r in config["reports"] if r["model"] == model)
    needed = set()
    for table in report["tables"]:
        src = producer.get(table.lower())
        if src:
            needed |= {src} | _closure(by_name, src)
    ordered, done = [], set()

    def visit(name):
        if name in done:
            return
        done.add(name)
        for dep in by_name[name]["dependsOn"]:
            if dep in needed:
                visit(dep)
        ordered.append(name)

    for name in sorted(needed):
        visit(name)
    return [{"name": n, "dependsOn": [d for d in by_name[n]["dependsOn"]
                                      if d in needed and by_name[d]["tier"] == tier]}
            for n in ordered if by_name[n]["tier"] == tier and by_name[n]["type"] == "notebook"]
```

- [ ] **Step 4: Implement `dag_check.py`**

```python
# deploy/dag_check.py
"""CI gate: the DP refresh DAG config must agree with the notebook code and the report models.

Usage: python deploy/dag_check.py   (exit 0 = clean, 1 = errors printed)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from dag_config import check, load_config  # noqa: E402
from dag_scan import scan_notebooks, scan_reports  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent


def main() -> int:
    config = load_config()
    errors = check(config, scan_notebooks(REPO_ROOT), scan_reports(REPO_ROOT))
    items = config["items"]
    print(f"dp_refresh_dag.json: {len(items)} items "
          f"({sum(i['type'] == 'notebook' for i in items)} notebooks), "
          f"{len(config['reports'])} reports, {len(config['excluded'])} excluded")
    for e in errors:
        print("ERROR:", e)
    print("OK" if not errors else f"{len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run all deploy tests** — `python -m pytest -q` in `deploy/` → all pass (2 existing + 5 scan + 14 config).

- [ ] **Step 6: Commit**: `deploy/dag_config.py deploy/test_dag_config.py deploy/dag_check.py`, message
  `DAG config checks + CLI`. Don't push yet (no config file exists yet; CI isn't wired until Task 5).

---

### Task 4: Bootstrap the config, then review it (controller reviews the draft)

**Files:** Create `deploy/bootstrap_dag_config.py`; create `deploy/dp_refresh_dag.json`.

- [ ] **Step 1: Write the generator**

```python
# deploy/bootstrap_dag_config.py
"""One-time: draft dp_refresh_dag.json from the scan (+ cadences from dp_backend_scope.json).

Usage: python deploy/bootstrap_dag_config.py  -> writes deploy/dp_refresh_dag.json (refuses to overwrite)
After this, the JSON is hand-maintained and dag_check.py keeps it honest.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from dag_scan import scan_notebooks, scan_reports  # noqa: E402

ROOT = Path(__file__).parent.parent
OUT = Path(__file__).parent / "dp_refresh_dag.json"
DATAFLOWS = [
    {"name": "df_RepairOrderDetail_Raw", "type": "dataflow", "workspace": "staging", "tier": "staging",
     "cadence": "daily", "dependsOn": [], "produces": ["RepairOrderDetail"]},
    {"name": "df_InSalPar_Audit_Raw", "type": "dataflow", "workspace": "staging", "tier": "staging",
     "cadence": "daily", "dependsOn": [], "produces": ["InSalPar_Audit"]},
]


def main():
    if OUT.exists():
        sys.exit(f"{OUT} exists; bootstrap only runs once")
    notebooks = scan_notebooks(ROOT)
    old = json.loads((Path(__file__).parent / "dp_backend_scope.json").read_text(encoding="utf-8"))
    cadence = {n["name"]: n["cadence"] for n in old["notebooks"]}
    build = {n: s for n, s in notebooks.items() if n.startswith("Build_")}
    producer = {d["produces"][0].lower(): d["name"] for d in DATAFLOWS}
    for name, scan in build.items():
        for table in scan["writes"]:
            producer[table.lower()] = name
    items = list(DATAFLOWS)
    for name in sorted(build):
        scan = build[name]
        deps = sorted({producer[t] for t in scan["reads"] if t in producer and producer[t] != name})
        items.append({
            "name": name, "type": "notebook", "workspace": scan["workspace"],
            "tier": "silver" if scan["workspace"] == "staging" else "gold",
            "cadence": cadence.get(name, "daily"),  # Task 4A reviews every cadence with Brian
            "dependsOn": deps, "produces": sorted(scan["writes"]),
            "extraReads": [], "scanIgnore": [], "dynamicReviewed": False,
        })
    excluded = [{"name": n, "reason": "not a scheduled producer (utility/prototype)"}
                for n in sorted(notebooks) if not n.startswith("Build_")]
    reports = [{"model": m, "tables": t} for m, t in scan_reports(ROOT).items()]
    OUT.write_text(json.dumps({"items": items, "reports": reports, "excluded": excluded}, indent=2) + "\n",
                   encoding="utf-8")
    print(f"wrote {OUT}: {len(items)} items, {len(reports)} reports, {len(excluded)} excluded")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Generate and run the checker**

```
cd C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs
python deploy/bootstrap_dag_config.py
python deploy/dag_check.py
```
Expected: the draft is written; the checker prints some errors. The typical ones are:
- `builds table names at run time` for the dynamic notebooks;
- `report X: table Y has no producer` (a table a report reads that no registered notebook writes);
- possibly `produces … but the code writes …` or `Build_Silver_*: tier` problems.

- [ ] **Step 3: Resolve each error in the JSON by hand (implementer), one class at a time**
  - **Dynamic notebooks:** open the notebook, find every table it reads and writes, put the writes in
    `produces` and any reads of DP-produced tables in `extraReads`, add the matching `dependsOn`, and set
    `"dynamicReviewed": true`. Write one line per notebook in your report explaining what you found.
  - **`has no producer`:** find what writes that table (grep `Tables/<name>` across `workspaces/`). If
    it's a notebook, check it's registered. If nothing writes it (e.g. a Silver table read through a
    shortcut, a table produced outside DP), **don't guess**: list it for the controller.
  - **SQL false positives** (a word after FROM/JOIN that happens to match a table name but isn't a
    read): add it to that item's `scanIgnore`, with a note in your report.
  - Never delete an item or change a cadence (Task 4A decides cadences with Brian).
- [ ] **Step 4:** Re-run `python deploy/dag_check.py` until it prints `OK`, or only errors you've listed
  for the controller. **Stop and report** with: item counts, the dynamic-notebook notes, `scanIgnore`
  additions, unresolved items, and the full `dependsOn` list for the Customer Anatomy notebooks (used
  in Task 11).
- [ ] **Step 5 (controller):** review the draft. Spot-check 5 notebooks' `dependsOn` against their code,
  decide the unresolved items (asking Brian where it's a business question), and confirm `excluded` only
  contains non-producers. Then the implementer commits `deploy/bootstrap_dag_config.py` and
  `deploy/dp_refresh_dag.json` (message `DP refresh DAG config: all producers, reports, exclusions`).

---

### Task 4A: Cadence review (implementer builds the table; Brian decides)

Goal: every producer runs only as often as its output can actually change, weighed against the risk of
stale joins (e.g. a new technician showing as unmatched until a monthly dim refreshes).

**Files:** Create `C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\cadence_review.py`
(read-only); output `C:\Users\bfox\Documents\Git-Projects\data-projects\docs\architecture\dp-refresh-cadence-review.md`.

- [ ] **Step 1: Write the script.** It must:
  - load `dp_refresh_dag.json` (import `load_config` from
    `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\deploy` via `sys.path`, as `tune_run.py` does);
  - for every notebook item: resolve its item ID (`fab api "workspaces/<ws>/items?type=Notebook"`), list
    its job instances (follow `continuationToken`, raise on non-2xx; copy `api`/`api_list` from
    `tools/dp-migration/proto_measure.py`), and compute the **median duration of its Completed runs**
    and the run count;
  - for every item, compute from the config: **direct inputs** (the tables it reads that other items
    produce, plus the Silver→Bronze source names from the scan), **downstream count** (items that
    depend on it, transitively), and **reports** that use any table it produces;
  - flag items whose code has **no dependency on data** (no reads at all, e.g. a generated calendar) as
    `static`;
  - write a markdown table sorted by tier, then name, with columns: Item · Tier · Current cadence · Reads
    · Static? · Median run (s) · Runs seen · Downstream items · Reports · **Recommendation** (leave empty)
    · **Brian's decision** (leave empty).
- [ ] **Step 2:** Run it; commit the script and the generated doc (data-projects, message `Cadence review table`).
- [ ] **Step 3 (controller):** fill the Recommendation column with reasons, using these rules:
  - **manual:** output can't change without a code change (static), e.g. `Build_Gold_DateTable`
    (fixed 2020–2030 calendar; add a note to extend END_DATE before 2030).
  - **weekly or manual:** reference data that changes only by business event and has cheap failure
    modes, e.g. `Build_Gold_BranchLocation`.
  - **daily:** anything a daily fact joins to where a missing new row shows as Unknown/unmatched
    (customers, parts, salespeople, technicians), unless it's expensive **and** the business confirms
    it rarely changes.
  - **monthly:** month-end snapshots (MD Invoices / Parts Open Orders snapshots) stay as they are.
  - Cost matters only where it's material: flag items whose median run is in the top 10.
- [ ] **Step 4 (controller + Brian):** present the table. Brian decides each row. Apply the decisions to
  `dp_refresh_dag.json` (`cadence`), run `python deploy/dag_check.py` (`OK`), commit (message
  `Cadences per Brian's review 2026-09-29`), and record his decisions in the review doc's last column.

---

### Task 5: Wire the checks into CI

**Files:** Modify `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\.github\workflows\deploy.yml`.

- [ ] **Step 1:** In **both** jobs (`deploy-dev` and `deploy-prod`), after `- run: pip install -r deploy/requirements.txt`, add:

```yaml
      - run: pip install pytest
      - name: Unit tests for deploy tooling
        run: python -m pytest deploy -q
      - name: DAG config must match the code
        run: python deploy/dag_check.py
```

- [ ] **Step 2:** Locally: `python -m pytest deploy -q && python deploy/dag_check.py` → both pass.
- [ ] **Step 3:** Commit `.github/workflows/deploy.yml` (message `CI: run deploy tests and DAG check before deploying`),
  push all Task 1–5 commits, then `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/wait_ci.py`.
  Expected: CI green, and the run's log shows the two new steps passing.
- [ ] **Step 4: Prove the gate works (no push):** temporarily delete one `dependsOn` entry in the JSON,
  run `python deploy/dag_check.py` → exit 1 naming the missing dependency; then `git checkout deploy/dp_refresh_dag.json`.

---

### Task 6: Hygiene audit

Rules for every **gold** notebook in the config: (1) sets `spark.sql.session.timeZone` to `UTC`;
(2) for every table it writes, VACUUMs it (`VACUUM delta.\`Tables/<table>\``); (3) never uses `saveAsTable`
(lower-cases table names). Dynamic notebooks are reported for manual review instead of being judged.

**Files:** Create `deploy/hygiene_audit.py`, `deploy/test_hygiene_audit.py`.

- [ ] **Step 1: Failing tests**

```python
# deploy/test_hygiene_audit.py
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from hygiene_audit import audit_source  # noqa: E402

GOOD = '''spark.conf.set("spark.sql.session.timeZone", "UTC")
df.write.format("delta").mode("overwrite").save("Tables/Fact_A")
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Fact_A` RETAIN 0 HOURS")
'''


def test_good_notebook_passes():
    assert audit_source(GOOD) == []


def test_missing_utc_and_vacuum():
    src = 'df.write.format("delta").save("Tables/Fact_A")\n'
    problems = audit_source(src)
    assert "no UTC session time zone" in problems
    assert "no VACUUM for Fact_A" in problems


def test_save_as_table_flagged():
    assert "uses saveAsTable" in audit_source(GOOD + 'df.write.saveAsTable("x")\n')


def test_commented_code_does_not_count():
    src = '# spark.conf.set("spark.sql.session.timeZone", "UTC")\ndf.write.save("Tables/Fact_A")\n'
    assert "no UTC session time zone" in audit_source(src)
```

- [ ] **Step 2:** Run → FAIL (ImportError).
- [ ] **Step 3: Implement**

```python
# deploy/hygiene_audit.py
"""Gold notebook hygiene: UTC session time zone, VACUUM after every overwrite, no saveAsTable.

Usage: python deploy/hygiene_audit.py   (prints problems per gold item; exit 1 if any)
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from dag_config import load_config  # noqa: E402
from dag_scan import WRITE_PATTERNS, scan_notebooks  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
UTC = r"spark\.conf\.set\(\s*[\"']spark\.sql\.session\.timeZone[\"']\s*,\s*[\"']UTC[\"']"


def _code(src):
    return "\n".join(line for line in src.splitlines() if not line.lstrip().startswith("#"))


def audit_source(src: str) -> list:
    code = _code(src)
    problems = []
    if not re.search(UTC, code):
        problems.append("no UTC session time zone")
    for table in sorted({m for p in WRITE_PATTERNS for m in re.findall(p, code)}):
        if not re.search(rf"VACUUM\s+delta\.`[^`]*Tables/{re.escape(table)}`", code):
            problems.append(f"no VACUUM for {table}")
    if "saveAsTable(" in code:
        problems.append("uses saveAsTable")
    return problems


def main() -> int:
    config = load_config()
    notebooks = scan_notebooks(REPO_ROOT)
    failing = 0
    for item in config["items"]:
        if item["tier"] != "gold" or item["type"] != "notebook":
            continue
        scan = notebooks[item["name"]]
        src = (REPO_ROOT / scan["path"] / "notebook-content.py").read_text(encoding="utf-8")
        problems = audit_source(src)
        if scan["dynamic"]:
            # Table names are built at run time, so the VACUUM rule can't be judged statically.
            print(f"{item['name']}: dynamic table names, reviewed by hand (static findings: {problems or 'none'})")
            continue
        if problems:
            failing += 1
            print(f"{item['name']}: {'; '.join(problems)}")
    print(f"{failing} gold notebook(s) with problems")
    return 1 if failing else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4:** Tests pass. Run `python deploy/hygiene_audit.py` and save its output for Task 7.
- [ ] **Step 5:** Commit `deploy/hygiene_audit.py deploy/test_hygiene_audit.py` (message `Gold hygiene audit`). Don't add it to CI yet (it fails until Task 7 is done).

---

### Task 7: Fix hygiene problems

**Files:** the gold notebooks listed by the audit (fabric-workspace-docs).

- [ ] **Step 1:** For each notebook the audit lists, edit only what's missing:
  - **No UTC:** add as the first statement of the first code cell (after its imports):
    `spark.conf.set("spark.sql.session.timeZone", "UTC")`, with a one-line comment
    `# Pin UTC so date extraction is deterministic (shared runMultiple sessions inherit this).`
  - **No VACUUM for `<table>`:** directly after that table's `.save("Tables/<table>")` statement, add:
    ```python
    spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
    spark.sql("VACUUM delta.`Tables/<table>` RETAIN 0 HOURS")
    ```
  - **saveAsTable:** replace with `.save("Tables/<exact table name>")` (keep the exact casing the
    reports use), and **list it for the controller**: a table-name casing change can break readers.
  - **Dynamic:** read the code, apply the same fixes by hand, and describe them in your report.
  Don't change anything else in these notebooks.
- [ ] **Step 2:** `python deploy/hygiene_audit.py` → `0 gold notebook(s) with problems` (dynamic notebooks
  print a "reviewed by hand" line and don't count; confirm you reviewed each one in Step 1). Then add a
  CI step after the DAG check in both jobs:
  `      - name: Gold hygiene\n        run: python deploy/hygiene_audit.py`.
- [ ] **Step 3:** `python deploy/dag_check.py` still `OK`. Commit the notebooks + workflow (message
  `Gold hygiene: UTC pin + VACUUM where missing; CI gate`), push, `wait_ci.py`, then
  `git_sync.py 73fd5443-240e-410a-990a-98827f32c087`.
- [ ] **Step 4:** Verify the edited notebooks still run: pick up to 5 of the edited notebooks (prefer
  small ones), run each with `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/run_item.py 73fd5443-240e-410a-990a-98827f32c087 <id> RunNotebook 3600`
  (IDs from `fab api "workspaces/73fd5443-240e-410a-990a-98827f32c087/items?type=Notebook"`), then
  refresh the SQL endpoint metadata. The rest get exercised by the Task 11 runs and Phase 2's first full run.

---

### Task 8: `spark_usage.py` (resource-usage measurement) — data-projects

**Files:** Create `C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\spark_usage.py` and `test_spark_usage.py`.

- [ ] **Step 1: Failing test for the core-seconds math**

```python
# tools/dp-migration/test_spark_usage.py
from spark_usage import core_seconds


def test_step_integral_of_allocated_cores():
    data = {"timestamps": [0, 1000, 3000, 4000], "allocatedCores": [8.0, 16.0, 8.0, 8.0]}
    # 8 cores for 1 s + 16 cores for 2 s + 8 cores for 1 s = 48 core-seconds
    assert core_seconds(data) == 48.0


def test_empty_timeline():
    assert core_seconds({"timestamps": [], "allocatedCores": []}) == 0.0
```

- [ ] **Step 2:** `python -m pytest test_spark_usage.py -q` → FAIL (ImportError).
- [ ] **Step 3: Implement**

```python
"""Spark resource usage for a notebook run: allocated executor core-seconds, idle time, efficiency.

Usage: python spark_usage.py <workspaceId> <notebookId> <startUtcISO> <endUtcISO>
Lists the notebook's Livy sessions submitted in the window and, per session, prints duration, allocated
executor core-seconds (the driver is not included; use for RELATIVE comparisons), idle seconds and
core efficiency, from Fabric's resourceUsage API.
"""
import json
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"


def core_seconds(data: dict) -> float:
    """Step integral of allocatedCores over timestamps (ms); the last point has zero width."""
    ts, cores = data.get("timestamps", []), data.get("allocatedCores", [])
    total = 0.0
    for i in range(len(ts) - 1):
        total += cores[i] * (ts[i + 1] - ts[i]) / 1000.0
    return round(total, 1)


def api(path: str) -> dict:
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    i = out.find('{\n  "status_code"')
    if i < 0:
        i = out.find("{")
    resp = json.loads(out[i:])
    if not 200 <= int(resp.get("status_code", 0)) <= 299:
        raise RuntimeError(f"fab api {path}: {json.dumps(resp)[:500]}")
    return resp.get("text") or {}


def main():
    ws, nb, start, end = sys.argv[1:5]
    sessions = [s for s in api(f"workspaces/{ws}/notebooks/{nb}/livySessions").get("value", [])
                if start <= (s.get("submittedDateTime") or "") <= end]
    for s in sorted(sessions, key=lambda s: s["submittedDateTime"]):
        usage = api(f"workspaces/{ws}/notebooks/{nb}/livySessions/{s['livyId']}"
                    f"/applications/{s['sparkApplicationId']}/resourceUsage")
        print(json.dumps({
            "submitted": s["submittedDateTime"], "state": s.get("state"),
            "duration_s": round(usage.get("duration", 0) / 1000, 1),
            "core_seconds": core_seconds(usage.get("data") or {}),
            "idle_s": round(usage.get("idleTime", 0) / 1000, 1),
            "core_efficiency": round(usage.get("coreEfficiency") or 0, 3),
            "capacityExceeded": usage.get("capacityExceeded"),
        }))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4:** Tests pass. **Calibrate against Phase 0's known CU:** run it for the Phase 0 prototype
  window (`2026-09-28T21:54:00` to `2026-09-28T22:00:00`) on both `Proto_RunMultiple` IDs, and for the
  baseline window (`2026-09-28T21:22:00` to `2026-09-28T21:31:00`) on 2–3 of the Build_* notebooks
  (IDs in `tools/dp-migration/proto_baseline.py`'s resolve output or `fab api .../items?type=Notebook`).
  Compute `CU(s) / core_seconds` for each (CU from the results doc: Proto Staging 792.0, Proto
  Presentation 1403.0, Contact 175.5, WkMechAdj 272.2, TechnicianAttendance 250.0). Record the ratios. If
  they're roughly stable (within ±25%), core-seconds is a usable proxy; if not, say so. Tuning then
  relies on Capacity Metrics hours instead (Task 11 Step 4).
- [ ] **Step 5:** Commit (data-projects) `tools/dp-migration/spark_usage.py tools/dp-migration/test_spark_usage.py`,
  message `spark_usage.py: allocated core-seconds per notebook run`.

---

### Task 9 (controller + Brian): Orphan cleanup

- [ ] **Step 1: Gather evidence (read-only).** For each candidate, record whether any config item, any
  RP - Dev model (`scan_reports`), or any notebook read (`scan_notebooks` reads) references it, and when it
  last ran (jobs API):
  - Environment items: `DP_Silver_HighConcurrency` (Staging), `DP_Gold_HighConcurrency` (Presentation)
  - `Pipeline_DP_Master_Orchestrator` (Presentation/Pipelines)
  - Notebooks: `Utilities_BackfillMDInvoicesNoFreightSnapshot_20260923` (in Git), and the workspace-only
    `Utilities_BackfillPartsOpenOrdersSnapshot_20260922`, `Utilities_JobCodesV2Test_20260923`
  - `Build_Gold_OpenOrders`, `Build_Gold_OpenOrderParts` and their tables (keep if any report reads them)
  - Tables: `dim_JobCodes_v2`, `BranchOperational`, `Silver_ArMasterCustomer_1` (check both lakehouses
    with `fab ls "<ws>.Workspace/<lh>.Lakehouse/Tables"`)
- [ ] **Step 2: Ask Brian** with the evidence table; delete only what he approves.
- [ ] **Step 3: Delete the approved ones.** For items in Git: delete the folder, commit, push, `wait_ci.py`,
  `git_sync.py`. For workspace-only items: `fab api -X delete "workspaces/<ws>/items/<id>"`. For tables:
  `fab rm "<ws>.Workspace/<lh>.Lakehouse/Tables/<table>" -f`. Then remove any `excluded` entries for
  deleted notebooks and make sure `dag_check.py` is still `OK`.

---

### Task 10: `dag_json` parameter for Proto_RunMultiple, plus `tune_run.py`

**Files:**
- Modify both `workspaces/DP - Staging - Dev/Orchestration/Proto_RunMultiple.Notebook/notebook-content.py`
  and `workspaces/DP - Presentation - Dev/Orchestration/Proto_RunMultiple.Notebook/notebook-content.py`
- Create `C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\tune_run.py`

- [ ] **Step 1: Notebook change (identical in both files).** In the PARAMETERS cell add two lines:
  `dag_json = ""` and `spark_conf_json = ""`. At the start of the cell that calls `runMultiple`
  (before `started = …`), add:

```python
# Session-level Spark settings: every child notebook in this runMultiple session inherits them.
for key, value in (json.loads(spark_conf_json) if spark_conf_json else {}).items():
    spark.conf.set(key, str(value))
    print("spark.conf", key, "=", spark.conf.get(key))
```

  and add `"spark_conf": spark_conf_json,` to the `summary` dict. Then, in the earlier cell, replace the
  block that picks `items`:

```python
if lakehouse not in CHAINS:
    raise ValueError(f"Unexpected default lakehouse {lakehouse!r}; refusing to run")
if dag_json:
    items = json.loads(dag_json)
elif failure_drill.lower() == "true":
    if lakehouse != "DP_Presentation":
        raise ValueError("failure_drill only runs in the Presentation copy")
    items = FAILURE_DRILL
else:
    items = CHAINS[lakehouse]
```

  Check the two files are still identical below `# MARKDOWN` and every cell parses (same check as
  Phase 0: split on `# CELL`/`# PARAMETERS CELL`, `ast.parse` each).
- [ ] **Step 2:** Commit both files (message `Proto_RunMultiple: accept dag_json`), push, `wait_ci.py`,
  `git_sync.py` for both workspaces.
- [ ] **Step 3: Write `tune_run.py`**

```python
"""Tuning run: one report's chain through the prototype orchestrators at a given concurrency.

Usage: python tune_run.py "<report model>" <concurrency> <label> [spark_conf_json]
Runs the Silver tier (Staging Proto_RunMultiple) then the Gold tier (Presentation), passing each tier's
sub-DAG from fabric-workspace-docs/deploy/dp_refresh_dag.json as dag_json. Prints the UTC window and
the spark_usage.py lines for both orchestrators. Exit 1 if either orchestrator job fails.
"""
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, r"C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\deploy")
from dag_config import load_config, tier_dag  # noqa: E402

PROTOS = [("silver", "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "52709f40-5484-462d-9786-a096bb32741d"),
          ("gold", "73fd5443-240e-410a-990a-98827f32c087", "7b221481-19b4-4506-a23c-e220ee1a6944")]


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")


def main():
    model, concurrency, label = sys.argv[1], sys.argv[2], sys.argv[3]
    spark_conf = sys.argv[4] if len(sys.argv) > 4 else ""
    config = load_config()
    start = now()
    ok = True
    for tier, ws, proto in PROTOS:
        dag = tier_dag(config, model, tier)
        print(f"{tier}: {len(dag)} notebooks")
        if not dag:
            continue
        r = subprocess.run([sys.executable, str(HERE / "run_item.py"), ws, proto, "RunNotebook", "5400",
                            "--param", f"dag_json={json.dumps(dag)}", "--param", f"concurrency={concurrency}",
                            "--param", f"run_label={label}_{tier}"]
                           + (["--param", f"spark_conf_json={spark_conf}"] if spark_conf else []),
                           capture_output=True, text=True)
        print(r.stdout[-600:])
        if r.returncode != 0:
            ok = False
            break
    end = now()
    print(f"WINDOW {start} {end}")
    for tier, ws, proto in PROTOS:
        u = subprocess.run([sys.executable, str(HERE / "spark_usage.py"), ws, proto, start, end],
                           capture_output=True, text=True)
        print(tier, u.stdout.strip() or u.stderr[-400:])
    print_report_counts(config, model)
    sys.exit(0 if ok else 1)


def print_report_counts(config, model):
    """Row counts of the report's DP_Presentation tables (compare across tuning runs)."""
    import duckdb
    root = ("abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/"
            "966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/")
    con = duckdb.connect()
    con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    tables = next(r["tables"] for r in config["reports"] if r["model"] == model)
    for t in tables:
        n = con.sql(f"SELECT count(*) FROM delta_scan('{root}{t}')").fetchone()[0]
        print(f"  COUNT {t:40s} {n:>12,}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4:** Dry check: `python -c` import of `tune_run` and print `tier_dag(load_config(), "Customer Anatomy", "gold")`.
  Expected: the ~10 Customer Anatomy Gold notebooks in dependency order, with their within-tier
  `dependsOn`. Commit `tools/dp-migration/tune_run.py` (message `tune_run.py: report chain through prototypes`).

---

### Task 11: Tuning runs on the Customer Anatomy chain

Customer Anatomy is the largest chain (4 Gold levels). Each run rebuilds real Dev tables, as a normal refresh does.

- [ ] **Step 1 (controller): confirm a quiet window with Brian** (nothing else in the DP workspaces;
  not 4:15–6:00 AM). Record the workspace Spark pool settings for context:
  `fab api "workspaces/ab15d64d-c7ba-415d-9bcf-7feb1ef9b201/spark/settings"` and the same for Presentation.
- [ ] **Step 2: Three runs, ≥20 minutes apart,** in the same quiet period:
  `python tune_run.py "Customer Anatomy" 2 ca_c2`, then `… 4 ca_c4`, then `… 8 ca_c8`.
  After each: refresh the SQL endpoint metadata. `tune_run.py` prints `COUNT` lines for every Customer
  Anatomy table. All three runs must give the same counts (±1% if Bronze moved).
- [ ] **Step 3: Record per run:** wall clock per tier, `core_seconds`, `idle_s`, `core_efficiency`, and
  whether any notebook failed. Read the orchestrator summaries from
  `Files/orchestration_proto/<label>_<tier>.json` (use the Phase 0 scratchpad `read_summaries.py` pattern:
  OneLake DFS GET with an `AzureCliCredential` storage token).
- [ ] **Step 4:** At least an hour later, get CU per run from Capacity Metrics ('Metrics By Item And Hour',
  **upper-case** item IDs, **local CDT** hours) for the two `Proto_RunMultiple` items. Runs ≥20 minutes
  apart may share an hour, so use it as a cross-check on the core-seconds ranking, not the only source.
- [ ] **Step 5: Spark-settings run.** ≥20 minutes after the last run, repeat with the best concurrency from
  Step 3 plus session settings adapted from JD's IncrementalCopyData_NB (F8 = 16 Spark vCores):
  `python tune_run.py "Customer Anatomy" <best> ca_conf '{"spark.sql.shuffle.partitions": "16", "spark.sql.autoBroadcastJoinThreshold": "52428800"}'`
  (on Windows, put the command in a scratchpad `.sh` so the JSON quoting survives). Check the orchestrator
  summary shows the settings applied, and the counts match the earlier runs. Compare against the same
  concurrency without settings. AQE is already on by default in Fabric, so report the difference honestly,
  even if it's none.
- [ ] **Step 6: Recommend** a default `concurrency` (the lowest CU that keeps wall clock acceptable),
  whether to apply the session settings, and whether the workspace Spark pool (max nodes / autoscale)
  looks worth changing. Pool changes are Brian's decision; only recommend them.

---

### Task 12 (controller): Phase 1 results, then STOP

- [ ] **Step 1:** Write `C:\Users\bfox\Documents\Git-Projects\data-projects\docs\architecture\dp-refresh-phase1-results.md`
  with these sections:
  1. The config: item counts by tier/cadence, reports, excluded, and dynamic notebooks and how they were resolved.
  2. The CI gates added.
  3. Hygiene fixes.
  4. Orphans deleted or kept.
  5. The core-seconds calibration.
  6. The tuning table (c=2/4/8 and the Spark-settings run: wall, core-seconds, efficiency, CU) and the
     recommended defaults.
  7. Cadence decisions (link to `dp-refresh-cadence-review.md`).
  8. Anything Phase 2 must know (e.g. weekly = Mondays, manual items never scheduled, session settings
     applied by the orchestrator).
- [ ] **Step 2:** Commit and push both repos' remaining Phase 1 commits.
- [ ] **Step 3: STOP.** Present the results to Brian. Phases 2–3 (the `Run_DP_Refresh` orchestrator,
  `dp_refresh_log`, `Pipeline_DP_Refresh`, alerts, drills) get their own plan (writing-plans).
