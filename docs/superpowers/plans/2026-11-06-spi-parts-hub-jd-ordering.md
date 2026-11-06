# JD ordering, phase 1 (Plan S, app 0.17.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A JD ordering area in SPI Parts Hub: JD Recommended Reorder and One-Time Order for every branch, with their own
rules, Templates, Orders and Special statuses, ending in an exported list, beside Prism.

**Spec:** `docs/superpowers/specs/2026-11-06-spi-parts-hub-jd-ordering-design.md` (decisions S-D1 to S-D7).

**Architecture:** A new Gold notebook writes `Fact_JD_Reorder` and `Fact_JD_SalesHistory` from a copy of the non-JD
calculation, held in step by a test; `Build_Gold_NonJD_Reorder` isn't touched. Contract 9 adds JD files beside today's.
In the app, one object (`jdSource`) makes JD data look like the `DataSource` every page already takes as a prop, so the
pages get JD data without being copied, and a small `AreaContext` gives them the path prefix and hides transfer UI.

**Tech Stack:** PySpark notebook (Fabric), DuckDB reference, Python publish, React 19 + TypeScript + Vite + Vitest.

---

## How this plan runs (weekend, unattended)

**Two independent tracks.** Neither waits for the other. The app works entirely on mock.

| Track | Tasks | Where it runs |
|---|---|---|
| **App** | S5, S6, S7, S8, S9, S10 | `nonjd-order-app`, branch `dev`, mock mode |
| **Data** | S1, S2, S3, S4 | `data-projects` and `fabric-workspace-docs`, branch `dev`; **Dev workspaces only** |
| **Brian, with Claude** | S11 (release), S12 (docs) | After Monday's try-it |

**Never over the weekend:** merge, deploy, any Prod write, the claim, anything on the Gateway PC, Fedora, `npm run build`.

**When something needs Brian** (a permission prompt, a dataflow credential, a missing list): stop that task, write down
exactly what's needed, and carry on with the other track. If S2 is stuck, S3's code is still written, statically checked
and committed, and its Dev run waits. S4's tests don't need Dev; its measurement falls back to the estimate in its Step 5.

**Rules for every task:** stage only named files (never `git add -A`; both repos hold unrelated user changes). Never read,
print or stage `.env*` files, `.env.example` included. Never `fab import` into Dev. No deletes of Fabric items. Commit
messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push after each commit.

## SharePoint (done and verified, 2026-11-06)

There is one set of lists, shared by Dev and Prod.

- **`JD_OrderRules`:** list GUID `22e28c35-2a57-4c71-a807-abd9f22d1409`, same columns as `NonJD_OrderRules`, with the Default
  row (item 1: 12 months, MinDemands 3, 4 weeks).
- **`Area`** (single line of text) on `NonJD_Orders` and `NonJD_OneTimeTemplates`. Blank = non-JD.

Claude's `az` Graph sign-in can write list **items** but can't create lists or columns (accessDenied, 2026-11-06).

## Decisions made in this plan

| # | Decision | Why |
|---|---|---|
| S-P1 | **The JD notebook copies the calculation; a test keeps the copies identical.** `deploy/test_jd_reorder_in_step.py` compares the five named regions byte for byte (S3). | The calculation is one long notebook whose cells build on each other. Extracting it into a shared module would change `Build_Gold_NonJD_Reorder`, which the spec forbids. |
| S-P2 | **`jdSource` wraps the `DataSource`.** Pages already take `source`; routes pass `source={jdSource}`. | No page copies. `useBranchData`, the caches (keyed by source object) and the parity banners work unchanged. |
| S-P3 | **Transfer fields stay out of Gold and the files; `jdSource` fills them with neutral values on read.** | The spec drops those columns, and the app's `ReorderPart` type requires them. Filling on read keeps the type and the files small. |
| S-P4 | **The JD publish can't block non-JD.** If the JD build failed or hasn't run, the publish goes ahead, and the JD files stay as they were. A JD build that finishes later triggers its own publish. | S-D4: non-JD is what's in use. Addition to the spec. |
| S-P5 | **Non-JD's Special statuses leaves out franchise D settings** (and JD's shows only those). | `NonJD_PartSettings` is shared, so a JD setting would otherwise appear on Shannon's page. Addition to the spec. |
| S-P6 | **Non-JD Orders and Templates read only blank-Area rows.** The default `loadOrders()` and `loadOneTimeTemplates()` exclude JD, so no non-JD caller changes. | The same reason. |

## File map

**fabric-workspace-docs**
- Create `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_JD_OrderRules_Raw.Dataflow/` (`.platform`, `mashup.pq`, `queryMetadata.json`)
- Create `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_JD_Reorder.Notebook/` (`.platform`, `notebook-content.py`)
- Create `deploy/test_jd_reorder_in_step.py`
- Modify `deploy/dp_refresh_dag.json`, `workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json`
- `deploy/dp_backend_scope.json` needs **no** change: `Build_Gold_NonJD_Reorder` isn't listed there either, and `dag_check` is the test.

**data-projects**
- Modify `tools/dp-migration/nonjd_reorder_check.py` (`--scope jd`) and its tests
- Modify `projects/part order tool - app/publish/`: `publish_logic.py`, `extract.py`, `build_files.py`, `run_publish.py`, their tests, `README.md`

**nonjd-order-app**
- Create `src/area/AreaContext.tsx`, `src/data/jdSource.ts`, `src/pages/JdLayout.tsx`
- Modify `src/engine/rules.ts`, `calc.ts`, `parity.ts`, `src/state/branchRows.ts`, `useBranchData.ts`
- Modify `src/data/contract.ts`, `types.ts`, `files.ts`, `lists.ts`, `source.ts`, `src/data/mock/*`, `src/config.ts`
- Modify `src/App.tsx`, `src/ui/areas.ts`, `src/ui/nav.ts`
- Modify `src/pages/`: `HomePage`, `ReorderPage`, `OneTimeOrderPage`, `TemplatesPage`, `OrdersPage`, `OrderPage`, `RulesPage`, `SpecialStatusesPage`, `LaunchPage`, `pages/orders/paths.ts`, `pages/part/*`, `pages/home/attention.ts`, `pages/rules/ruleForm.ts`

---

## Data track

### Task S1: The reference (data-projects)

**Files:** `tools/dp-migration/nonjd_reorder_check.py`, its test file.

The reference re-implements the calculation in DuckDB SQL. It gains a JD scope, so Gold's JD tables are checked by code
that doesn't share the notebook's.

- [ ] **Step 1: Failing tests.** Add to the test file (create `test_nonjd_reorder_check_scope.py` beside the tool if it has none):

```python
import nonjd_reorder_check as chk

def test_scopes_name_their_tables_and_defaults():
    nj, jd = chk.SCOPES["nonjd"], chk.SCOPES["jd"]
    assert nj.reorder_table == "Fact_NonJD_Reorder" and nj.rules_table == "NonJD_OrderRules"
    assert nj.builtin_supply == 12.0 and nj.excluded_branches == ["12", "5", "97", "4B", "93C"]
    assert jd.reorder_table == "Fact_JD_Reorder" and jd.history_table == "Fact_JD_SalesHistory"
    assert jd.rules_table == "JD_OrderRules"
    assert jd.builtin_supply == 4.0 and jd.excluded_branches == []   # S-D3, S-D5

def test_jd_scope_sql_is_franchise_d_with_s_d7(duck):
    # duck: an in-memory DuckDB fixture holding small parts, history and settings tables, below.
    duck.execute("""CREATE TABLE parts AS SELECT * FROM (VALUES
        ('1','D','HIST',5.0,0,0), ('1','D','STOCK',5.0,2,0), ('1','D','ORD',5.0,0,3), ('1','D','SET',5.0,0,0),
        ('1','D','DEAD',5.0,0,0), ('1','D','FREE',0.0,9,0), ('1','MC','OTHER',5.0,9,0), ('12','D','VAULT',5.0,1,0)
      ) t(Branch,Franchise,PartNumber,Cost,QuantityOnHand,OnOrder)""")
    duck.execute("CREATE TABLE hist AS SELECT '1' Branch,'D' Franchise,'HIST' PartNumber")
    duck.execute("CREATE TABLE settings AS SELECT '1' Branch,'D' Franchise,'SET' PartNumber")
    got = {r[0] for r in duck.execute(chk.jd_scope_sql("parts", "hist", "settings")).fetchall()}
    assert got == {"HIST", "STOCK", "ORD", "SET", "VAULT"}   # not DEAD, FREE (cost 0) or OTHER
```

- [ ] **Step 2: Run** `python -m pytest tools/dp-migration -q -k scope` → FAIL.

- [ ] **Step 3: Implement.** A small dataclass and the scope SQL. `main()` gains `--scope {nonjd,jd}` (default `nonjd`, whose
output and behaviour must not change). Every use of a table name, `BUILTIN_DEFAULT`, `_EXCLUDED_SQL` and the part filter reads
the chosen scope. With `--scope jd` the transfer steps, suggestion compare and purchases compare are skipped, the transfer
columns leave `COMPARE_COLS`, and `AppInboundQty` is 0.

```python
@dataclass(frozen=True)
class Scope:
    reorder_table: str
    history_table: str
    rules_table: str
    builtin_supply: float
    excluded_branches: list
    has_transfers: bool

SCOPES = {
    "nonjd": Scope("Fact_NonJD_Reorder", "Fact_NonJD_SalesHistory", "NonJD_OrderRules", 12.0, EXCLUDED_BRANCHES, True),
    "jd": Scope("Fact_JD_Reorder", "Fact_JD_SalesHistory", "JD_OrderRules", 4.0, [], False),
}

def jd_scope_sql(parts: str, hist: str, settings: str) -> str:
    """S-D7: franchise D, cost > 0, and a sale in the history, stock on hand or on order, or a part setting."""
    return f"""SELECT p.PartNumber FROM {parts} p
      WHERE upper(trim(p.Franchise)) = 'D' AND p.Cost > 0
        AND (coalesce(p.QuantityOnHand, 0) <> 0 OR coalesce(p.OnOrder, 0) <> 0
             OR EXISTS (SELECT 1 FROM {hist} h WHERE h.Branch = p.Branch AND h.Franchise = p.Franchise
                                                 AND h.PartNumber = p.PartNumber)
             OR EXISTS (SELECT 1 FROM {settings} s WHERE s.Branch = p.Branch AND s.Franchise = p.Franchise
                                                     AND s.PartNumber = p.PartNumber))"""
```

The history test uses the 60-month window (`MonthStart >= history_start`), as Gold does; the unit test's table has no dates
because `jd_scope_sql` is given an already-windowed relation.

- [ ] **Step 4: Run** the tool's tests → PASS. Then `python nonjd_reorder_check.py --tier prod` → same PASS and fingerprint as
before the change (read-only).

- [ ] **Step 5: Commit** `Plan S task S1: nonjd_reorder_check --scope jd`.

### Task S2: The rules dataflow and shortcut (fabric-workspace-docs, Dev)

**The SharePoint list and Default row are done** (above). **The coordinator is creating `df_JD_OrderRules_Raw` and its
`dp_refresh_dag.json` entry directly (2026-11-06): don't redo them.** What's left, once that dataflow is committed:

- [ ] **Step 1: Confirm** `df_JD_OrderRules_Raw.Dataflow` and its DAG entry are on `dev` (`produces: ["JD_OrderRules"]`) and its `mashup.pq` reads list `22e28c35-2a57-4c71-a807-abd9f22d1409`. If not there yet, report and go on with the other tasks.

- [ ] **Step 2: The shortcut, if that work didn't add it.** `DP_Presentation.Lakehouse/shortcuts.metadata.json`, as `NonJD_OrderRules`'s:

```json
{"name": "JD_OrderRules", "path": "/Tables", "target": {"type": "OneLake", "oneLake": {"path": "Tables/JD_OrderRules",
 "itemId": "876255e0-d462-4697-adc1-4a655f5bb101", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"}}}
```

`python deploy/dag_check.py`, `python -m pytest deploy -q`. Commit `Plan S task S2: JD_OrderRules shortcut`, push. Git sync `DP - Presentation - Dev` with `tools/dp-migration/git_sync.py`.

- [ ] **Step 3: Run it in Dev if it hasn't run:** `run_item.py <staging workspace> <item> Refresh`. **If it fails on credentials, that piece waits for Brian** (he opens it once in the Dev UI and picks the existing SharePoint connection, as L1). Report and go on. On success, confirm with DuckDB that `JD_OrderRules` has the Default row, then `python deploy/sync_shortcuts.py` (dry run) and `--apply` **for Dev only**.

### Task S3: `Build_Gold_JD_Reorder` (fabric-workspace-docs, Dev)

**Files:** the new notebook, `deploy/test_jd_reorder_in_step.py`, `deploy/dp_refresh_dag.json`.

- [ ] **Step 1: The failing guard test.**

```python
"""S-P1: Build_Gold_JD_Reorder copies these regions of Build_Gold_NonJD_Reorder. A change to one must go in both."""
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parent.parent / "workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool"
NONJD = ROOT / "Build_Gold_NonJD_Reorder.Notebook/notebook-content.py"
JD = ROOT / "Build_Gold_JD_Reorder.Notebook/notebook-content.py"
# (name, start marker, end marker): each region runs from the start marker's line up to the end marker's line.
REGIONS = [
    ("rule validation", "# ---- Rules list: validate", "# ---- Transfer rules list: validate"),
    ("rule pick", "# ---- Step 1: each part's rule ----", "# ---- Part 2 item 1: each part's transfer rule ----"),
    ("settings", "# ---- Settings: latest row per key", "# ---- Step 8b: committed app transfers"),
    ("demand", "# ---- Steps 2-3: demand over", "# ---- Steps 3-14: demand, target"),
    ("calculation", "# ---- Steps 3-14: demand, target", "# ---- Part 2: transfer inputs per part"),
]

def region(text: str, start: str, end: str) -> str:
    assert text.count(start) == 1, f"{start!r} isn't there exactly once"
    tail = text[text.index(start):]
    assert end in tail, f"{end!r} doesn't follow {start!r}"
    return tail[:tail.index(end)].replace("\r\n", "\n")

@pytest.mark.parametrize("name,start,end", REGIONS, ids=[r[0] for r in REGIONS])
def test_region_matches(name, start, end):
    a = region(NONJD.read_text(encoding="utf-8"), start, end)
    b = region(JD.read_text(encoding="utf-8"), start, end)
    assert a == b, f"The {name} region differs between the two notebooks: change both"

def test_jd_has_no_non_jd_exclusions():
    text = JD.read_text(encoding="utf-8")
    assert "EXCLUDED_BRANCHES" not in text and "EXCLUDED_FRANCHISES" not in text
```

The JD notebook keeps the `# ---- Part 2: transfer inputs per part` comment as the line after the copied chain, closing the
chain with a comment explaining that Parts 2 and 3 aren't used here.

- [ ] **Step 2: Run** `python -m pytest deploy/test_jd_reorder_in_step.py -q` → FAIL (no notebook).

- [ ] **Step 3: The notebook.** A new `.platform` with `displayName` `Build_Gold_JD_Reorder`, a fresh `logicalId`, and the same `# META` header as the non-JD notebook. Copy these cells verbatim except as stated:

| Part | Change from `Build_Gold_NonJD_Reorder` |
|---|---|
| Header comment | Purpose, grain (Branch + Franchise + PartNumber), sources, Plan S and S-P1 |
| Imports, session settings, `add_months` | Same. `BUILTIN_DEFAULT["Supply"] = 4.0` (S-D3). No `EXCLUDED_*`, `BUILTIN_TRANSFER` or transfer limits |
| Inputs | `scope` below. `order_rules_raw` reads `JD_OrderRules`. No transfer rules, app transfers or purchases frame beyond `intrans_p` |
| Rules validate, Step 1, Settings | **Verbatim** (guarded) |
| Inbound | Same, without the excluded-branch filter (display only) |
| `base` | Without `part_trule`, `app_inbound`, `app_outbound` and the transfer-rule columns; `.withColumn("AppInboundQty", F.lit(0).cast("int"))`, so the calculation text is unchanged |
| Steps 2-3, Steps 3-14 | **Verbatim** (guarded) up to the Part 2 comment; then `BuiltAtUtc` |
| `final` | The `pre` columns without Part 2's, `AppOutboundQty` or `_pend`; plus `LastReceived` (`intrans_p` with franchise D and no branch filter) and `EquipStockValue` |

The scope (S-D7):

```python
parts = spark.sql("""SELECT Branch, Franchise, PartNumber, Description, Bin, VendorCode, DealerGroupCode,
                            SuperTo, SuperFrom, QuantityOnHand, OnOrder, BackOrderQty, Cost, SellPrice1, ListPrice,
                            Current12MoSales, Previous12MoSales, DateLastRequested,
                            PendingQty, SLC, Source, CommodityCode, InventoryCost
                     FROM Silver_PartInformation""")
_d = parts.filter((c("Cost") > 0) & (F.upper(ztrim(c("Franchise"))) == "D"))
_recent = hist.filter(c("MonthStart") >= F.lit(history_start)).select(*KEY).distinct()
_set = spark.sql("SELECT Branch, Franchise, PartNumber FROM NonJD_PartSettings").select(*KEY).distinct()
_keep = (_d.filter((F.coalesce(c("QuantityOnHand"), F.lit(0)) != 0) | (F.coalesce(c("OnOrder"), F.lit(0)) != 0))
         .select(*KEY).union(_d.join(_recent, KEY, "left_semi").select(*KEY))
         .union(_d.join(_set, KEY, "left_semi").select(*KEY)).distinct())
scope = _d.join(_keep, KEY, "left_semi")
```

Writes, with the same habits as the non-JD notebook: `.persist`, a duplicate-key check and `MIN_REORDER_ROWS = 100_000` before
writing; path-based `.save("Tables/Fact_JD_Reorder")` and `.save("Tables/Fact_JD_SalesHistory")` (same shape, the history
following the reorder keys); `VACUUM ... RETAIN 0 HOURS`; invalid rules and settings exit `WARN:` through `_warns`.

- [ ] **Step 4: Run** the guard test → PASS. `python deploy/hygiene_audit.py` → 0 problems.

- [ ] **Step 5: DAG.**

```json
{"name": "Build_Gold_JD_Reorder", "type": "notebook", "workspace": "presentation", "tier": "gold", "cadence": "daily",
 "dependsOn": ["Build_Silver_PartInformation", "Build_Silver_InMaster", "Build_Silver_PartStockingRules",
   "Build_Silver_PartSalesHistory", "Build_Silver_InTrans", "df_NonJD_PartSettings_Raw", "df_JD_OrderRules_Raw",
   "Build_Gold_OutstandingTransfers"],
 "produces": ["Fact_JD_Reorder", "Fact_JD_SalesHistory"], "extraReads": [], "scanIgnore": [], "dynamicReviewed": false}
```

It doesn't depend on `Build_Gold_NonJD_Reorder`, so a failure of either leaves the other alone. Run `dag_check.py`, and fix
what it reports about the literal saves. Regenerate `docs/TABLE-LINEAGE.md` with `deploy/table_lineage.py`. `pytest deploy -q`.

- [ ] **Step 6: Commit** `Plan S task S3: Build_Gold_JD_Reorder and its in-step test`, push, git sync `DP - Presentation - Dev`.

- [ ] **Step 7: Run in Dev (needs S2's table).** If S2 is waiting on Brian, report and stop here; the code is done. Otherwise:
`run_item.py` the notebook, then `python nonjd_reorder_check.py --tier dev --scope jd` → PASS, 0 differences. Run it a second time
and compare the snapshots: only rows with a line in the moved window may differ. Dev `Silver_InTrans` can be stale; if so,
rebuild Dev Silver first and say so.

- [ ] **Step 8: Non-JD unchanged.** `git log -1 --format=%H -- <Build_Gold_NonJD_Reorder path>` is the commit it was at before this plan, and `python nonjd_reorder_check.py --tier dev` still passes. Report row counts, parts per branch (largest), history rows, lines to order and dollars at each branch's Default.

### Task S4: Publish contract 9 (data-projects)

**Files:** `publish/publish_logic.py`, `extract.py`, `build_files.py`, `run_publish.py`, tests, `README.md`.

- [ ] **Step 1: Failing tests.**

```python
# test_publish_logic.py
def test_decide_publish_new_jd_order_data():
    end = datetime(2026, 11, 9, 12, 0)
    state = {"source": "prod", "dataAsOf": pl.iso_utc(end), "jdOrderAsOf": "old"}
    latest = {"status": "Succeeded", "end_utc": end, "run_id": "r"}
    assert pl.decide_publish(latest, state, "prod", jd_end=datetime(2026, 11, 9, 12, 5))[0] is True
    state["jdOrderAsOf"] = pl.iso_utc(datetime(2026, 11, 9, 12, 5))
    assert pl.decide_publish(latest, state, "prod", jd_end=datetime(2026, 11, 9, 12, 5))[0] is False
    assert pl.decide_publish(latest, state, "prod")[0] is False            # no JD build: as before

def test_contract_is_9():
    assert pl.CONTRACT_VERSION == 9

# test_build_files.py
def test_build_jd_order_files(tmp_path):
    rows = [jd_order_row(branch="12", partNumber="B"), jd_order_row(branch="12", partNumber="A")]
    hashes, branches = build_files.build_jd_order(rows, {"12": "Vault"}, AS_OF, out_dir=str(tmp_path))
    assert set(hashes) == {"jdorder_12.json.gz"}                           # branch 12 allowed (S-D5)
    assert branches == [{"branch": "12", "name": "Vault", "parts": 2}]
    doc = read_gz(tmp_path / "jdorder_12.json.gz")
    assert [p["partNumber"] for p in doc["parts"]] == ["A", "B"]
    assert "transferRuleId" not in doc["parts"][0]                          # S-P3

def test_build_jd_order_refuses_a_file_over_the_limit(tmp_path, monkeypatch):
    monkeypatch.setattr(build_files, "JD_FILE_LIMIT", 10)
    with pytest.raises(ValueError, match="upload limit"):
        build_files.build_jd_order([jd_order_row()], {}, AS_OF, out_dir=str(tmp_path))

def test_build_jd_history_files(tmp_path):
    hashes = build_files.build_jd_history(lambda b: [hist_row(b)], ["12"], date(2026, 11, 1), out_dir=str(tmp_path))
    assert set(hashes) == {"jdhistory_12.json.gz"}
    assert len(read_gz(tmp_path / "jdhistory_12.json.gz")["months"]) == 60

def test_meta_has_the_jd_order_fields(tmp_path):
    path = build_files.write_meta(AS_OF, AS_OF, "dev", [], {}, out_dir=str(tmp_path), jd_branches=[], jd_idle_branches=[],
                                  jd_order_branches=[{"branch": "12", "name": "Vault", "parts": 2}], jd_order_as_of="x")
    meta = json.load(open(path))
    assert meta["contractVersion"] == 9 and meta["jdOrderAsOf"] == "x" and meta["jdOrderBranches"][0]["branch"] == "12"

def test_non_jd_files_unchanged_by_the_jd_build(tmp_path):
    # build() on the fixture as before, then build_jd_order and build_jd_history into the same folder:
    # reorder_*, history_*, rules, surplus, transfers keep the same sha256.
    ...
```

Write the last test out fully, with the file's existing `build()` fixture. Update existing `contractVersion == 8` assertions.

- [ ] **Step 2: Run** `python -m pytest -q` in `publish/` → FAIL.

- [ ] **Step 3: Implement.**

`publish_logic.py`: `CONTRACT_VERSION = 9` with its comment line, `JD_ITEM = "Build_Gold_JD_Reorder"`, and:

```python
def decide_publish(latest, state: dict, source: str, force: bool = False, jd_end=None):
    # ...the existing checks, then:
    if state.get("source") == source and state.get("dataAsOf") == iso_utc(latest["end_utc"]):
        if jd_end is not None and state.get("jdOrderAsOf") != iso_utc(jd_end):
            return True, "new JD order data"
        return False, "already published"
    return True, "new data"
```

`extract.py`: `JD_ORDER_COLUMNS` = `REORDER_COLUMNS` without `TransferRuleId` through `SuggestedOutQty`, `AppInboundQty` and `AppOutboundQty`; `jd_order_available(con)`, `jd_order_built_at(con)`, `jd_order(con)`, `stage_jd_history(con)`, `jd_history_for(con, branch)`, `jd_rules(con)`, all from `Fact_JD_Reorder`, `Fact_JD_SalesHistory` and `JD_OrderRules`. `check_columns` is **unchanged**: a missing JD table isn't an error (S-P4).

`build_files.py`:

```python
def build_jd_order(rows, names, data_as_of, out_dir=None):
    """jdorder_<branch>.json.gz (contract v9, Plan S): every branch, no D6 check (S-D5). Same limit as the JD files."""
    return _branch_files(rows, names, data_as_of, out_dir, "jdorder_", _jd_order_part, "JD order")

def _jd_order_part(r: dict) -> dict:
    return _clean(_equip_stock_value(_last_received(_round2(r))))
```

`build_jd_history` writes `jdhistory_<key>.json.gz` as `build()` writes `history_`, with `JD_FILE_LIMIT` checked, and `jd_rules.json.gz` as `rules.json.gz`. `write_meta` gains keyword-only `jd_order_branches` and `jd_order_as_of`, defaulting to `[]` and `None`.

`run_publish.py`, after the existing extracts and builds:

```python
jd_run = pl.latest_item_run(rows, pl.JD_ITEM)
jd_ok = (jd_run is not None and jd_run.get("status") == "Succeeded" and extract.jd_order_available(con)
         and pl.built_in_run(extract.jd_order_built_at(con), pl.run_start(rows, jd_run["run_id"]), jd_run["end_utc"]))
if jd_ok:
    # build the three kinds of JD file; if jd_order_built_at changed while extracting, treat as not ok this time
    ...
else:
    # S-P4: keep what's published. carried = state's jdOrder hashes, branches and asOf.
    print(f"JD order files kept as published ({'no run' if jd_run is None else jd_run.get('status')})")
```

`to_send` comes from this run's hashes only; carried hashes go into the saved state, not into `to_send`, so `--force` never looks for a file this run didn't write. `decide_publish` gets `jd_end=jd_run["end_utc"]` when that run succeeded. Save `jdOrderAsOf`, `jdOrderBranches`, `jdOrderHashes` in the state.

- [ ] **Step 4: Run** tests → PASS. README "File contract": v9, the three files, `jdOrderBranches`, `jdOrderAsOf`, `counts.jdOrderParts`, `counts.jdHistoryRows`, and the deploy note: Gold, then app 0.17.0, then this code on the Gateway PC.

- [ ] **Step 5: Measure, read-only, no upload.** With S3 done, `python run_publish.py --out <scratch>` with the source set to Dev through the shell, as R3 did, using `az` credentials and no `.env` read. Report every `jdorder_*` and `jdhistory_*` total and the largest of each against 4 MB. **If a file is over, stop and ask; don't change the shape.** If S3 hasn't run, estimate from Prod Silver with DuckDB (S-D7's rows per branch, today's bytes per row in `reorder_*`) and mark it an estimate.

- [ ] **Step 6: Commit** `Plan S task S4: publish contract 9 (JD order files)`, push. **Don't pull on the Gateway PC.**

---

## App track (mock only)

Run `npx vitest run <paths>`, `npx tsc --noEmit` and `npx eslint .` for each task. **No `npm run build`.** Every existing test must still pass unchanged, except where a task names the change (version, contract, launch card).

### Task S5: Engine, contract, lists and source

- [ ] **Step 1: Failing tests.**

```ts
// src/engine/__tests__/rules.test.ts
it('JD built-in default: 12 months, 3 demands, 4 weeks', () => {
  expect(JD_BUILTIN_DEFAULT).toMatchObject({ ruleName: 'Built-in default', historyMonths: 12, minDemands: 3, supply: 4,
    supplyUnit: 'Weeks', demandBasis: 'UnitsSold', ruleId: null });
});
it('pickRule falls back to the rule it is given', () => {
  expect(pickRule(PART, [], JD_BUILTIN_DEFAULT).supply).toBe(4);
  expect(pickRule(PART, []).supply).toBe(12);
});

// src/engine/__tests__/calc.test.ts
it('computePart uses the fallback when no rule fits', () => {
  const a = computePart(PART_12_SOLD_A_YEAR_WITH_3_DEMANDS, [], DATE);
  const b = computePart(PART_12_SOLD_A_YEAR_WITH_3_DEMANDS, [], DATE, JD_BUILTIN_DEFAULT);
  expect(a.target).toBeGreaterThan(b.target);
});

// src/data/__tests__/contract.test.ts
it('reads 9; hasJdOrdering needs contract 9 and at least one branch', () => {
  expect(SUPPORTED_CONTRACT_VERSIONS).toContain(9);
  expect(hasJdOrdering({ contractVersion: 8, jdOrderBranches: [B] })).toBe(false);
  expect(hasJdOrdering({ contractVersion: 9, jdOrderBranches: [] })).toBe(false);
  expect(hasJdOrdering({ contractVersion: 9, jdOrderBranches: [B] })).toBe(true);
});

// src/data/__tests__/lists.test.ts (with the file's Graph fake)
it('loadOrders: non-JD by default, JD on request', async () => { /* rows Area '', null, 'JD'; default = first two; { area: 'JD' } = the third */ });
it('createOrder writes Area only when given', async () => { /* no Area field on a non-JD create; Area: 'JD' on a JD one */ });
it('loadOneTimeTemplates: non-JD by default, JD on request', async () => { /* as above */ });
it('loadJdRules reads VITE_LIST_JD_RULES', async () => { /* getConfig().lists.jdRules */ });
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement.**
  - `engine/rules.ts`: `export const JD_BUILTIN_DEFAULT = Object.freeze({ ...BUILTIN_DEFAULT, supply: 4 });`. `pickRule(part, usable, fallback: Readonly<ChosenRule> = BUILTIN_DEFAULT)`. Validation is untouched, and `EXCLUDED_BRANCHES` stays: only the transfer code reads it, and JD has no transfer lines.
  - `engine/calc.ts`: `computePart(part, usable, buildDate, fallback?)`. `engine/parity.ts` and `state/branchRows.ts` (`BranchInputs` and `SharedInputs` gain `fallbackRule?: Readonly<ChosenRule>`, passed to `computePart` in `computeCore` and the parity call).
  - `state/useBranchData.ts`: where `inputs` and `shared` are built, `fallbackRule: src.fallbackRule`.
  - `data/contract.ts`: `SUPPORTED_CONTRACT_VERSIONS` gains 9, `CONTRACT_VERSION = 9`, and `hasJdOrdering(meta)`.
  - `data/types.ts`: `Meta` gains `jdOrderBranches?: MetaBranch[]`, `jdOrderAsOf?: string`. `Order.area: string | null`, `OrderInput.area?: 'JD'`, `OrdersFilter.area?: 'JD'`. `OneTimeTemplate.area?: 'JD' | null`.
  - `data/files.ts`: `loadJdOrder(branch)`, `loadJdHistory(branch)`, `loadJdRulesSnapshot()`, each checking the branch as `loadJd` does.
  - `data/lists.ts`: `ORDER_FIELDS` and `ONE_TIME_TEMPLATE_FIELDS` gain `Area`. `loadOrders` filters in the browser: `filter.area === 'JD' ? o.area === 'JD' : !o.area`. `loadOneTimeTemplates(area?)` likewise. `loadJdRules`, `saveJdRule`, `patchJdRule` share the rule functions through a list-id argument.
  - `data/source.ts`: `DataSource` gains those loaders and `readonly fallbackRule?: Readonly<ChosenRule>`. Both `graphSource` and the mock implement them.
  - `config.ts`: `lists.jdRules` from `VITE_LIST_JD_RULES`, added to the required-for-graph check. **Brian sets it at release** (S11). Mock mode needs nothing.

- [ ] **Step 4: Run** `npx vitest run src/engine src/data src/state` → PASS.

- [ ] **Step 5: Commit** `Plan S task S5: JD fallback rule, contract 9, Area, JD files and rules in the data layer`.

### Task S6: Mock JD data

**Files:** `src/data/mock/jdOrderFixtures.ts` (new), `src/data/mock/index.ts`.

- [ ] **Step 1: Failing test** in `src/data/__tests__/mock.test.ts`:

```ts
it('publishes JD ordering at contract 9, with branch 12', async () => {
  const src = createMockSource();
  const meta = await src.loadMeta();
  expect(meta.contractVersion).toBe(9);
  expect(meta.jdOrderBranches?.map((b) => b.branch)).toEqual(['1', '7', '12']);
  const file = await src.loadJdOrder('1');
  expect(file.parts.map((p) => p.status)).toEqual(expect.arrayContaining(
    ['OutOfStock', 'Reorder', 'OK', 'NotStocked', 'Masked', 'ManualOrder']));
  expect((await src.loadJdRules()).map((r) => r.ruleName)).toEqual(['Default']);
});
it('contract 8 has no JD ordering', async () => {
  const src = createMockSource({ contractVersion: 8 });
  expect(hasJdOrdering(await src.loadMeta())).toBe(false);
});
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement.** `jdOrderFixtures.ts` builds rows named `JD-ORD-*` at branches 1, 7 and 12 by the way `fixtures.ts` does (`usableRules`, `computePart`, here with `JD_BUILTIN_DEFAULT`), one row per status, plus a 60-month history for each. At branch 1 include `JD-ORD-OOS`, `JD-ORD-REO`, `JD-ORD-OK`, `JD-ORD-NS` (fewer than 3 demands), `JD-ORD-MASK`, `JD-ORD-MAN` and a phase-in `JD-ORD-PHASE`. Their settings go in the mock's settings map, franchise D. The JD rule is one Default row. Non-JD fixtures don't change.

- [ ] **Step 4: Run** `npx vitest run src/data` → PASS. Update tests that assert contract 8 as the mock's default, passing `{ contractVersion: 8 }` where the old behaviour is what's tested.

- [ ] **Step 5: Commit** `Plan S task S6: mock JD ordering data`.

### Task S7: `jdSource`, the area and the routes

- [ ] **Step 1: Failing tests.**

```ts
// src/data/__tests__/jdSource.test.ts
const mock = createMockSource();
const src = makeJdSource(() => Promise.resolve(mock));

it('meta: the JD branches and date', async () => {
  const meta = await src.loadMeta();
  expect(meta.branches.map((b) => b.branch)).toEqual(['1', '7', '12']);
  expect(meta.dataAsOf).toBe((await mock.loadMeta()).jdOrderAsOf);
});
it('reorder reads the JD file, with neutral transfer fields', async () => {
  const [p] = (await src.loadReorder('1')).parts;
  expect(p.franchise).toBe('D');
  expect(p).toMatchObject({ transferRuleId: null, allowSend: false, allowReceive: false, freeExcess: 0, convNeed: 0,
    redistEligible: false, suggestedInQty: 0, suggestedOutQty: 0, appInboundQty: 0, appOutboundQty: 0 });
});
it('rules, snapshot and fallback are JD', async () => {
  expect((await src.loadRules()).map((r) => r.ruleName)).toEqual(['Default']);
  expect(src.fallbackRule?.supply).toBe(4);
});
it('no transfers', async () => {
  await expect(src.loadTransferSuggestions()).rejects.toBeInstanceOf(NotFoundError);
  await expect(src.loadTransferRulesSnapshot()).rejects.toBeInstanceOf(NotFoundError);
  expect((await src.loadOpenTransfers()).committed).toEqual([]);
  expect(await src.loadTransferRules()).toEqual([]);
  expect((await src.loadSurplus()).parts).toEqual([]);
});
it('orders and templates carry Area JD and stay apart', async () => {
  const id = await src.createOrder(ORDER_INPUT);
  expect((await src.loadOrders()).map((o) => o.itemId)).toContain(id);
  expect((await mock.loadOrders()).map((o) => o.itemId)).not.toContain(id);
  const t = await src.saveOneTimeTemplate(TEMPLATE_INPUT);
  expect((await mock.loadOneTimeTemplates()).map((x) => x.itemId)).not.toContain(t);
});
it('a method it does not override reaches the base', async () => {
  expect(await src.loadSettings()).toEqual(await mock.loadSettings());
});

// src/ui/__tests__/nav.test.ts
it('JD paths', () => {
  expect(areaFor('/jd/reorder')?.id).toBe('jd');
  expect(navItemFor('/jd/reorder')?.label).toBe('Recommended Reorder');
  expect(trailFor('/jd/reorder')).toEqual([{ label: 'JD ordering', to: '/jd' }, { label: 'Recommended Reorder' }]);
  expect(trailFor('/jd')).toEqual([{ label: 'JD ordering' }]);
  expect(navItemFor('/reorder')?.path).toBe('/reorder');
});

// src/area/__tests__/AreaContext.test.tsx
it('defaults to non-JD with no prefix; the JD provider prefixes paths', () => { /* render useAreaPath()('/orders') → '/orders', then '/jd/orders' */ });
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement.**

`src/data/jdSource.ts`:

```ts
// JD ordering's data (Plan S, S-P2): the DataSource every page already takes, with JD files and lists behind it. Sync
// to create, so a route can pass it as a prop; each method awaits the base. A method not overridden reaches the base.
type Base = () => Promise<DataSource>;

const NEUTRAL_TRANSFER = { transferRuleId: null, transferRuleName: null, excessSupply: 0, excessUnit: 'Months',
  allowSend: false, allowReceive: false, redistMax: 0, redistUnit: 'Months', redistMinValue: 0, excessKeep: 0,
  freeExcess: 0, convNeed: 0, redistCap: 0, redistEligible: false, suggestedInQty: 0, suggestedConvInQty: 0,
  suggestedOutQty: 0, appInboundQty: 0, appOutboundQty: 0 } as const;

export function makeJdSource(base: Base): DataSource {
  const overrides: Partial<DataSource> = {
    fallbackRule: JD_BUILTIN_DEFAULT,
    loadMeta: async () => {
      const m = await (await base()).loadMeta();
      return { ...m, branches: m.jdOrderBranches ?? [], dataAsOf: m.jdOrderAsOf ?? m.dataAsOf };
    },
    loadReorder: async (b) => {
      const f = await (await base()).loadJdOrder(b);
      return { ...f, parts: f.parts.map((p) => ({ ...NEUTRAL_TRANSFER, ...p })) };
    },
    loadHistory: async (b) => (await base()).loadJdHistory(b),
    loadRulesSnapshot: async () => (await base()).loadJdRulesSnapshot(),
    loadRules: async () => (await base()).loadJdRules(),
    saveRule: async (r) => (await base()).saveJdRule(r),
    patchRule: async (id, p) => (await base()).patchJdRule(id, p),
    loadSurplus: async () => ({ dataAsOf: null, parts: [] }),
    loadTransfers: async () => ({ dataAsOf: null, lines: [] }),
    loadTransferRulesSnapshot: async () => { throw new NotFoundError('JD ordering has no transfer rules'); },
    loadTransferSuggestions: async () => { throw new NotFoundError('JD ordering has no transfer suggestions'); },
    loadTransferRules: async () => [],
    loadOpenTransfers: async () => ({ transfers: [], committed: [] }),
    loadOrders: async (f) => (await base()).loadOrders({ ...f, area: 'JD' }),
    createOrder: async (o) => (await base()).createOrder({ ...o, area: 'JD' }),
    loadOneTimeTemplates: async () => (await base()).loadOneTimeTemplates('JD'),
    saveOneTimeTemplate: async (t) => (await base()).saveOneTimeTemplate({ ...t, area: 'JD' }),
  };
  return new Proxy(overrides as DataSource, {
    get(target, name, receiver) {
      if (name in target) return Reflect.get(target, name, receiver);
      return async (...args: unknown[]) => {
        const b = (await base()) as unknown as Record<string | symbol, (...a: unknown[]) => unknown>;
        return b[name](...args);
      };
    },
  });
}

export const jdSource = makeJdSource(getDataSource);
```

Check `NotFoundError`'s constructor, the real neutral field types against `ReorderPart`, and the `dataAsOf` nullability on `SurplusFile` and `TransfersFile` against `types.ts`, and adjust to the types. `then` must read as undefined on the proxy (add it to the guard: `if (name === 'then') return undefined`), or `await jdSource` would hang. Add a test for that.

`src/area/AreaContext.tsx`:

```tsx
export interface AppArea { id: 'non-jd' | 'jd'; prefix: '' | '/jd'; label: string; hasTransfers: boolean;
  fallbackRule: Readonly<ChosenRule>; rulesListName: string }
export const NON_JD_AREA: AppArea = { id: 'non-jd', prefix: '', label: 'Non-JD ordering', hasTransfers: true,
  fallbackRule: BUILTIN_DEFAULT, rulesListName: 'NonJD_OrderRules' };
export const JD_AREA: AppArea = { id: 'jd', prefix: '/jd', label: 'JD ordering', hasTransfers: false,
  fallbackRule: JD_BUILTIN_DEFAULT, rulesListName: 'JD_OrderRules' };
const Ctx = createContext(NON_JD_AREA);
export const AreaProvider = Ctx.Provider;
export const useArea = () => useContext(Ctx);
export function useAreaPath() { const { prefix } = useArea(); return useCallback((p: string) => `${prefix}${p}`, [prefix]); }
```

The default is non-JD, so a page rendered in an existing test behaves exactly as before.

`src/pages/JdLayout.tsx`: loads meta from `jdSource`. Before contract 9 (`!hasJdOrdering`) it shows the card "JD ordering isn't in today's data yet. It arrives with the next publish." Otherwise:

```tsx
<AreaProvider value={JD_AREA}>
  <PartPanelProvider source={jdSource}>
    <Outlet />
  </PartPanelProvider>
</AreaProvider>
```

The nested provider means every `PartLink` under JD opens a panel reading JD data.

`src/App.tsx`, under `AppShell`'s children, with existing routes unchanged:

```tsx
{
  path: 'jd', element: <JdLayout />,
  children: [
    { index: true, element: <HomePage source={jdSource} /> },
    { path: 'reorder', element: <ReorderPage source={jdSource} /> },
    { path: 'one-time', element: <OneTimeOrderPage source={jdSource} /> },
    { path: 'templates', element: <TemplatesPage source={jdSource} /> },
    { path: 'orders', element: <OrdersPage source={jdSource} /> },
    { path: 'orders/:orderId', element: <OrderPage source={jdSource} /> },
    { path: 'rules', element: <RulesPage source={jdSource} /> },
    { path: 'special', element: <SpecialStatusesPage source={jdSource} /> },
    { path: 'part/:branch/:franchise/:partNumber', element: <PartPage source={jdSource} /> },
  ],
},
```

`src/ui/areas.ts`, the JD entry:

```ts
{ id: 'jd', label: 'JD ordering', description: 'Recommended Reorder and One-Time orders for JD parts, beside Prism.',
  icon: 'package', status: 'live', home: '/jd',
  screens: [
    { path: '/jd', label: 'Home', icon: 'home' },
    { path: '/jd/reorder', label: 'Recommended Reorder', icon: 'reorder' },
    { path: '/jd/one-time', label: 'One-Time Order', icon: 'onetime' },
    { path: '/jd/templates', label: 'Templates', icon: 'copy' },
    { path: '/jd/orders', label: 'Orders', icon: 'orders' },
    { path: '/jd/rules', label: 'Rules', icon: 'rules' },
    { path: '/jd/special', label: 'Special statuses', icon: 'flag' },
  ] },
```

`areaFor` already matches `/jd/...`, on its first segment. `src/ui/nav.ts`: `navItemFor` tries the first two segments when the first is `jd`. `trailFor`: a `/jd/part/...` page sits under JD ordering, and `/jd/orders/12` under JD ordering › Orders. The rail's active item comes from `navItemFor`; confirm in `NavRail.tsx`.

- [ ] **Step 4: Run** `npx vitest run src/data src/ui src/area src/__tests__`, tsc, lint → PASS. Note that `AREAS`-based tests naming JD as coming later change now.

- [ ] **Step 5: Commit** `Plan S task S7: jdSource, the area context and the /jd routes`.

### Task S8: Reorder, Home and the paths

**Files:** `pages/orders/paths.ts`, `pages/home/attention.ts`, `pages/part/search` (`partPath`), `pages/part/PartLink.tsx`, `pages/HomePage.tsx`, `pages/ReorderPage.tsx`, `pages/reorder/*`.

- [ ] **Step 1: Failing tests,** `src/pages/__tests__/jdReorderPage.test.tsx`: render inside `AreaProvider value={JD_AREA}` with `source={makeJdSource(mock)}`.

```ts
it('lists JD parts at any branch, 12 included', async () => { /* branch picker offers 1, 7, 12; JD-ORD-REO shows with status Reorder */ });
it('has no transfer UI', async () => {
  // no Stepper, no "Transfer suggested only", no transfer banner or pill; the page opens on the order step
});
it('a saved order goes to JD Orders', async () => {
  // tick JD-ORD-REO, Create order; the location is /jd/orders/<id>; the order has area 'JD'
});
it('part numbers link under /jd and open the JD panel', async () => { /* href /jd/part/1/D/JD-ORD-REO */ });
it('parity banner compares against the JD snapshot', async () => { /* no "differs" banner on the mock */ });
it('home: JD counts, no Transfers card, links under /jd', async () => { /* HomePage inside the provider */ });
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement.** Paths are helpers, so callers prefix them:
  - Each page reads `const ap = useAreaPath()` and wraps every in-app path it builds: `ap(ordersPath(...))`, `ap(orderPath(id))`, `ap('/reorder')`. Find them with a search for `'/reorder'`, `'/one-time'`, `'/orders'`, `'/rules'`, `'/templates'`, `'/special'`, `'/part/'`, `partPath(`, `orderPath(`, `ordersPath(`, and the `attention.ts` functions (which gain a `prefix` argument defaulting to `''`). Transfer paths aren't prefixed; they're hidden.
  - `PartLink`: `ap(partPath(...))` for its `href`.
  - `ReorderPage`: `const { hasTransfers } = useArea()`. With it false: no `Stepper`, `step` is always `'order'`, no "Transfer suggested only", no transfer banner or pills, and `useReorderTransfers` is `active: false`. The suggestion files read as not found, so most of this already reads as empty; the flag removes the controls.
  - `HomePage`: no transfer cards with `hasTransfers` false; the Part Lookup card stays, pointing at `/lookup`.

- [ ] **Step 4: Run** `npx vitest run src/pages src/__tests__`, tsc, lint → PASS. Non-JD tests pass unchanged.

- [ ] **Step 5: Commit** `Plan S task S8: JD Recommended Reorder and Home`.

### Task S9: One-Time, Templates, Orders, Rules, Special statuses, part page

- [ ] **Step 1: Failing tests,** `src/pages/__tests__/jdOtherPages.test.tsx`:

```ts
it('One-Time: JD branches, no transfers step, an order lands in JD Orders', async () => {});
it('Templates: a saved JD template is not on the non-JD page, and the reverse', async () => {});
it('Orders: JD lists only JD orders; non-JD only its own; export is the same CSV', async () => {});
it('Rules: reads and saves the JD list; a saved rule does not touch NonJD_OrderRules', async () => {});
it('Rules: the built-in row shows 4 weeks, and New rule starts at the JD default', async () => {});
it('Rules: Try it recomputes with the JD fallback', async () => {});
it('Rules: a rule on branch 12 is accepted', async () => {});
it('Special statuses: JD shows only franchise D; non-JD leaves franchise D out', async () => {});
it('Part page and panel: a JD part with its JD history; Settings saves to the shared list with franchise D', async () => {});
```

Write these out against the mock, following `archiveOrders.test.tsx` and the existing page tests.

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement.**
  - `OneTimeOrderPage`: with `hasTransfers` false, drop the transfers step from its steps list and the transfer-related controls; `ap()` on its paths. `useOneTimeBranches` already takes `source`.
  - `TemplatesPage`, `TemplateCard`, `useOneTimeTemplate`: `ap()` on paths, using the `source` they're given.
  - `OrdersPage`, `OrderPage`: `ap()`. The "back to orders" links stay in the area.
  - `RulesPage`: the built-in row reads `useArea().fallbackRule` instead of `BUILTIN_DEFAULT`, and the description names `area.rulesListName`. `pages/rules/ruleForm.ts`: the new-rule default takes the fallback as an argument, defaulting to `BUILTIN_DEFAULT`. Remove nothing about excluded branches on the non-JD page; the JD page shows no such note.
  - `SpecialStatusesPage`: before `specialRows`, keep only settings of this area (S-P5):

```ts
const isD = (s: PartSetting) => ztrim(s.franchise ?? '').toUpperCase() === 'D';
const mine = [...settings.values()].filter((s) => (area.id === 'jd' ? isD(s) : !isD(s)));
```

  - `PartPage`, `PartDetailsPanel`, `usePartRow`: use the `source` given. `OtherBranches` reads JD branches through it. Its transfer mentions hide with `hasTransfers` false.

- [ ] **Step 4: Run** the whole suite, in two halves if needed, then tsc and lint → PASS.

- [ ] **Step 5: Commit** `Plan S task S9: JD One-Time, Templates, Orders, Rules, Special statuses, part page`.

### Task S10: Launch card, 0.17.0, click-through, try-it

- [ ] **Step 1: Failing tests.** In `launchPage.test`:

```ts
it('JD card: live with counts on contract 9', async () => { /* a link to /jd, "N parts to order · $X" */ });
it('JD card: "Coming later" on contract 8', async () => { /* createMockSource({ contractVersion: 8 }) */ });
it('Non-JD card figures are unchanged', async () => {});
```

`src/__tests__/clickThrough0170.test.tsx` (setup as `clickThrough0160`; move the version test here): launch → JD ordering card → Home → Recommended Reorder at branch 12 → tick two parts → Create order → it's on JD Orders → Export CSV → back on Non-JD Orders it isn't there; JD Rules → change Default's supply → Try it moves the numbers; One-Time at branch 7 → an order; a part number opens the panel with JD history and keeps the ticks.

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement.** `LaunchPage`: a second `useBranchData(branch, { source: jdSource, enabled: meta != null && hasJdOrdering(meta), reauthenticate, now })`; `launchCounts` over its `computed`, with `suggestionLines` null. A failure hides the JD count only. Before contract 9 the JD card renders as today's "Coming later". `package.json` and lock `0.17.0`.

- [ ] **Step 4: Run** the full suite, `npx tsc --noEmit`, `npx eslint .` → PASS, and report the real counts.

- [ ] **Step 5: Look at it** on `npm run dev` (mock): launch page, JD Reorder, Rules, a part panel. Stop the dev server afterwards. If it can't be seen or stopped, say so.

- [ ] **Step 6: Try-it notes.** `projects/part order tool - app/for-users/0.17.0-try-it.md` (0.16.0's style; exact clicks, expected parts and numbers, what's left out: Transfers, spiking, EOQ, the Prism check; "non-JD is unchanged"; and the Dev check results if S3 ran).

- [ ] **Step 7: Commit** both repos: `Plan S task S10: launch card and 0.17.0`, `Plan S task S10: 0.17.0 try-it notes`.

---

## With Brian

### Task S11: Release (Brian, Monday or later, after the try-it)

Claude gives exact commands and checks each step. Nothing here runs unattended.

- [ ] **1. Fabric PR** `dev → main` (`python deploy/merge_preview.py`, the template). Brian merges with a merge commit, runs **Deploy DP backend**, then `python deploy/claim_prod_pipeline.py`. Claude fast-forwards dev.
- [ ] **2. Prod data.** Brian runs Pipeline_DP_Refresh with `mode=items`, `items=df_JD_OrderRules_Raw`; then `sync_shortcuts.py --apply`; then `mode=items`, `items=Build_Gold_JD_Reorder`. `nonjd_reorder_check.py --tier prod --scope jd` → PASS, and `--tier prod` (non-JD) → PASS and unchanged.
- [ ] **3. App.** Brian adds `VITE_LIST_JD_RULES=22e28c35-2a57-4c71-a807-abd9f22d1409` to the build's env file (`22e28c35-2a57-4c71-a807-abd9f22d1409`; Claude doesn't open the file). `npm run build`, dist checks, upload to Fedora staging; Brian installs 0.17.0. The JD card says "Coming later" until step 4, and every other area works as before.
- [ ] **4. Publish.** Brian pulls the contract 9 code on the Gateway PC and runs `run_publish.py --force`. Claude checks `contractVersion: 9`, `jdOrderBranches` (branch 12 included) and the file sizes.
- [ ] **5. Real test.** One branch: Recommended Reorder and One-Time lists, a saved order and its CSV compared with the reference, a TEST rule on `JD_OrderRules`, a TEST template and a JD setting. Claude removes the TEST rows afterwards and says what was removed.
- [ ] **6. Non-JD check.** Brian's normal branch: the Non-JD card, Orders and Special statuses are as they were.
- [ ] **7. Barry or Curt** hold lists up against Prism. Differences go to F12's follow-ups and FUTURE-IDEAS; they won't match exactly.

### Task S12: Docs

- [ ] Guide and walkthrough (regenerate both `.docx`), a new `JD-ORDERING.md` beside `REORDER-RULES.md`, the publish README's contract section, `fabric-workspace-docs/docs/TABLE-LINEAGE.md`, `TROUBLESHOOTING.md` for anything learned, FUTURE-IDEAS (JD ordering phase 1 done; next F12 tags, then Transfers), the plan's and spec's status blocks, memory.

---

## Spec coverage

| Spec | Task |
|---|---|
| S-D1 no Prism connection; ends as an export | S8, S9 (the same export) |
| S-D2 screens | S7 to S9 |
| S-D3 Default rule, fallback | Done (row), S3 (Gold), S5 (app) |
| S-D4 separate build; non-JD can't move | S3 (Step 8, guard), S4 (byte test, S-P4) |
| S-D5 every branch | S1, S3, S4, tests naming branch 12 |
| S-D6 own rules list | Done (list), S2 (shortcut), S5, S9 |
| S-D7 records | S1, S3 |
| Contract 9 files, 4 MB | S4 |
| Area column | S5, S7, S9 |
| Launch card, before contract 9 | S7, S10 |
| Reference, parity banner, twice-run | S1, S3, S8 |
| Try-it, release, Barry and Curt | S10, S11 |
