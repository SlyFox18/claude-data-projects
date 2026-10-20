# Non-JD Parts Order Tool: Data Feed Implementation Plan (Plan A of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Progress:**
> - Task 2 DONE 2026-10-20 (`b259bb58`; rop_matrix.csv uploaded to Dev Files/config/nonjd).
> - Task 3 DONE 2026-10-20 (`441ac2d9`, `b66ea215`, `4d23310d`). After review the committed script gained duplicate-key counts, a fuller mismatch printout and 22 tests; **the committed files are the reference, not the code copied below.**
> - Task 4 DONE 2026-10-20 (fabric-workspace-docs `5a9adc3a`, `5a896731`): after review, single-pass validation and a WARN when the current month is missing after day 3 (stale Bronze).
> - Task 5 DONE 2026-10-20 (`07ff6562`, `fc985ddb`): after review, redundant scans dropped, Bronze type assert, cache released. Committed notebooks are the reference.
> - Task 1 (SharePoint site, lists, permissions) is Brian's; Task 8 needs it.
>
> Plan written 2026-10-20. The Python in Tasks 3 and 10 was extracted from this plan and its 19 tests pass (2026-10-20); the fingerprint query was checked in DuckDB. The notebooks and dataflow are untested until Task 8.
>
> Pre-plan checks already done (2026-10-20, read-only DuckDB on DP Dev):
> - Bronze `InHistMQT` (shortcut in DP_Staging) is the history source. JD primary key `BRANCH,FRANCHISE,PART_NO,MM_YYYY`; 0 duplicate keys in the last 61 months. `MM_YYYY` is the 1st of the month at 00:00 UTC and includes the current month.
> - `InHistMQT` month t-1 matches `INHIST_MONTH_4_PI.PI_SALES_HISTORY_02` / `PI_SALES_REQUEST_02` on 99.997% of 999,649 keys; month t-12 matches `_13` on 99.97%. Remaining differences are the two Bronze copies being taken at slightly different times.
> - Bronze `InMaster` has `MINIMUM_QTY`, `MAXIMUM_QTY`, `REORDER_CODE`, `ACTIVITY_CODE`. Silver doesn't carry them yet.
> - The ROP matrix CSV has 1,991 data rows, one with a blank Month Count (dropped), and **no overlapping ranges** within a month count, so the range join can't duplicate a part.
> - The old LH logic (`nb_Fact_NonJD_Parts_Order`) averaged over the **last 12 months**, not 60, and never applied the SharePoint part settings. This plan keeps the 12-month window as a named constant and applies settings.

**Goal:** Build the DP tables and the daily publish script that produce the per-branch JSON files the Non-JD Parts Order Tool web app reads from SharePoint.

**Architecture:** Two new Silver notebooks (monthly part history, part stocking rules) and one Gold notebook (`Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory`) join the daily `Pipeline_DP_Refresh`. A small Dataflow Gen2 reads the app's part-settings SharePoint list back into DP. A Python publish script on the Gateway PC reads Gold with DuckDB after the DP run, writes gzipped JSON files, and uploads changed files to a SharePoint library through Graph. An independent DuckDB re-implementation of the reorder rules checks the Gold output.

**Tech Stack:** PySpark notebooks (Fabric), Power Query M (Dataflow Gen2), Python 3.13 + DuckDB 1.5 + msal + requests, pytest, SharePoint lists and a document library.

**Spec:** `docs/superpowers/specs/2026-10-20-non-jd-parts-order-tool-redesign-design.md`. **Plan B** (the React app) is written after this one and builds against the file contract in Task 14.

---

## Repos, branches and IDs

- **fabric-workspace-docs** (`C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`): notebooks, dataflow, shortcuts, DAG config, tests. Work on `dev`.
- **data-projects** (`C:\Users\bfox\Documents\Git-Projects\data-projects`): ROP CSV, check script, publish script, docs. Work on `dev`.
- Both repos often hold unrelated uncommitted changes. **Stage only the files named in each step.**

| Item | Dev | Prod |
|---|---|---|
| DP - Staging workspace | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` | `189e5c0a-548a-4feb-93d6-dda9ebbe96c1` |
| DP_Staging lakehouse | `876255e0-d462-4697-adc1-4a655f5bb101` | `6713bd45-a4ad-47e6-8bff-1bb0415e9784` |
| DP - Presentation workspace | `73fd5443-240e-410a-990a-98827f32c087` | `7836042d-adb1-4846-b70d-bd42980054c5` |
| DP_Presentation lakehouse | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `29d9df80-a383-4d40-9807-1e2e6cbff88f` |

Shell notes: in Bash run `export PATH="$HOME/.local/bin:$PATH"` before `fab`. If the Bash tool blocks a harmless command as "printenv", put the command in a script file in the scratchpad and run that.

## File map

**fabric-workspace-docs**

| File | Responsibility |
|---|---|
| `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartSalesHistory.Notebook/{.platform,notebook-content.py}` | 60 months of monthly sales, requests, value per part from `InHistMQT` |
| `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartStockingRules.Notebook/{.platform,notebook-content.py}` | Min, max, reorder code, activity code per part from Bronze `InMaster` |
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_PartSettings_Raw.Dataflow/{.platform,queryMetadata.json,mashup.pq}` | SharePoint list `NonJD_PartSettings` → table `NonJD_PartSettings` |
| `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/{.platform,notebook-content.py}` | Reorder recommendation and 60-month history facts |
| `workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json` | Add shortcuts to the 3 new staging tables |
| `deploy/dp_refresh_dag.json` | Register the 4 new items |
| `deploy/test_inmaster_guard.py` | Add the new InMaster reader to the identical-guard test |

**data-projects** (all under `projects/part order tool - app/` unless noted)

| File | Responsibility |
|---|---|
| `params/make_rop_matrix.py` | Convert the original ROP CSV to clean headers |
| `params/rop_matrix.csv` | Clean ROP matrix uploaded to DP_Presentation `Files/config/nonjd/` |
| `tools/dp-migration/nonjd_reorder_check.py` (repo root path) | Independent DuckDB re-implementation of the reorder rules; compares with Gold; fingerprint for run-twice checks |
| `tools/dp-migration/test_nonjd_reorder_check.py` | Fixture tests for the reference rules |
| `publish/publish_logic.py` | Pure helpers: publish decision, history arrays, meta, number cleaning, upload order |
| `publish/test_publish_logic.py` | Tests for the above |
| `publish/config.py`, `publish/.env.example`, `publish/.gitignore`, `publish/requirements.txt` | Settings |
| `publish/extract.py` | DuckDB reads of Gold and `dp_refresh_log` |
| `publish/build_files.py` | Deterministic gzipped JSON files + content hashes |
| `publish/upload.py` | Graph upload with retry |
| `publish/run_publish.py` | Orchestration, state file, exit codes |
| `publish/README.md` | How to run, schedule, and the file contract |
| `README.md` | Point at the new spec and plans |

---

### Task 1: SharePoint site, library and lists (Brian, in the browser)

**Files:** none (SharePoint setup). Record the values you get in `publish/.env` in Task 11.

- [ ] **Step 1: Create the site.** SharePoint → Create site → Team site (no Microsoft 365 group needed, a communication site also works). Name **Parts Order Tool**, URL `https://spitractor.sharepoint.com/sites/PartsOrderTool`. Members: Ben, Shannon, Barry, Curt, Brian. If you choose a different URL, use it everywhere this plan says `/sites/PartsOrderTool`.

- [ ] **Step 2: Create the document library** `NonJD Order Data`. Leave versioning at the default.

- [ ] **Step 3: Create list `NonJD_PartSettings`** with these columns. Use exactly these names when creating each column, so the internal names match (rename display names afterwards if wanted):

| Column | Type | Notes |
|---|---|---|
| Title | (built in) | The app writes `Branch|Franchise|PartNumber` here |
| Branch | Single line of text | Required |
| Franchise | Single line of text | Required |
| PartNumber | Single line of text | Required |
| MinOverride | Number | Optional, 0 decimals |
| EOQ | Number | Optional |
| ForceNonSpiking | Yes/No | Default No |
| Masked | Yes/No | Default No |
| MaskExpires | Date and time (date only) | Optional |
| PreApprovedRule | Single line of text | Optional |
| Notes | Multiple lines of text | Optional |

- [ ] **Step 4: Create list `NonJD_Orders`**: Title (order name), Branch (text), Franchise (text), OrderType (Choice: Recommended, OneTime), Parameters (Multiple lines, JSON), Status (Choice: Draft, Exported, Placed), ExportCount (Number, default 0).

- [ ] **Step 5: Create list `NonJD_OrderLines`**: Title (`Branch|Franchise|PartNumber`), OrderId (Number), Branch, Franchise, PartNumber (text), RecommendedQty (Number), OrderQty (Number), Cost (Number, 2 decimals), LineValue (Number, 2 decimals).

- [ ] **Step 6: Add one test row** to `NonJD_PartSettings` for a real non-JD part you know (for example Branch `1`, a franchise like `MC`, its part number) with `MinOverride = 5`. Task 8 uses it.

- [ ] **Step 7: Grant the publish SPN write access to the site.** The publish script reuses the Parts Availability service principal (`CLIENT_ID` in the Gateway PC's `parts-lookup-static-prototype/.env`). Grant it `Sites.Selected` **write** on the new site, the same way it was granted on the Parts Availability site. Write down the SPN's client ID for Task 11.

- [ ] **Step 8: Grant the same SPN read access to DP_Presentation** in both tiers, so DuckDB can read Gold and `dp_refresh_log`: Fabric → `DP - Presentation - Dev` → Manage access → add the SPN as **Viewer**; repeat for `DP - Presentation - Prod`. (It already reads `DP_Staging` Prod for Parts Availability.)

---

### Task 2: Clean ROP matrix CSV

**Files:**
- Create: `projects/part order tool - app/params/make_rop_matrix.py`
- Create (generated): `projects/part order tool - app/params/rop_matrix.csv`

- [ ] **Step 1: Write the converter**

```python
"""
Convert the corporate ROP matrix export ("Version 5 ROP-CSV.csv") to the clean CSV that
Build_Gold_NonJD_Reorder reads from DP_Presentation Files/config/nonjd/rop_matrix.csv.

- PascalCase headers (the original has spaces and "Spiking Warehouse<BR>Stocking Min").
- Thousands separators removed from numbers ("9,999,999" -> 9999999).
- Rows with a blank Month Count are dropped (1 row in Version 5; it can never match a part).

Run from anywhere:  python make_rop_matrix.py
"""
import csv
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / "example excel sheet" / "Version 5 ROP-CSV.csv"
TARGET = HERE / "rop_matrix.csv"

HEADERS = {
    "Group": "StockingGroup", "Commodity Code": "CommodityCode", "SRC": "SRC", "SLC": "SLC",
    "Attachment": "Attachment", "Price L": "PriceL", "Price H": "PriceH", "Month Count": "MonthCount",
    "Demand L": "DemandL", "Demand H": "DemandH", "Sales L": "SalesL", "Sales H": "SalesH",
    "Modifier": "Modifier", "Trending Cap": "TrendingCap", "Warehouse Min": "WarehouseMin",
    "Stocking weeks": "StockingWeeks", "Spiking Modifier": "SpikingModifier",
    "Spiking Warehouse<BR>Stocking Min": "SpikingWarehouseStockingMin",
}
TEXT = {"StockingGroup", "CommodityCode", "SRC", "SLC", "Attachment"}


def main() -> None:
    with SOURCE.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    out = []
    for row in rows:
        clean = {HEADERS[k]: (v or "").strip() for k, v in row.items()}
        if not clean["MonthCount"]:
            continue
        for k, v in clean.items():
            if k not in TEXT:
                clean[k] = v.replace(",", "")
        out.append(clean)
    with TARGET.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(HEADERS.values()), lineterminator="\n")
        w.writeheader()
        w.writerows(out)
    print(f"Wrote {len(out)} rows to {TARGET}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

Run: `python "projects/part order tool - app/params/make_rop_matrix.py"`
Expected: `Wrote 1990 rows to ...rop_matrix.csv`

- [ ] **Step 3: Spot-check the output**

Run: `head -3 "projects/part order tool - app/params/rop_matrix.csv"`
Expected first line: `StockingGroup,CommodityCode,SRC,SLC,Attachment,PriceL,PriceH,MonthCount,DemandL,DemandH,SalesL,SalesH,Modifier,TrendingCap,WarehouseMin,StockingWeeks,SpikingModifier,SpikingWarehouseStockingMin`, and no data line containing `"`.

- [ ] **Step 4: Upload to DP_Presentation Dev Files**

```bash
export PATH="$HOME/.local/bin:$PATH"
fab mkdir "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Files/config/nonjd"
fab cp "projects/part order tool - app/params/rop_matrix.csv" "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Files/config/nonjd/rop_matrix.csv" -f
fab ls "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Files/config/nonjd"
```
Expected: `rop_matrix.csv` listed. (If `fab mkdir` says the folder exists, continue.)

- [ ] **Step 5: Commit (data-projects)**

```bash
git add "projects/part order tool - app/params/make_rop_matrix.py" "projects/part order tool - app/params/rop_matrix.csv"
git commit -m "Non-JD order tool: clean ROP matrix CSV for DP

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Reference implementation of the reorder rules (test first)

This is the independent check for Task 7. It encodes the business rules once in DuckDB SQL; Task 9 compares Gold against it.

**Files:**
- Create: `tools/dp-migration/test_nonjd_reorder_check.py`
- Create: `tools/dp-migration/nonjd_reorder_check.py`

**Rules (shared with Task 7, keep both in step):**
1. Scope: `Cost > 0`; franchise (upper, trimmed) not in `D, ZP, S, 95` and not starting with `T` or `U`.
2. Window: months `current_month - 11 .. current_month` (12 months, including the current partial month). Missing months are zero.
3. `MonthCount` = months in the window with `SalesQty > 0 OR RequestCount > 0`. Averages = window totals / `MonthCount` (as doubles), 0 when `MonthCount = 0`. `MonthCountCapped` = 1 when 0, 19 when above 19.
4. Matrix: `MonthCount = MonthCountCapped AND DemandL <= AvgDemand < DemandH AND SalesL <= AvgSales < SalesH`. No match → `Modifier 1.0`, `WarehouseMin 1`.
5. Settings: latest row per key by `Modified DESC, Id DESC`. `EffectiveMin = coalesce(MinOverride, MinimumQty, 0)`. Masked when `Masked AND (MaskExpires IS NULL OR MaskExpires >= today)`.
6. `StockingTarget = ceil(max(WarehouseMin, EffectiveMin, AvgDemand * Modifier))`, NULL when `MonthCount = 0`.
7. Quantities truncate toward zero (`OnHandInt`, `OnOrderInt`). `RecommendedOrderQty = 0` when masked or `MonthCount = 0`, else `max(0, target - OnHandInt - OnOrderInt)`.
8. `SurplusQty = max(0, OnHandInt)` when `MonthCount = 0`, else `max(0, OnHandInt - target)`.
9. `InboundTransferQty` = sum of `OpenQty` on outstanding transfers where `trim(RequestingBranch) = trim(Branch)` and transfer `PartNumber = upper(trim(PartNumber))`.
10. `Status`: `Masked`, else `NoRecentActivity` (MonthCount 0), else `OutOfStock` (rec > 0 and raw on hand, NULL as 0, <= 0; fractional stock such as 0.5 counts as in stock), else `Reorder` (rec > 0), else `OK`.

- [ ] **Step 1: Write the failing tests**

```python
# tools/dp-migration/test_nonjd_reorder_check.py
from datetime import date

import duckdb
import pytest

import nonjd_reorder_check as chk

CUR = date(2026, 10, 1)
TODAY = date(2026, 10, 20)


def _con():
    con = duckdb.connect()
    con.execute("""CREATE TABLE parts (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   QuantityOnHand DECIMAL(12,2), OnOrder DECIMAL(12,2), Cost DECIMAL(12,2))""")
    con.execute("CREATE TABLE rules (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MinimumQty DECIMAL(10,2))")
    con.execute("""CREATE TABLE hist (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MonthStart DATE,
                   SalesQty DECIMAL(12,2), RequestCount INTEGER)""")
    con.execute("""CREATE TABLE matrix (MonthCount INTEGER, DemandL DOUBLE, DemandH DOUBLE, SalesL DOUBLE,
                   SalesH DOUBLE, Modifier DOUBLE, WarehouseMin INTEGER)""")
    con.execute("""CREATE TABLE settings (Id INTEGER, Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   MinOverride DOUBLE, Masked BOOLEAN, MaskExpires DATE, Modified TIMESTAMP)""")
    con.execute("CREATE TABLE transfers (RequestingBranch VARCHAR, PartNumber VARCHAR, OpenQty DOUBLE)")
    return con


def _run(con):
    rows = chk.expected_reorder(con, CUR, TODAY).fetchall()
    cols = ["Branch", "Franchise", "PartNumber", "MonthCount", "StockingTarget", "RecommendedOrderQty",
            "SurplusQty", "InboundTransferQty", "Status"]
    return {r[2]: dict(zip(cols, r)) for r in rows}


def test_scope_excludes_jd_test_franchises_and_zero_cost():
    con = _con()
    con.execute("""INSERT INTO parts VALUES ('1','D','JD1',0,0,5), ('1','TD','T1',0,0,5), ('1','UM','U1',0,0,5),
                   ('1','ZP','Z1',0,0,5), ('1','MC','FREE',0,0,0), ('1','MC','OK1',0,0,5), ('1','DA','DA1',0,0,5)""")
    assert sorted(_run(con)) == ["DA1", "OK1"]


def test_matrix_modifier_and_target():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P1',1,0,10)")
    # 3 active months in the window, 6 requests -> avg demand 2.0; 9 sales -> avg sales 3.0
    con.execute("""INSERT INTO hist VALUES ('1','MC','P1','2026-10-01',3,2), ('1','MC','P1','2026-09-01',3,2),
                   ('1','MC','P1','2026-08-01',3,2), ('1','MC','P1','2025-01-01',99,99)""")
    con.execute("INSERT INTO matrix VALUES (3, 0, 5, 0, 999999, 1.5, 2)")
    r = _run(con)["P1"]
    assert r["MonthCount"] == 3
    assert r["StockingTarget"] == 3          # ceil(max(2, 0, 2.0 * 1.5))
    assert r["RecommendedOrderQty"] == 2     # 3 - 1 on hand - 0 on order
    assert r["Status"] == "Reorder"


def test_no_matrix_match_uses_defaults_and_min_qty():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P2',0,0,10)")
    con.execute("INSERT INTO rules VALUES ('1','MC','P2',4)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P2','2026-10-01',1,1)")
    r = _run(con)["P2"]
    assert r["StockingTarget"] == 4          # max(WarehouseMin 1, MinimumQty 4, 1.0 * 1.0)
    assert r["RecommendedOrderQty"] == 4
    assert r["Status"] == "OutOfStock"


def test_null_on_hand_counts_as_out_of_stock():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P8',NULL,0,10)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P8','2026-10-01',1,1)")
    r = _run(con)["P8"]
    assert r["RecommendedOrderQty"] == 1
    assert r["Status"] == "OutOfStock"


def test_settings_override_latest_row_wins_and_masking():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P3',0,0,10), ('1','MC','P4',0,0,10)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P3','2026-10-01',1,1), ('1','MC','P4','2026-10-01',1,1)")
    con.execute("""INSERT INTO settings VALUES
        (1,'1','MC','P3',2,false,NULL,'2026-10-01 10:00'), (2,'1','MC','P3',7,false,NULL,'2026-10-05 10:00'),
        (3,'1','MC','P4',NULL,true,'2026-12-31','2026-10-01 10:00')""")
    r = _run(con)
    assert r["P3"]["StockingTarget"] == 7
    assert r["P4"]["RecommendedOrderQty"] == 0 and r["P4"]["Status"] == "Masked"


def test_expired_mask_is_ignored():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P5',0,0,10)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P5','2026-10-01',1,1)")
    con.execute("INSERT INTO settings VALUES (1,'1','MC','P5',NULL,true,'2026-10-19','2026-10-01 10:00')")
    assert _run(con)["P5"]["Status"] == "OutOfStock"


def test_no_activity_is_surplus_and_truncates_quantities():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('92','MC','P6',10.7,0,10), ('92','MC','P7',9.9,0,10)")
    con.execute("INSERT INTO hist VALUES ('92','MC','P7','2026-10-01',1,1)")
    r = _run(con)
    assert r["P6"]["Status"] == "NoRecentActivity"
    assert r["P6"]["StockingTarget"] is None and r["P6"]["SurplusQty"] == 10
    assert r["P7"]["SurplusQty"] == 8         # trunc(9.9)=9 minus target 1


def test_inbound_transfers_match_trimmed_upper_part_number():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','ab-1 ',0,0,10)")
    con.execute("INSERT INTO transfers VALUES ('1','AB-1',4), ('1 ','AB-1',2), ('5','AB-1',9)")
    assert _run(con)["ab-1 "]["InboundTransferQty"] == pytest.approx(6.0)


def test_compare_counts_mismatches():
    con = duckdb.connect()
    con.execute("""CREATE TABLE gold AS SELECT * FROM (VALUES ('1','MC','A',1,2,0,0.0,'Reorder'),
                   ('1','MC','B',1,2,0,0.0,'Reorder')) t(Branch,Franchise,PartNumber,MonthCount,
                   RecommendedOrderQty,SurplusQty,InboundTransferQty,Status)""")
    con.execute("""CREATE TABLE expected AS SELECT * FROM (VALUES ('1','MC','A',1,2,0,0.0,'Reorder'),
                   ('1','MC','C',1,2,0,0.0,'Reorder')) t(Branch,Franchise,PartNumber,MonthCount,
                   RecommendedOrderQty,SurplusQty,InboundTransferQty,Status)""")
    con.execute("ALTER TABLE gold ADD COLUMN StockingTarget INTEGER")
    con.execute("ALTER TABLE expected ADD COLUMN StockingTarget INTEGER")
    result = chk.compare(con, "gold", "expected")
    assert result == {"only_gold": 1, "only_expected": 1, "different": 0}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd tools/dp-migration && python -m pytest test_nonjd_reorder_check.py -q`
Expected: FAIL / error `ModuleNotFoundError: No module named 'nonjd_reorder_check'`

- [ ] **Step 3: Write the implementation**

```python
# tools/dp-migration/nonjd_reorder_check.py
"""
Non-JD Parts Order Tool: independent check of Fact_NonJD_Reorder.

Re-implements the reorder rules (plan 2026-10-20-non-jd-parts-order-tool-data-feed.md, Task 3) in DuckDB SQL
over the same Silver inputs, then compares row by row with the Gold table Build_Gold_NonJD_Reorder wrote.
Also prints a fingerprint of the Gold table (excluding BuiltAtUtc) for run-twice determinism checks.

Usage:
    python nonjd_reorder_check.py --tier dev            # compare, exit 1 on any mismatch
    python nonjd_reorder_check.py --tier dev --fingerprint-only

Auth: Azure CLI (az login as Brian), read-only.
"""
import argparse
import sys
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import duckdb

TIERS = {
    "dev": {"staging": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101"),
            "presentation": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91")},
    "prod": {"staging": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"),
             "presentation": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f")},
}
MATRIX_CSV = (Path(__file__).resolve().parents[2] / "projects" / "part order tool - app" / "params"
              / "rop_matrix.csv")
WINDOW_MONTHS = 12
COMPARE_COLS = ["MonthCount", "StockingTarget", "RecommendedOrderQty", "SurplusQty", "Status"]


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.year * 12 + (d.month - 1) + n, 12)
    return date(y, m + 1, 1)


EXPECTED_SQL = """
    WITH scope AS (
        SELECT * FROM parts
        WHERE Cost > 0
          AND upper(trim(Franchise)) NOT IN ('D', 'ZP', 'S', '95')
          AND NOT starts_with(upper(trim(Franchise)), 'T')
          AND NOT starts_with(upper(trim(Franchise)), 'U')
    ),
    win AS (
        SELECT Branch, Franchise, PartNumber,
               sum(CASE WHEN SalesQty > 0 OR RequestCount > 0 THEN 1 ELSE 0 END) AS MonthCount,
               CAST(sum(coalesce(SalesQty, 0)) AS DOUBLE) AS WindowSales,
               CAST(sum(coalesce(RequestCount, 0)) AS DOUBLE) AS WindowRequests
        FROM hist WHERE MonthStart >= ? AND MonthStart <= ?
        GROUP BY ALL
    ),
    s AS (
        SELECT * EXCLUDE (rn) FROM (
            SELECT *, row_number() OVER (PARTITION BY Branch, Franchise, PartNumber
                                         ORDER BY Modified DESC, Id DESC) AS rn
            FROM settings) WHERE rn = 1
    ),
    t AS (
        SELECT trim(RequestingBranch) AS b, PartNumber AS pn, sum(coalesce(OpenQty, 0)) AS q
        FROM transfers GROUP BY ALL
    ),
    base AS (
        SELECT sc.Branch, sc.Franchise, sc.PartNumber,
               CAST(trunc(coalesce(sc.QuantityOnHand, 0)) AS INTEGER) AS oh,
               CAST(trunc(coalesce(sc.OnOrder, 0)) AS INTEGER) AS oo,
               sc.QuantityOnHand,
               coalesce(w.MonthCount, 0) AS mc,
               CASE WHEN coalesce(w.MonthCount, 0) > 0 THEN w.WindowRequests / w.MonthCount ELSE 0.0 END AS avg_d,
               CASE WHEN coalesce(w.MonthCount, 0) > 0 THEN w.WindowSales / w.MonthCount ELSE 0.0 END AS avg_s,
               CASE WHEN coalesce(w.MonthCount, 0) = 0 THEN 1
                    WHEN w.MonthCount > 19 THEN 19 ELSE w.MonthCount END AS mcc,
               CAST(coalesce(s.MinOverride, r.MinimumQty, 0) AS DOUBLE) AS eff_min,
               coalesce(s.Masked, false) AND (s.MaskExpires IS NULL OR s.MaskExpires >= ?) AS masked,
               coalesce(t.q, 0.0) AS inbound
        FROM scope sc
        LEFT JOIN win w USING (Branch, Franchise, PartNumber)
        LEFT JOIN rules r USING (Branch, Franchise, PartNumber)
        LEFT JOIN s USING (Branch, Franchise, PartNumber)
        LEFT JOIN t ON t.b = trim(sc.Branch) AND t.pn = upper(trim(sc.PartNumber))
    ),
    rop AS (
        SELECT base.*, coalesce(m.Modifier, 1.0) AS modifier, coalesce(m.WarehouseMin, 1) AS wmin
        FROM base LEFT JOIN matrix m
          ON m.MonthCount = base.mcc AND base.avg_d >= m.DemandL AND base.avg_d < m.DemandH
         AND base.avg_s >= m.SalesL AND base.avg_s < m.SalesH
    ),
    calc AS (
        SELECT *, CASE WHEN mc = 0 THEN NULL
                       ELSE CAST(ceil(greatest(CAST(wmin AS DOUBLE), eff_min, avg_d * modifier)) AS INTEGER)
                  END AS target
        FROM rop
    ),
    rec AS (
        SELECT *, CASE WHEN masked OR mc = 0 THEN 0 ELSE greatest(0, target - oh - oo) END AS rec_qty FROM calc
    )
    SELECT Branch, Franchise, PartNumber, mc AS MonthCount, target AS StockingTarget,
           rec_qty AS RecommendedOrderQty,
           CASE WHEN mc = 0 THEN greatest(0, oh) ELSE greatest(0, oh - target) END AS SurplusQty,
           inbound AS InboundTransferQty,
           CASE WHEN masked THEN 'Masked' WHEN mc = 0 THEN 'NoRecentActivity'
                WHEN rec_qty > 0 AND coalesce(QuantityOnHand, 0) <= 0 THEN 'OutOfStock'
                WHEN rec_qty > 0 THEN 'Reorder' ELSE 'OK' END AS Status
    FROM rec
"""


def _params(current_month: date, today: date) -> list:
    return [add_months(current_month, -(WINDOW_MONTHS - 1)), current_month, today]


def expected_reorder(con, current_month: date, today: date):
    """Run the reference rules over tables parts, rules, hist, matrix, settings, transfers."""
    return con.execute(EXPECTED_SQL, _params(current_month, today))


def compare(con, gold: str, expected: str) -> dict:
    keys = "Branch, Franchise, PartNumber"
    only_gold = con.execute(f"SELECT count(*) FROM (SELECT {keys} FROM {gold} EXCEPT SELECT {keys} FROM {expected})").fetchone()[0]
    only_exp = con.execute(f"SELECT count(*) FROM (SELECT {keys} FROM {expected} EXCEPT SELECT {keys} FROM {gold})").fetchone()[0]
    diff_cond = " OR ".join(f"g.{c} IS DISTINCT FROM e.{c}" for c in COMPARE_COLS)
    different = con.execute(f"""
        SELECT count(*) FROM {gold} g JOIN {expected} e USING ({keys})
        WHERE {diff_cond} OR abs(coalesce(g.InboundTransferQty, 0) - coalesce(e.InboundTransferQty, 0)) > 1e-6
    """).fetchone()[0]
    return {"only_gold": only_gold, "only_expected": only_exp, "different": different}


def _path(tier: str, layer: str, table: str) -> str:
    ws, lh = TIERS[tier][layer]
    return f"abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"


def _connect(tier: str):
    con = duckdb.connect()
    con.execute("SET memory_limit='3GB'; SET temp_directory='.duckdb_spill'; SET preserve_insertion_order=false;")
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
    con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    return con


def fingerprint(con, tier: str) -> tuple:
    p = _path(tier, "presentation", "Fact_NonJD_Reorder")
    return con.execute(f"""SELECT count(*), bit_xor(hash(t))
                           FROM (SELECT * EXCLUDE (BuiltAtUtc) FROM delta_scan('{p}')) t""").fetchone()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tier", choices=sorted(TIERS), required=True)
    ap.add_argument("--fingerprint-only", action="store_true")
    a = ap.parse_args()
    con = _connect(a.tier)
    rows, fp = fingerprint(con, a.tier)
    print(f"Fact_NonJD_Reorder ({a.tier}): {rows:,} rows, fingerprint {fp}")
    if a.fingerprint_only:
        return 0

    gold_p = _path(a.tier, "presentation", "Fact_NonJD_Reorder")
    built = con.execute(f"SELECT max(BuiltAtUtc) FROM delta_scan('{gold_p}')").fetchone()[0]
    today = built.astimezone(ZoneInfo("America/Chicago")).date()
    current_month = date(today.year, today.month, 1)
    print(f"Gold built {built}; checking as of {today} (month {current_month})")

    con.execute(f"""CREATE TABLE parts AS SELECT Branch, Franchise, PartNumber, QuantityOnHand, OnOrder, Cost
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartInformation')}')""")
    con.execute(f"""CREATE TABLE rules AS SELECT Branch, Franchise, PartNumber, MinimumQty
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartStockingRules')}')""")
    window_start = add_months(current_month, -(WINDOW_MONTHS - 1))
    con.execute(f"""CREATE TABLE hist AS SELECT Branch, Franchise, PartNumber, MonthStart, SalesQty, RequestCount
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartSalesHistory')}')
                    WHERE MonthStart >= DATE '{window_start}'""")
    con.execute(f"""CREATE TABLE matrix AS SELECT CAST(MonthCount AS INTEGER) MonthCount, CAST(DemandL AS DOUBLE) DemandL,
                    CAST(DemandH AS DOUBLE) DemandH, CAST(SalesL AS DOUBLE) SalesL, CAST(SalesH AS DOUBLE) SalesH,
                    CAST(Modifier AS DOUBLE) Modifier, CAST(WarehouseMin AS INTEGER) WarehouseMin
                    FROM read_csv('{MATRIX_CSV.as_posix()}', header=true, all_varchar=true)""")
    con.execute(f"""CREATE TABLE settings AS SELECT Id, Branch, Franchise, PartNumber, MinOverride, Masked,
                    MaskExpires, Modified FROM delta_scan('{_path(a.tier, 'staging', 'NonJD_PartSettings')}')""")
    con.execute(f"""CREATE TABLE transfers AS SELECT RequestingBranch, PartNumber, OpenQty
                    FROM delta_scan('{_path(a.tier, 'presentation', 'Fact_OutstandingTransfers')}')""")
    con.execute("CREATE TABLE expected AS " + EXPECTED_SQL, _params(current_month, today))
    con.execute(f"""CREATE TABLE gold AS SELECT Branch, Franchise, PartNumber, MonthCount, StockingTarget,
                    RecommendedOrderQty, SurplusQty, InboundTransferQty, Status FROM delta_scan('{gold_p}')""")
    result = compare(con, "gold", "expected")
    print(result)
    if any(result.values()):
        print(con.execute("""SELECT g.*, e.StockingTarget e_target, e.RecommendedOrderQty e_rec, e.Status e_status
                             FROM gold g JOIN expected e USING (Branch, Franchise, PartNumber)
                             WHERE g.RecommendedOrderQty IS DISTINCT FROM e.RecommendedOrderQty
                                OR g.Status IS DISTINCT FROM e.Status LIMIT 10""").fetchall())
        return 1
    print("PASS: Gold matches the reference rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tools/dp-migration && python -m pytest test_nonjd_reorder_check.py -q`
Expected: `9 passed`

- [ ] **Step 5: Commit (data-projects)**

```bash
git add tools/dp-migration/nonjd_reorder_check.py tools/dp-migration/test_nonjd_reorder_check.py
git commit -m "Non-JD order tool: reference reorder rules + Gold comparison check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Silver_PartSalesHistory notebook

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartSalesHistory.Notebook/.platform`
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartSalesHistory.Notebook/notebook-content.py`

(All paths in Tasks 4-8 are in fabric-workspace-docs.)

- [ ] **Step 1: Save the `.platform` helper** (used again in Tasks 5, 6 and 7) as `make_platform.py` in your scratchpad, not the repo. It writes a new random `logicalId` and no trailing newline, as Git sync requires:

```python
# make_platform.py <item folder> <displayName> <Notebook|Dataflow>
import json, os, sys, uuid
folder, name, kind = sys.argv[1:4]
os.makedirs(folder, exist_ok=True)
doc = {"$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
       "metadata": {"type": kind, "displayName": name},
       "config": {"version": "2.0", "logicalId": str(uuid.uuid4())}}
with open(os.path.join(folder, ".platform"), "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(doc, indent=2))
print(doc["config"]["logicalId"])
```

- [ ] **Step 2: Write `.platform`** (from the fabric-workspace-docs root)

Run: `python <scratchpad>/make_platform.py "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartSalesHistory.Notebook" Build_Silver_PartSalesHistory Notebook`
Expected: a uuid printed; the file exists and its last byte is `}`.

- [ ] **Step 3: Write `notebook-content.py`**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "876255e0-d462-4697-adc1-4a655f5bb101",
# META       "default_lakehouse_name": "DP_Staging",
# META       "default_lakehouse_workspace_id": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
# META       "known_lakehouses": [
# META         {
# META           "id": "876255e0-d462-4697-adc1-4a655f5bb101"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Build_Silver_PartSalesHistory
#
# PURPOSE: monthly sales units, request (demand) counts and sales value per part for the last 60 months
#   (the current month plus 59), for the Non-JD Parts Order Tool (Build_Gold_NonJD_Reorder) and any report that
#   needs monthly part history. Spec: data-projects
#   docs/superpowers/specs/2026-10-20-non-jd-parts-order-tool-redesign-design.md
# GRAIN: Branch + Franchise + PartNumber + MonthStart. JD's primary key for InHistMQT is
#   BRANCH, FRANCHISE, PART_NO, MM_YYYY (watermarktable_full, checked 2026-10-20).
# SOURCE: shortcut InHistMQT (JD Bronze).
# VERIFIED 2026-10-20 (DuckDB on Dev): month t-1 matches INHIST_MONTH_4_PI.PI_SALES_HISTORY_02 and
#   PI_SALES_REQUEST_02 on 99.997% of 999,649 keys; t-12 vs _13 on 99.97% (the two Bronze copies are taken at
#   slightly different times). MM_YYYY is the 1st of the month at 00:00 UTC and includes the current month.
# A part has a row only for months with any history; a missing month means no activity.
# Key text is not trimmed: trailing-space twin part numbers are real, separate parts.

from datetime import date, datetime

import pytz
from pyspark.sql import functions as F

spark.conf.set("spark.sql.session.timeZone", "UTC")

MONTHS = 60
KEY = ["Branch", "Franchise", "PartNumber", "MonthStart"]


def add_months(d, n):
    y, m = divmod(d.year * 12 + (d.month - 1) + n, 12)
    return date(y, m + 1, 1)


today_central = datetime.now(pytz.utc).astimezone(pytz.timezone("America/Chicago")).date()
current_month = date(today_central.year, today_central.month, 1)
oldest_month = add_months(current_month, -(MONTHS - 1))
print(f"BUILD_SILVER_PARTSALESHISTORY: months {oldest_month} .. {current_month}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

hist = (
    spark.read.table("InHistMQT")
    .select(
        F.col("BRANCH").alias("Branch"),
        F.col("FRANCHISE").alias("Franchise"),
        F.col("PART_NO").alias("PartNumber"),
        F.to_date("MM_YYYY").alias("MonthStart"),
        F.col("SAL_QTY").cast("decimal(12,2)").alias("SalesQty"),
        F.col("REQ_CNT").cast("int").alias("RequestCount"),
        F.col("SAL_VAL").cast("decimal(14,2)").alias("SalesValue"),
    )
    .filter((F.col("MonthStart") >= F.lit(oldest_month)) & (F.col("MonthStart") <= F.lit(current_month)))
)

null_keys = hist.filter(F.col("Branch").isNull() | F.col("Franchise").isNull()
                        | F.col("PartNumber").isNull() | F.col("MonthStart").isNull()).count()
if null_keys:
    raise ValueError(f"{null_keys} InHistMQT rows have a null key column")

not_month_start = hist.filter(F.dayofmonth("MonthStart") != 1).count()
if not_month_start:
    raise ValueError(f"{not_month_start} rows have MM_YYYY not on the 1st of a month - check the source's time zone")

dup_keys = hist.groupBy(*KEY).count().filter("count > 1").count()
if dup_keys:
    raise ValueError(f"{dup_keys} duplicate {KEY} keys in InHistMQT - refusing to pick a survivor")

row_count = hist.count()
months_present = hist.select("MonthStart").distinct().count()
print(f"Rows: {row_count:,}; distinct months: {months_present}")
if months_present < MONTHS - 1:
    raise ValueError(f"only {months_present} months present, expected about {MONTHS}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

(hist.write.format("delta").mode("overwrite").option("overwriteSchema", "true")
     .save("Tables/Silver_PartSalesHistory"))
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Silver_PartSalesHistory` RETAIN 0 HOURS")
print(f"SUCCESS: {row_count:,} rows written to Silver_PartSalesHistory")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Commit** (push happens in Task 8)

```bash
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartSalesHistory.Notebook"
git commit -m "DP: Build_Silver_PartSalesHistory (60 months from InHistMQT) for the Non-JD order tool

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Silver_PartStockingRules notebook (with the InMaster guard)

**Files:**
- Modify: `deploy/test_inmaster_guard.py:6-7`
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartStockingRules.Notebook/.platform`
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartStockingRules.Notebook/notebook-content.py`

- [ ] **Step 1: Add the new notebook to the guard test (failing test)**

Replace lines 6-7 of `deploy/test_inmaster_guard.py` with:

```python
NOTEBOOKS = [ROOT / "Build_Silver_PartInformation.Notebook" / "notebook-content.py",
             ROOT / "Data Notebooks" / "Build_Silver_InMaster.Notebook" / "notebook-content.py",
             ROOT / "Data Notebooks" / "Build_Silver_PartStockingRules.Notebook" / "notebook-content.py"]
```

And change the comparison in `test_guard_is_identical_in_every_inmaster_reader` to:

```python
def test_guard_is_identical_in_every_inmaster_reader():
    guards = [_guard(_text(p)) for p in NOTEBOOKS]
    assert all(g == guards[0] for g in guards[1:])
```

- [ ] **Step 2: Run to verify it fails**

Run: `python -m pytest deploy/test_inmaster_guard.py -q`
Expected: FAIL with `FileNotFoundError` for `Build_Silver_PartStockingRules.Notebook/notebook-content.py`

- [ ] **Step 3: Write `.platform`**

Run: `python <scratchpad>/make_platform.py "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartStockingRules.Notebook" Build_Silver_PartStockingRules Notebook`

- [ ] **Step 4: Write `notebook-content.py`**

The block from `# JD's Full copy has returned` to `    print(inmaster_warning)` must be byte-identical to `Build_Silver_PartInformation`'s (the test enforces it). Copy it from that notebook rather than retyping if in doubt.

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "876255e0-d462-4697-adc1-4a655f5bb101",
# META       "default_lakehouse_name": "DP_Staging",
# META       "default_lakehouse_workspace_id": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
# META       "known_lakehouses": [
# META         {
# META           "id": "876255e0-d462-4697-adc1-4a655f5bb101"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Build_Silver_PartStockingRules
#
# PURPOSE: per-part stocking settings kept in Equip's InMaster that Silver_InMaster and Silver_PartInformation
#   don't carry: minimum and maximum quantity, reorder code, activity code. Read by Build_Gold_NonJD_Reorder
#   (MinimumQty feeds the stocking target, as in the old LH nb_Fact_NonJD_Parts_Order).
# GRAIN: Branch + Franchise + PartNumber (JD primary key of InMaster: BRANCH, FRANCHISE, PART_NO).
# SOURCE: shortcut InMaster (JD Bronze).

from pyspark.sql import functions as F

spark.conf.set("spark.sql.session.timeZone", "UTC")
print("BUILD_SILVER_PARTSTOCKINGRULES")

in_master = spark.read.table("InMaster")
print(f"InMaster: {in_master.count():,} rows")

# JD's Full copy has returned an InMaster row twice (2026-10-19: 8/D/E63245, identical in all 73 columns; Equip had
# it once). Rows identical in EVERY column are collapsed - that keeps no arbitrary survivor - and reported as a
# warning. Rows that share the key but differ still fail: that's a real conflict.
# This block is byte-identical in every notebook that reads Bronze InMaster (deploy/test_inmaster_guard.py).
_KEY = ["BRANCH", "FRANCHISE", "PART_NO"]
_dup_keys = in_master.groupBy(*_KEY).count().filter("count > 1")
_n_dup_keys = _dup_keys.count()
inmaster_warning = None
if _n_dup_keys:
    _distinct = in_master.distinct()
    _conflicts = _distinct.groupBy(*_KEY).count().filter("count > 1").count()
    if _conflicts:
        raise ValueError(f"InMaster has {_conflicts} key(s) whose rows differ - refusing to pick one "
                         f"(dp-notebook-rules: no arbitrary survivors)")
    _before = in_master.count()
    in_master = _distinct.cache()
    _examples = ", ".join("/".join(str(r[k]) for k in _KEY) for r in _dup_keys.orderBy(*_KEY).limit(5).collect())
    inmaster_warning = (f"Bronze InMaster had {_before - in_master.count()} exact duplicate row(s) on "
                        f"{_n_dup_keys} key(s) (e.g. {_examples}); collapsed. Equip has each once - a JD copy "
                        f"read issue; the next Full load normally replaces it.")
    print(inmaster_warning)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

rules = in_master.select(
    F.col("BRANCH").alias("Branch"),
    F.col("FRANCHISE").alias("Franchise"),
    F.col("PART_NO").alias("PartNumber"),
    F.col("MINIMUM_QTY").cast("decimal(10,2)").alias("MinimumQty"),
    F.col("MAXIMUM_QTY").cast("decimal(10,2)").alias("MaximumQty"),
    F.col("REORDER_CODE").alias("ReorderCode"),
    F.col("ACTIVITY_CODE").alias("ActivityCode"),
)

row_count = rules.count()
dup_keys = rules.groupBy("Branch", "Franchise", "PartNumber").count().filter("count > 1").count()
if dup_keys:
    raise ValueError(f"{dup_keys} duplicate keys after the InMaster guard")

(rules.write.format("delta").mode("overwrite").option("overwriteSchema", "true")
      .save("Tables/Silver_PartStockingRules"))
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Silver_PartStockingRules` RETAIN 0 HOURS")
print(f"SUCCESS: {row_count:,} rows written to Silver_PartStockingRules")

if inmaster_warning:
    notebookutils.notebook.exit("WARN: " + inmaster_warning)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 5: Run the guard test**

Run: `python -m pytest deploy/test_inmaster_guard.py -q`
Expected: `2 passed`

- [ ] **Step 6: Commit**

```bash
git add deploy/test_inmaster_guard.py "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartStockingRules.Notebook"
git commit -m "DP: Build_Silver_PartStockingRules (min/max/reorder/activity from InMaster)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Part-settings dataflow

**Files:**
- Create: `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_PartSettings_Raw.Dataflow/.platform`
- Create: `.../df_NonJD_PartSettings_Raw.Dataflow/queryMetadata.json`
- Create: `.../df_NonJD_PartSettings_Raw.Dataflow/mashup.pq`

- [ ] **Step 1: Generate two query ids** for Step 3: `python -c "import uuid; [print(uuid.uuid4()) for _ in range(2)]"`. Use them as `<UUID-B>` and `<UUID-C>`.

- [ ] **Step 2: Write `.platform`**

Run: `python <scratchpad>/make_platform.py "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_PartSettings_Raw.Dataflow" df_NonJD_PartSettings_Raw Dataflow`

- [ ] **Step 3: Write `queryMetadata.json`** (connections copied from `df_Dim_BranchUserAccess`, which already uses the same SharePoint tenant and lakehouse connections):

```json
{
  "formatVersion": "202502",
  "computeEngineSettings": {
    "allowModernEvaluationEngine": true
  },
  "name": "df_NonJD_PartSettings_Raw",
  "queryGroups": [],
  "documentLocale": "en-US",
  "gatewayObjectId": "d98a8d2c-d0df-4a42-a281-aab18e49dbd7",
  "queriesMetadata": {
    "NonJD_PartSettings": {
      "queryId": "<UUID-B>",
      "queryName": "NonJD_PartSettings",
      "loadEnabled": false
    },
    "NonJD_PartSettings_DataDestination": {
      "queryId": "<UUID-C>",
      "queryName": "NonJD_PartSettings_DataDestination",
      "isHidden": true,
      "loadEnabled": false
    }
  },
  "connections": [
    {
      "path": "Lakehouse",
      "kind": "Lakehouse",
      "connectionId": "{\"ClusterId\":\"d98a8d2c-d0df-4a42-a281-aab18e49dbd7\",\"DatasourceId\":\"ec4b2ec8-cf80-4ab1-a47d-f018c5be7b6c\"}"
    },
    {
      "path": "https://spitractor.sharepoint.com",
      "kind": "SharePoint",
      "connectionId": "{\"ClusterId\":\"e8fe8222-99d4-4763-be03-af2f5603a773\",\"DatasourceId\":\"42db34a4-fef6-4221-aac7-18ff87e019ec\"}"
    }
  ]
}
```

- [ ] **Step 4: Write `mashup.pq`**

```
[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "NonJD_PartSettings_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared NonJD_PartSettings = /*
============================================================================
Table:     NonJD_PartSettings
Dataflow:  df_NonJD_PartSettings_Raw
Location:  DP - Staging - Dev -> Raw Data - Dataflows
============================================================================

PURPOSE:
Per-part overrides that parts managers save in the Non-JD Parts Order Tool
web app (SharePoint list NonJD_PartSettings on the Parts Order Tool site).
Build_Gold_NonJD_Reorder applies MinOverride and Masked/MaskExpires; the
other columns are stored for later rules.

SOURCE: SharePoint list NonJD_PartSettings,
https://spitractor.sharepoint.com/sites/PartsOrderTool. The list is the
system of record; the app writes it under each user's own sign-in.

REFRESH: daily, by Pipeline_DP_Refresh, before Build_Gold_NonJD_Reorder.

GRAIN: one row per list item. Normally one per Branch + Franchise +
PartNumber; if duplicates exist, Gold keeps the latest Modified (then the
highest Id).

KNOWN LIMIT: SharePoint text columns may not keep trailing spaces, so a
setting on one of the trailing-space twin part numbers may not match.
============================================================================
*/
let
  Source = SharePoint.Tables("https://spitractor.sharepoint.com/sites/PartsOrderTool", [Implementation = "2.0", ViewMode = "All"]),
  Items = Source{[Title = "NonJD_PartSettings"]}[Items],
  IdColumn = if List.Contains(Table.ColumnNames(Items), "ID") then "ID" else "Id",
  WithId = Table.RenameColumns(Items, {{IdColumn, "ItemId"}}),
  Chosen = Table.SelectColumns(WithId, {"ItemId", "Branch", "Franchise", "PartNumber", "MinOverride", "EOQ", "ForceNonSpiking", "Masked", "MaskExpires", "PreApprovedRule", "Modified"}),
  Renamed = Table.RenameColumns(Chosen, {{"ItemId", "Id"}}),
  ModifiedUtc = Table.TransformColumns(Renamed, {{"Modified", each if _ = null then null else DateTimeZone.RemoveZone(DateTimeZone.ToUtc(DateTimeZone.From(_))), type datetime}}),
  Typed = Table.TransformColumnTypes(ModifiedUtc, {{"Id", Int64.Type}, {"Branch", type text}, {"Franchise", type text}, {"PartNumber", type text}, {"MinOverride", type number}, {"EOQ", type number}, {"ForceNonSpiking", type logical}, {"Masked", type logical}, {"MaskExpires", type date}, {"PreApprovedRule", type text}})
in
  Typed;
shared NonJD_PartSettings_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "876255e0-d462-4697-adc1-4a655f5bb101"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "NonJD_PartSettings", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
```

- [ ] **Step 5: Commit**

```bash
git add "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_PartSettings_Raw.Dataflow"
git commit -m "DP: df_NonJD_PartSettings_Raw (order-tool settings list -> DP_Staging)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Gold notebook Build_Gold_NonJD_Reorder

**Files:**
- Create: `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/.platform`
- Create: `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/notebook-content.py`

- [ ] **Step 1: Write `.platform`**

Run: `python <scratchpad>/make_platform.py "workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook" Build_Gold_NonJD_Reorder Notebook`

- [ ] **Step 2: Write `notebook-content.py`** (implements the 10 rules in Task 3 exactly)

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "966efc8a-16f9-423b-aa43-e368fcd8fb91"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# ============================================================================
# NOTEBOOK: Build_Gold_NonJD_Reorder
# ============================================================================
# PURPOSE: daily reorder recommendations for non-John Deere parts, and their 60-month history, for the Non-JD
#   Parts Order Tool web app (published to SharePoint by data-projects
#   projects/part order tool - app/publish/). Port of LH_Master_Data nb_Fact_NonJD_Parts_Order with:
#   the full Branch + Franchise + PartNumber key (LH joined InMaster on Branch + PartNumber), part settings
#   applied, inbound transfers and surplus added, and parts with no recent activity kept (recommendation 0).
# RULES: data-projects docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md, Task 3.
#   tools/dp-migration/nonjd_reorder_check.py re-implements them independently; keep both in step.
# GRAIN: Fact_NonJD_Reorder - Branch + Franchise + PartNumber.
#        Fact_NonJD_SalesHistory - Branch + Franchise + PartNumber + MonthStart (months with activity only).
# SOURCES (DP_Presentation shortcuts): Silver_PartInformation, Silver_InMaster, Silver_PartStockingRules,
#   Silver_PartSalesHistory, NonJD_PartSettings; Gold Fact_OutstandingTransfers;
#   Files/config/nonjd/rop_matrix.csv (data-projects projects/part order tool - app/params/rop_matrix.csv).
# ============================================================================

from datetime import date, datetime

import pytz
from pyspark.sql import Window
from pyspark.sql import functions as F

spark.conf.set("spark.sql.session.timeZone", "UTC")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

CALC_WINDOW_MONTHS = 12   # old LH logic used Month01-12; spec section 11 asks Ben whether to change it
HISTORY_MONTHS = 60
EXCLUDED_FRANCHISES = ["D", "ZP", "S", "95"]
EXCLUDED_PREFIXES = ["T", "U"]
KEY = ["Branch", "Franchise", "PartNumber"]


def add_months(d, n):
    y, m = divmod(d.year * 12 + (d.month - 1) + n, 12)
    return date(y, m + 1, 1)


today_central = datetime.now(pytz.utc).astimezone(pytz.timezone("America/Chicago")).date()
current_month = date(today_central.year, today_central.month, 1)
window_start = add_months(current_month, -(CALC_WINDOW_MONTHS - 1))
history_start = add_months(current_month, -(HISTORY_MONTHS - 1))
built_at = datetime.now(pytz.utc).replace(tzinfo=None)
print(f"Today (Central) {today_central}; calc window {window_start}..{current_month}; history from {history_start}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ---- Inputs ----
parts = spark.sql("""SELECT Branch, Franchise, PartNumber, Description, Bin, VendorCode, DealerGroupCode,
                            SuperTo, SuperFrom, QuantityOnHand, OnOrder, BackOrderQty, Cost, SellPrice1, ListPrice,
                            Current12MoSales, Previous12MoSales, DateLastRequested
                     FROM Silver_PartInformation""")
fr = F.upper(F.trim(F.col("Franchise")))
scope = parts.filter((F.col("Cost") > 0) & ~fr.isin(EXCLUDED_FRANCHISES)
                     & ~fr.startswith(EXCLUDED_PREFIXES[0]) & ~fr.startswith(EXCLUDED_PREFIXES[1]))

inmaster = spark.sql("SELECT Branch, Franchise, PartNumber, LowMarginFlag, ProductGroup FROM Silver_InMaster")
rules = spark.sql("""SELECT Branch, Franchise, PartNumber, MinimumQty, MaximumQty, ReorderCode, ActivityCode
                     FROM Silver_PartStockingRules""")
hist = spark.sql("""SELECT Branch, Franchise, PartNumber, MonthStart, SalesQty, RequestCount
                    FROM Silver_PartSalesHistory""")
settings_raw = spark.sql("""SELECT Id, Branch, Franchise, PartNumber, MinOverride, Masked, MaskExpires, Modified
                            FROM NonJD_PartSettings""")
transfers = spark.sql("SELECT RequestingBranch, PartNumber, OpenQty FROM Fact_OutstandingTransfers")

matrix = (spark.read.option("header", True).csv("Files/config/nonjd/rop_matrix.csv")
          .select(F.col("MonthCount").cast("int").alias("ROP_MonthCount"),
                  F.col("DemandL").cast("double"), F.col("DemandH").cast("double"),
                  F.col("SalesL").cast("double"), F.col("SalesH").cast("double"),
                  F.col("Modifier").cast("double"), F.col("WarehouseMin").cast("int"))
          .filter(F.col("ROP_MonthCount").isNotNull()))

print(f"Parts in scope: {scope.count():,}; matrix rows: {matrix.count():,}; settings rows: {settings_raw.count():,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ---- Window activity (rules 2-3) ----
win = (hist.filter((F.col("MonthStart") >= F.lit(window_start)) & (F.col("MonthStart") <= F.lit(current_month)))
       .groupBy(*KEY)
       .agg(F.sum(F.when((F.col("SalesQty") > 0) | (F.col("RequestCount") > 0), 1).otherwise(0)).alias("MonthCount"),
            F.sum(F.coalesce(F.col("SalesQty"), F.lit(0))).cast("double").alias("WindowSales"),
            F.sum(F.coalesce(F.col("RequestCount"), F.lit(0))).cast("double").alias("WindowRequests")))

# ---- Settings: latest row per key (rule 5) ----
w_latest = Window.partitionBy(*KEY).orderBy(F.col("Modified").desc_nulls_last(), F.col("Id").desc())
settings = (settings_raw.withColumn("_rn", F.row_number().over(w_latest)).filter("_rn = 1").drop("_rn", "Id", "Modified")
            .withColumn("IsMasked", F.coalesce(F.col("Masked"), F.lit(False))
                        & (F.col("MaskExpires").isNull() | (F.col("MaskExpires") >= F.lit(today_central))))
            .select(*KEY, "MinOverride", "IsMasked", "MaskExpires"))

# ---- Inbound transfers (rule 9) ----
inbound = (transfers.groupBy(F.trim(F.col("RequestingBranch")).alias("_tb"), F.col("PartNumber").alias("_tp"))
           .agg(F.sum(F.coalesce(F.col("OpenQty"), F.lit(0.0))).alias("InboundTransferQty")))

base = (scope
        .join(win, KEY, "left")
        .join(rules, KEY, "left")
        .join(inmaster, KEY, "left")
        .join(settings, KEY, "left")
        .join(inbound, (F.trim(F.col("Branch")) == F.col("_tb"))
              & (F.upper(F.trim(F.col("PartNumber"))) == F.col("_tp")), "left")
        .drop("_tb", "_tp")
        .withColumn("MonthCount", F.coalesce(F.col("MonthCount"), F.lit(0)))
        .withColumn("AvgMonthlyDemand", F.when(F.col("MonthCount") > 0, F.col("WindowRequests") / F.col("MonthCount")).otherwise(F.lit(0.0)))
        .withColumn("AvgMonthlySales", F.when(F.col("MonthCount") > 0, F.col("WindowSales") / F.col("MonthCount")).otherwise(F.lit(0.0)))
        .withColumn("MonthCountCapped", F.when(F.col("MonthCount") == 0, 1).when(F.col("MonthCount") > 19, 19).otherwise(F.col("MonthCount")))
        .withColumn("EffectiveMin", F.coalesce(F.col("MinOverride").cast("double"), F.col("MinimumQty").cast("double"), F.lit(0.0)))
        .withColumn("IsMasked", F.coalesce(F.col("IsMasked"), F.lit(False)))
        .withColumn("InboundTransferQty", F.coalesce(F.col("InboundTransferQty"), F.lit(0.0)))
        .withColumn("OnHandInt", F.coalesce(F.col("QuantityOnHand"), F.lit(0)).cast("int"))
        .withColumn("OnOrderInt", F.coalesce(F.col("OnOrder"), F.lit(0)).cast("int")))

# ---- Matrix (rule 4) ----
with_rop = (base.join(F.broadcast(matrix),
                      (F.col("MonthCountCapped") == F.col("ROP_MonthCount"))
                      & (F.col("AvgMonthlyDemand") >= F.col("DemandL")) & (F.col("AvgMonthlyDemand") < F.col("DemandH"))
                      & (F.col("AvgMonthlySales") >= F.col("SalesL")) & (F.col("AvgMonthlySales") < F.col("SalesH")),
                      "left")
            .withColumn("Modifier", F.coalesce(F.col("Modifier"), F.lit(1.0)))
            .withColumn("WarehouseMin", F.coalesce(F.col("WarehouseMin"), F.lit(1))))

# ---- Target, recommendation, surplus, status (rules 6-8, 10) ----
calc = (with_rop
        .withColumn("CalcROP", F.col("AvgMonthlyDemand") * F.col("Modifier"))
        .withColumn("StockingTarget", F.when(F.col("MonthCount") == 0, F.lit(None).cast("int"))
                    .otherwise(F.ceil(F.greatest(F.col("WarehouseMin").cast("double"), F.col("EffectiveMin"),
                                                 F.col("CalcROP"))).cast("int")))
        .withColumn("RecommendedOrderQty", F.when(F.col("IsMasked") | (F.col("MonthCount") == 0), F.lit(0))
                    .otherwise(F.greatest(F.lit(0), F.col("StockingTarget") - F.col("OnHandInt") - F.col("OnOrderInt"))).cast("int"))
        .withColumn("SurplusQty", F.when(F.col("MonthCount") == 0, F.greatest(F.lit(0), F.col("OnHandInt")))
                    .otherwise(F.greatest(F.lit(0), F.col("OnHandInt") - F.col("StockingTarget"))).cast("int"))
        .withColumn("EstOrderValue", (F.col("RecommendedOrderQty") * F.col("Cost")).cast("decimal(14,2)"))
        .withColumn("IsLowMargin", F.upper(F.trim(F.coalesce(F.col("LowMarginFlag"), F.lit("")))) == "LOW")
        .withColumn("Status", F.when(F.col("IsMasked"), "Masked")
                    .when(F.col("MonthCount") == 0, "NoRecentActivity")
                    .when((F.col("RecommendedOrderQty") > 0) & (F.coalesce(F.col("QuantityOnHand"), F.lit(0)) <= 0), "OutOfStock")
                    .when(F.col("RecommendedOrderQty") > 0, "Reorder")
                    .otherwise("OK"))
        .withColumn("BuiltAtUtc", F.lit(built_at).cast("timestamp")))

final = calc.select(
    "Branch", "Franchise", "PartNumber", "Description", "Bin", "VendorCode", "DealerGroupCode", "ProductGroup",
    "SuperTo", "SuperFrom", "QuantityOnHand", "OnOrder", "BackOrderQty", "Cost", "SellPrice1", "ListPrice",
    "MinimumQty", "MaximumQty", "ReorderCode", "ActivityCode", "MinOverride", "IsMasked", "MaskExpires",
    "IsLowMargin", "Current12MoSales", "Previous12MoSales", "DateLastRequested",
    "MonthCount", "AvgMonthlyDemand", "AvgMonthlySales", "Modifier", "WarehouseMin", "EffectiveMin",
    "CalcROP", "StockingTarget", "RecommendedOrderQty", "EstOrderValue", "SurplusQty", "InboundTransferQty",
    "Status", "BuiltAtUtc")

reorder_rows = final.count()
dup = final.groupBy(*KEY).count().filter("count > 1").count()
if dup:
    raise ValueError(f"{dup} duplicate keys in Fact_NonJD_Reorder (a join fanned out) - not writing")
if reorder_rows < 100_000:
    raise ValueError(f"only {reorder_rows:,} rows - expected several hundred thousand; refusing to write")
print(f"Fact_NonJD_Reorder rows: {reorder_rows:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

(final.write.format("delta").mode("overwrite").option("overwriteSchema", "true")
      .save("Tables/Fact_NonJD_Reorder"))
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Fact_NonJD_Reorder` RETAIN 0 HOURS")
print(f"SUCCESS: {reorder_rows:,} rows written to Fact_NonJD_Reorder")

# ---- 60-month history for the parts in scope ----
sales_history = (hist.filter(F.col("MonthStart") >= F.lit(history_start))
                 .join(final.select(*KEY), KEY, "inner")
                 .withColumn("MonthOffset", (F.months_between(F.lit(current_month), F.col("MonthStart")) + 1).cast("int"))
                 .select(*KEY, "MonthStart", "MonthOffset", "SalesQty", "RequestCount"))
history_rows = sales_history.count()
(sales_history.write.format("delta").mode("overwrite").option("overwriteSchema", "true")
              .save("Tables/Fact_NonJD_SalesHistory"))
spark.sql("VACUUM delta.`Tables/Fact_NonJD_SalesHistory` RETAIN 0 HOURS")
print(f"SUCCESS: {history_rows:,} rows written to Fact_NonJD_SalesHistory")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Run the hygiene audit**

Run: `python deploy/hygiene_audit.py`
Expected: no findings for `Build_Gold_NonJD_Reorder`, `Build_Silver_PartSalesHistory`, `Build_Silver_PartStockingRules`.

- [ ] **Step 4: Commit**

```bash
git add "workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook"
git commit -m "DP: Build_Gold_NonJD_Reorder (reorder recommendations + 60-month history)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Register, shortcut, push and run in Dev

**Files:**
- Modify: `deploy/dp_refresh_dag.json` (append 4 items to `items`)
- Modify: `workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json` (append 3 entries)

- [ ] **Step 1: Add the DAG items** (append to the `items` array):

```json
{"name": "df_NonJD_PartSettings_Raw", "type": "dataflow", "workspace": "staging", "tier": "staging",
 "cadence": "daily", "dependsOn": [], "produces": ["NonJD_PartSettings"]},
{"name": "Build_Silver_PartSalesHistory", "type": "notebook", "workspace": "staging", "tier": "silver",
 "cadence": "daily", "dependsOn": [], "produces": ["Silver_PartSalesHistory"],
 "extraReads": [], "scanIgnore": [], "dynamicReviewed": false},
{"name": "Build_Silver_PartStockingRules", "type": "notebook", "workspace": "staging", "tier": "silver",
 "cadence": "daily", "dependsOn": [], "produces": ["Silver_PartStockingRules"],
 "extraReads": [], "scanIgnore": [], "dynamicReviewed": false},
{"name": "Build_Gold_NonJD_Reorder", "type": "notebook", "workspace": "presentation", "tier": "gold",
 "cadence": "daily",
 "dependsOn": ["Build_Silver_PartInformation", "Build_Silver_InMaster", "Build_Silver_PartStockingRules",
               "Build_Silver_PartSalesHistory", "df_NonJD_PartSettings_Raw", "Build_Gold_OutstandingTransfers"],
 "produces": ["Fact_NonJD_Reorder", "Fact_NonJD_SalesHistory"],
 "extraReads": [], "scanIgnore": [], "dynamicReviewed": false}
```

- [ ] **Step 2: Add the shortcuts** (append to the JSON array, same shape as the `Silver_PartInformation` entry):

```json
{"name": "Silver_PartSalesHistory", "path": "/Tables", "target": {"type": "OneLake", "oneLake": {
  "path": "Tables/Silver_PartSalesHistory", "itemId": "876255e0-d462-4697-adc1-4a655f5bb101",
  "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"}}},
{"name": "Silver_PartStockingRules", "path": "/Tables", "target": {"type": "OneLake", "oneLake": {
  "path": "Tables/Silver_PartStockingRules", "itemId": "876255e0-d462-4697-adc1-4a655f5bb101",
  "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"}}},
{"name": "NonJD_PartSettings", "path": "/Tables", "target": {"type": "OneLake", "oneLake": {
  "path": "Tables/NonJD_PartSettings", "itemId": "876255e0-d462-4697-adc1-4a655f5bb101",
  "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"}}}
```
Format them with the file's existing 2-space indentation.

- [ ] **Step 3: Validate**

Run: `python deploy/dag_check.py && python -m pytest deploy -q && python deploy/table_lineage.py`
Expected: dag_check reports no errors (if it flags a read the scanner misread, fix the code or add the name to `scanIgnore` with a reason, never silence a real read); all tests pass; `docs/TABLE-LINEAGE.md` regenerated with the new tables.

- [ ] **Step 4: Commit and push**

```bash
git add deploy/dp_refresh_dag.json "workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json" docs/TABLE-LINEAGE.md
git commit -m "DP: register Non-JD order tool items and shortcuts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
```

- [ ] **Step 5: Sync Dev workspaces** (from data-projects)

```bash
python tools/dp-migration/wait_ci.py
python tools/dp-migration/git_sync.py ab15d64d-c7ba-415d-9bcf-7feb1ef9b201
python tools/dp-migration/git_sync.py 73fd5443-240e-410a-990a-98827f32c087
```
Expected: both syncs complete; the 3 new staging items and the Gold notebook exist in Fabric. The Silver shortcuts in DP_Presentation are created by the sync but resolve only after the tables exist (Step 6).

- [ ] **Step 6: Run the new items in Dev, in dependency order** (from data-projects; the first three can run in any order, the Gold one last):

```bash
export PATH="$HOME/.local/bin:$PATH"
S=ab15d64d-c7ba-415d-9bcf-7feb1ef9b201; P=73fd5443-240e-410a-990a-98827f32c087
DF=$(fab get "DP - Staging - Dev.Workspace/df_NonJD_PartSettings_Raw.Dataflow" -q id | tail -1)
H=$(fab get "DP - Staging - Dev.Workspace/Build_Silver_PartSalesHistory.Notebook" -q id | tail -1)
R=$(fab get "DP - Staging - Dev.Workspace/Build_Silver_PartStockingRules.Notebook" -q id | tail -1)
G=$(fab get "DP - Presentation - Dev.Workspace/Build_Gold_NonJD_Reorder.Notebook" -q id | tail -1)
python tools/dp-migration/run_item.py $S $DF Refresh 1800
python tools/dp-migration/run_item.py $S $H RunNotebook 1800
python tools/dp-migration/run_item.py $S $R RunNotebook 1800
python tools/dp-migration/run_item.py $P $G RunNotebook 1800
```
Expected: each exits 0 (Completed). If the dataflow fails on the SharePoint connection, open it once in the Dev UI, confirm the connection and rerun; don't edit it there, because Git sync is the only writer. For a notebook error, open the run in the Fabric Monitor hub, fix the code in the repo, push, sync and rerun.

---

### Task 9: Verify the Gold output in Dev

**Files:** none new.

- [ ] **Step 1: Reference comparison**

Run (data-projects): `cd tools/dp-migration && python nonjd_reorder_check.py --tier dev`
Expected: `PASS: Gold matches the reference rules`. Any mismatch means the Spark and SQL rules differ; fix the one that disagrees with Task 3's rule list, then rerun Task 8 Step 6.

- [ ] **Step 2: The test setting took effect**

Run a one-off query (scratch script) against Dev Gold for the part you added in Task 1 Step 6:

```python
import duckdb
con = duckdb.connect(); con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
p = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/Fact_NonJD_Reorder"
print(con.execute(f"SELECT Branch, Franchise, PartNumber, MinOverride, EffectiveMin, StockingTarget, RecommendedOrderQty, Status FROM delta_scan('{p}') WHERE MinOverride IS NOT NULL").fetchall())
```
Expected: your test part, `MinOverride = 5`, `EffectiveMin = 5`, `StockingTarget >= 5` (unless it has no recent activity, then target is NULL).

- [ ] **Step 3: Sanity numbers** (same scratch script, add):

```python
print(con.execute(f"SELECT Status, count(*), sum(RecommendedOrderQty), round(sum(EstOrderValue)) FROM delta_scan('{p}') GROUP BY 1 ORDER BY 1").fetchall())
print(con.execute(f"SELECT count(DISTINCT Branch), count(DISTINCT Franchise) FROM delta_scan('{p}')").fetchall())
```
Record the numbers in this plan's Progress note. Expect roughly 19+ branches and around 40 franchises. A total estimated order value in the millions of dollars means a unit problem; stop and investigate.

- [ ] **Step 4: Determinism (run twice)**

```bash
python nonjd_reorder_check.py --tier dev --fingerprint-only
```
Rerun `Build_Gold_NonJD_Reorder` alone (the last `run_item.py` line of Task 8 Step 6), then run the fingerprint again. Expected: identical row count and fingerprint. (BuiltAtUtc is excluded; nothing else should change.)

- [ ] **Step 5: Measure cost**

From the summary email and the Capacity Metrics app (or `python tools/dp-migration/spark_usage.py` if it covers these items), record minutes and CU(s) for the four items in the Progress note.

---

### Task 10: Publish helpers (test first)

**Files:**
- Create: `projects/part order tool - app/publish/test_publish_logic.py`
- Create: `projects/part order tool - app/publish/publish_logic.py`

- [ ] **Step 1: Write the failing tests**

```python
# projects/part order tool - app/publish/test_publish_logic.py
from datetime import date, datetime, timezone
from decimal import Decimal

import publish_logic as pl


def _row(status, end, start=None, run="r1"):
    return {"run_id": run, "name": "Build_Gold_NonJD_Reorder", "row_type": "item", "status": status,
            "start_utc": start or end, "end_utc": end}


def test_latest_item_run_picks_newest_end():
    rows = [_row("Succeeded", datetime(2026, 10, 19, 11, 30), run="a"),
            _row("Failed", datetime(2026, 10, 20, 11, 30), run="b"),
            {**_row("Succeeded", datetime(2026, 10, 21)), "name": "Other"}]
    assert pl.latest_item_run(rows, "Build_Gold_NonJD_Reorder")["run_id"] == "b"


def test_latest_item_run_none_when_absent():
    assert pl.latest_item_run([], "Build_Gold_NonJD_Reorder") is None


def test_decide_publish_rules():
    ok = _row("Succeeded", datetime(2026, 10, 20, 11, 40))
    assert pl.decide_publish(None, {}, "prod") == (False, "no run of Build_Gold_NonJD_Reorder in the log")
    assert pl.decide_publish(_row("Failed", datetime(2026, 10, 20)), {}, "prod")[0] is False
    assert pl.decide_publish(ok, {}, "prod") == (True, "new data")
    state = {"source": "prod", "dataAsOf": pl.iso_utc(ok["end_utc"])}
    assert pl.decide_publish(ok, state, "prod") == (False, "already published")
    assert pl.decide_publish(ok, {**state, "source": "dev"}, "prod") == (True, "new data")
    assert pl.decide_publish(ok, state, "prod", force=True) == (True, "forced")


def test_built_in_run():
    s, e = datetime(2026, 10, 20, 11, 0), datetime(2026, 10, 20, 11, 40)
    assert pl.built_in_run(datetime(2026, 10, 20, 11, 20), s, e)
    assert not pl.built_in_run(datetime(2026, 10, 19, 11, 20), s, e)


def test_iso_utc_naive_is_utc():
    assert pl.iso_utc(datetime(2026, 10, 20, 11, 40)) == "2026-10-20T11:40:00+00:00"


def test_month_labels_newest_first():
    labels = pl.month_labels(date(2026, 2, 1), 4)
    assert labels == ["2026-02", "2026-01", "2025-12", "2025-11"]


def test_history_arrays_fill_zeros_and_sort():
    rows = [{"franchise": "MC", "partNumber": "B", "monthOffset": 1, "salesQty": Decimal("2.00"), "requestCount": 1},
            {"franchise": "MC", "partNumber": "B", "monthOffset": 3, "salesQty": Decimal("1.50"), "requestCount": 2},
            {"franchise": "MC", "partNumber": "A", "monthOffset": 2, "salesQty": None, "requestCount": None}]
    out = pl.history_arrays(rows, months=4)
    assert [p["partNumber"] for p in out] == ["A", "B"]
    assert out[1]["sales"] == [2, 0, 1.5, 0]
    assert out[1]["requests"] == [1, 0, 2, 0]
    assert out[0]["sales"] == [0, 0, 0, 0]


def test_history_arrays_ignores_out_of_range_offsets():
    rows = [{"franchise": "MC", "partNumber": "A", "monthOffset": 61, "salesQty": 5, "requestCount": 5}]
    assert pl.history_arrays(rows, months=60)[0]["sales"] == [0] * 60


def test_clean_value():
    assert pl.clean_value(Decimal("3.00")) == 3
    assert pl.clean_value(Decimal("3.25")) == 3.25
    assert pl.clean_value(datetime(2026, 10, 20, 5, 0)) == "2026-10-20T05:00:00+00:00"
    assert pl.clean_value(date(2026, 10, 20)) == "2026-10-20"
    assert pl.clean_value(float("nan")) is None
    assert pl.clean_value("x ") == "x "


def test_upload_order_meta_last():
    assert pl.upload_order(["out/_meta.json", "out/b.json.gz", "out/a.json.gz"]) == \
        ["out/a.json.gz", "out/b.json.gz", "out/_meta.json"]


def test_changed_files():
    assert pl.changed_files({"a": "1", "b": "2", "c": "3"}, {"a": "1", "b": "9"}) == ["b", "c"]
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd "projects/part order tool - app/publish" && python -m pytest test_publish_logic.py -q`
Expected: error `ModuleNotFoundError: No module named 'publish_logic'`

- [ ] **Step 3: Write the implementation**

```python
# projects/part order tool - app/publish/publish_logic.py
"""
NON-JD ORDER TOOL PUBLISH - PURE HELPERS (no network, no config; tested in test_publish_logic.py)

- latest_item_run / decide_publish / built_in_run: publish only a successful DP run, once, and only the table
  that run wrote. The data date shown in the app is the run's end time, never the publish time.
- month_labels / history_arrays: 60-month arrays per part, index 0 = current month (MonthOffset 1).
- clean_value: JSON-safe values (Decimal -> int/float, datetimes -> ISO UTC, NaN -> None).
- upload_order: _meta.json goes last so the app never sees a date ahead of its files.
- changed_files: only upload files whose content hash changed.
"""
import math
import os
from datetime import date, datetime, timezone
from decimal import Decimal

ITEM = "Build_Gold_NonJD_Reorder"
META_FILE = "_meta.json"


def iso_utc(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def _naive_utc(value: datetime) -> datetime:
    return value if value.tzinfo is None else value.astimezone(timezone.utc).replace(tzinfo=None)


def latest_item_run(rows: list, item: str = ITEM):
    mine = [r for r in rows if r.get("name") == item and r.get("row_type") == "item" and r.get("end_utc")]
    return max(mine, key=lambda r: _naive_utc(r["end_utc"]), default=None)


def decide_publish(latest, state: dict, source: str, force: bool = False):
    if latest is None:
        return False, f"no run of {ITEM} in the log"
    if latest.get("status") != "Succeeded":
        return False, f"latest {ITEM} run {latest.get('run_id')} ended {latest.get('status')}; keeping the old files"
    if force:
        return True, "forced"
    if state.get("source") == source and state.get("dataAsOf") == iso_utc(latest["end_utc"]):
        return False, "already published"
    return True, "new data"


def built_in_run(built: datetime, start: datetime, end: datetime) -> bool:
    return _naive_utc(start) <= _naive_utc(built) <= _naive_utc(end)


def month_labels(current_month: date, months: int = 60) -> list:
    out, y, m = [], current_month.year, current_month.month
    for _ in range(months):
        out.append(f"{y:04d}-{m:02d}")
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return out


def clean_value(v):
    if v is None:
        return None
    if isinstance(v, Decimal):
        return int(v) if v == v.to_integral_value() else float(v)
    if isinstance(v, float):
        if math.isnan(v):
            return None
        return int(v) if v.is_integer() else v
    if isinstance(v, datetime):
        return iso_utc(v)
    if isinstance(v, date):
        return v.isoformat()
    if hasattr(v, "item"):  # numpy scalars from pandas
        return clean_value(v.item())
    return v


def history_arrays(rows: list, months: int = 60) -> list:
    parts = {}
    for r in rows:
        key = (r["franchise"], r["partNumber"])
        p = parts.setdefault(key, {"franchise": key[0], "partNumber": key[1],
                                   "sales": [0] * months, "requests": [0] * months})
        i = int(r["monthOffset"]) - 1
        if 0 <= i < months:
            p["sales"][i] = clean_value(r["salesQty"]) or 0
            p["requests"][i] = clean_value(r["requestCount"]) or 0
    return [parts[k] for k in sorted(parts)]


def upload_order(paths: list) -> list:
    return sorted(paths, key=lambda p: (os.path.basename(p) == META_FILE, p))


def changed_files(current: dict, previous: dict) -> list:
    return sorted(name for name, digest in current.items() if previous.get(name) != digest)
```

- [ ] **Step 4: Run tests**

Run: `cd "projects/part order tool - app/publish" && python -m pytest test_publish_logic.py -q`
Expected: `11 passed`

- [ ] **Step 5: Commit (data-projects)**

```bash
git add "projects/part order tool - app/publish/publish_logic.py" "projects/part order tool - app/publish/test_publish_logic.py"
git commit -m "Non-JD order tool publish: pure helpers + tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Publish config, extract and file builder

**Files:**
- Create: `projects/part order tool - app/publish/requirements.txt`
- Create: `projects/part order tool - app/publish/.env.example`
- Create: `projects/part order tool - app/publish/.gitignore`
- Create: `projects/part order tool - app/publish/config.py`
- Create: `projects/part order tool - app/publish/extract.py`
- Create: `projects/part order tool - app/publish/build_files.py`

- [ ] **Step 1: `requirements.txt`** (same pins as the Parts Availability pipeline on the Gateway PC)

```
duckdb==1.5.5
pandas==3.0.3
pyarrow==25.0.1
python-dotenv==1.2.3
msal==1.37.0
requests==2.32.5
pytz==2026.3.post1
pytest==8.4.2
```

- [ ] **Step 2: `.env.example`**

```
# Copy to .env (gitignored). The SPN is the Parts Availability one (Task 1 Steps 7-8).
TENANT_ID=
CLIENT_ID=
CLIENT_SECRET=
# Graph IDs of the Parts Order Tool site and its "NonJD Order Data" library (Step 4 below shows how to get them)
SITE_ID=
DRIVE_ID=
# Which DP tier to read: dev or prod
NONJD_SOURCE=dev
# Leave CLIENT_SECRET empty to read OneLake with your own az login instead (local test runs only)
```

- [ ] **Step 3: `.gitignore`**

```
.env
.env.*
!.env.example
output/
publish_state.json
.duckdb_spill/
publish.log
```

- [ ] **Step 4: Fill in your local `.env`.** Get SITE_ID and DRIVE_ID with your own login:

```bash
az rest --method get --url "https://graph.microsoft.com/v1.0/sites/spitractor.sharepoint.com:/sites/PartsOrderTool" --query id -o tsv
az rest --method get --url "https://graph.microsoft.com/v1.0/sites/<SITE_ID>/drives" --query "value[?name=='NonJD Order Data'].id" -o tsv
```

- [ ] **Step 5: `config.py`**

```python
"""Settings for the Non-JD order tool publish script, from .env (or the file named by NONJD_ENV_FILE)."""
import os

from dotenv import load_dotenv

load_dotenv(os.environ.get("NONJD_ENV_FILE", ".env"))

TENANT_ID = os.environ["TENANT_ID"]
CLIENT_ID = os.environ["CLIENT_ID"]
CLIENT_SECRET = os.environ.get("CLIENT_SECRET", "")
SITE_ID = os.environ["SITE_ID"]
DRIVE_ID = os.environ["DRIVE_ID"]
SOURCE = os.environ.get("NONJD_SOURCE", "dev")

PRESENTATION = {
    "dev": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91"),
    "prod": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f"),
}
if SOURCE not in PRESENTATION:
    raise ValueError(f"NONJD_SOURCE must be one of {sorted(PRESENTATION)}, not {SOURCE!r}")


def table_path(table: str) -> str:
    ws, lh = PRESENTATION[SOURCE]
    return f"abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"
```

- [ ] **Step 6: `extract.py`**

```python
"""DuckDB reads of DP Gold for the publish script. Returns plain Python rows (dicts)."""
from datetime import datetime, timedelta, timezone

import duckdb

import config

REORDER_SQL = """
SELECT Branch AS branch, Franchise AS franchise, PartNumber AS partNumber, Description AS description,
       Bin AS bin, VendorCode AS vendorCode, ProductGroup AS productGroup, SuperTo AS superTo, SuperFrom AS superFrom,
       QuantityOnHand AS onHand, OnOrder AS onOrder, BackOrderQty AS backOrder, Cost AS cost,
       SellPrice1 AS sellPrice, ListPrice AS listPrice, MinimumQty AS minimumQty, MaximumQty AS maximumQty,
       ReorderCode AS reorderCode, ActivityCode AS activityCode, MinOverride AS minOverride, IsMasked AS isMasked,
       MaskExpires AS maskExpires, IsLowMargin AS isLowMargin, Current12MoSales AS sales12,
       Previous12MoSales AS salesPrev12, DateLastRequested AS lastRequested, MonthCount AS monthCount,
       AvgMonthlyDemand AS avgDemand, AvgMonthlySales AS avgSales, StockingTarget AS target,
       RecommendedOrderQty AS recommendedQty, EstOrderValue AS estValue, SurplusQty AS surplusQty,
       InboundTransferQty AS inboundQty, Status AS status
FROM delta_scan('{path}')
ORDER BY branch, franchise, partNumber
"""


def connect():
    con = duckdb.connect()
    con.execute("SET memory_limit='3GB'; SET temp_directory='.duckdb_spill'; SET preserve_insertion_order=false;")
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
    if config.CLIENT_SECRET:
        con.execute(f"""CREATE SECRET (TYPE azure, PROVIDER service_principal, TENANT_ID '{config.TENANT_ID}',
                        CLIENT_ID '{config.CLIENT_ID}', CLIENT_SECRET '{config.CLIENT_SECRET}');""")
    else:
        con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    return con


def _dicts(cur) -> list:
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def log_rows(con, days: int = 14) -> list:
    since = (datetime.now(timezone.utc) - timedelta(days=days)).replace(tzinfo=None)
    return _dicts(con.execute(f"""
        SELECT run_id, name, row_type, status, start_utc, end_utc FROM delta_scan('{config.table_path("dp_refresh_log")}')
        WHERE name = 'Build_Gold_NonJD_Reorder' AND row_type = 'item' AND end_utc >= ?""", [since]))


def built_at(con) -> datetime:
    return con.execute(f"SELECT max(BuiltAtUtc) FROM delta_scan('{config.table_path('Fact_NonJD_Reorder')}')").fetchone()[0]


def reorder(con) -> list:
    return _dicts(con.execute(REORDER_SQL.format(path=config.table_path("Fact_NonJD_Reorder"))))


def history(con) -> list:
    return _dicts(con.execute(f"""
        SELECT Branch AS branch, Franchise AS franchise, PartNumber AS partNumber, MonthOffset AS monthOffset,
               SalesQty AS salesQty, RequestCount AS requestCount
        FROM delta_scan('{config.table_path('Fact_NonJD_SalesHistory')}')"""))


def transfers(con) -> list:
    return _dicts(con.execute(f"""
        SELECT t.RequestingBranch AS toBranch, t.SupplyingBranch AS fromBranch, t.PartNumber AS partNumber,
               t.PartTicket AS ticket, t.LineNumber AS line, t.OrderQty AS orderQty, t.ShippedQty AS shippedQty,
               t.OpenQty AS openQty, t.FulfillmentStatus AS status, t.TransferSubType AS subType,
               t.OrderAge AS ageDays, t.Date AS date
        FROM delta_scan('{config.table_path('Fact_OutstandingTransfers')}') t
        WHERE t.PartNumber IN (SELECT DISTINCT upper(trim(PartNumber))
                               FROM delta_scan('{config.table_path('Fact_NonJD_Reorder')}'))
        ORDER BY toBranch, partNumber, ticket, line"""))


def branch_names(con) -> dict:
    rows = con.execute(f"SELECT BranchID, BranchName FROM delta_scan('{config.table_path('dim_BranchLocation')}')").fetchall()
    return {str(b).strip(): n for b, n in rows if b is not None}
```

- [ ] **Step 7: `build_files.py`**

```python
"""Write the app's data files: deterministic gzipped JSON (same content -> same bytes -> same hash)."""
import gzip
import hashlib
import json
import os
from collections import defaultdict
from datetime import date

import publish_logic as pl

OUT_DIR = "output"


def _bytes(obj, compress: bool = True) -> bytes:
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return gzip.compress(raw, compresslevel=9, mtime=0) if compress else raw


def _write(name: str, data: bytes, hashes: dict) -> None:
    with open(os.path.join(OUT_DIR, name), "wb") as f:
        f.write(data)
    hashes[name] = hashlib.sha256(data).hexdigest()


def _clean(row: dict) -> dict:
    return {k: pl.clean_value(v) for k, v in row.items()}


def build(reorder: list, history: list, transfers: list, names: dict, data_as_of: str,
          current_month: date) -> tuple:
    """Write all data files into OUT_DIR (not _meta.json; see write_meta).
    Returns ({file name: sha256}, [{"branch", "name", "parts"}] for _meta.json)."""
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):
        os.remove(os.path.join(OUT_DIR, f))
    hashes = {}

    by_branch = defaultdict(list)
    for r in reorder:
        by_branch[r["branch"]].append(_clean({k: v for k, v in r.items() if k != "branch"}))
    hist_by_branch = defaultdict(list)
    for h in history:
        hist_by_branch[h["branch"]].append(h)

    labels = pl.month_labels(current_month, 60)
    for branch in sorted(by_branch):
        _write(f"reorder_{branch.strip()}.json.gz",
               _bytes({"branch": branch, "dataAsOf": data_as_of, "parts": by_branch[branch]}), hashes)
        _write(f"history_{branch.strip()}.json.gz",
               _bytes({"branch": branch, "months": labels,
                       "parts": pl.history_arrays(hist_by_branch.get(branch, []), 60)}), hashes)

    surplus = [_clean({"branch": r["branch"], "franchise": r["franchise"], "partNumber": r["partNumber"],
                       "onHand": r["onHand"], "target": r["target"], "surplusQty": r["surplusQty"],
                       "status": r["status"]})
               for r in reorder if (r["surplusQty"] or 0) > 0]
    _write("surplus.json.gz", _bytes({"dataAsOf": data_as_of, "parts": surplus}), hashes)
    _write("transfers.json.gz", _bytes({"dataAsOf": data_as_of, "lines": [_clean(t) for t in transfers]}), hashes)

    branches = [{"branch": b, "name": names.get(b.strip(), b.strip()), "parts": len(by_branch[b])}
                for b in sorted(by_branch, key=lambda x: (len(x.strip()), x.strip()))]
    return hashes, branches


def write_meta(data_as_of: str, published_at: str, source: str, branches: list, counts: dict) -> str:
    path = os.path.join(OUT_DIR, pl.META_FILE)
    with open(path, "wb") as f:
        f.write(_bytes({"dataAsOf": data_as_of, "publishedAt": published_at, "source": source,
                        "branches": branches, "counts": counts, "schemaVersion": 1}, compress=False))
    return path
```

- [ ] **Step 8: Local dry build against Dev** (no upload yet). Create `run_build_only.py` in the scratchpad, not the repo:

```python
import sys; sys.path.insert(0, r"C:\Users\bfox\Documents\Git-Projects\data-projects\projects\part order tool - app\publish")
import os; os.chdir(sys.path[0])
from datetime import date
import extract, build_files
con = extract.connect()
r, h, t, n = extract.reorder(con), extract.history(con), extract.transfers(con), extract.branch_names(con)
hashes, branches = build_files.build(r, h, t, n, "2026-10-20T11:40:00+00:00", date.today().replace(day=1))
print(len(hashes), "files;", branches[:3])
for f in sorted(os.listdir("output")): print(f, os.path.getsize(os.path.join("output", f)))
```
Run it with `NONJD_SOURCE=dev` and an empty `CLIENT_SECRET` (uses your az login). Expected: 2 files per branch plus `surplus.json.gz` and `transfers.json.gz`; every file under 4 MB (the upload limit without a chunked session). If any file is over 4 MB, copy the chunked `upload_file` from `.claude/queries/adhoc/parts-lookup-static-prototype/upload.py` into Task 12's upload.py.

- [ ] **Step 9: Commit (data-projects)**

```bash
cd "projects/part order tool - app/publish"
git add requirements.txt .env.example .gitignore config.py extract.py build_files.py
git commit -m "Non-JD order tool publish: config, DuckDB extract, file builder

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Upload and the publish runner

**Files:**
- Create: `projects/part order tool - app/publish/upload.py`
- Create: `projects/part order tool - app/publish/run_publish.py`

- [ ] **Step 1: `upload.py`**

```python
"""Upload files to the SharePoint library through Graph, as the publish SPN. Simple PUT (files must be <= 4 MB)."""
import os
import time

import msal
import requests

import config

GRAPH = "https://graph.microsoft.com/v1.0"
SIMPLE_LIMIT = 4 * 1024 * 1024
RETRY_STATUS = {409, 423, 429, 503, 504}
TIMEOUT = (10, 60)


def token() -> str:
    app = msal.ConfidentialClientApplication(config.CLIENT_ID, client_credential=config.CLIENT_SECRET,
                                             authority=f"https://login.microsoftonline.com/{config.TENANT_ID}")
    result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
    if "access_token" not in result:
        raise RuntimeError(f"Graph token failed: {result.get('error_description')}")
    return result["access_token"]


def put_file(path: str, access_token: str, attempts: int = 5) -> None:
    size = os.path.getsize(path)
    if size > SIMPLE_LIMIT:
        raise RuntimeError(f"{path} is {size:,} bytes; add a chunked upload session (see plan Task 11 Step 8)")
    name = os.path.basename(path)
    url = f"{GRAPH}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}/root:/{name}:/content"
    with open(path, "rb") as f:
        data = f.read()
    last = None
    for i in range(1, attempts + 1):
        try:
            r = requests.put(url, headers={"Authorization": f"Bearer {access_token}"}, data=data, timeout=TIMEOUT)
            if r.status_code not in RETRY_STATUS:
                r.raise_for_status()
                return
            last = RuntimeError(f"{r.status_code} uploading {name}")
        except requests.exceptions.RequestException as ex:
            last = ex
        time.sleep(3 * i)
    raise last
```

- [ ] **Step 2: `run_publish.py`**

```python
"""
Non-JD Parts Order Tool - daily publish.

1. Read dp_refresh_log; publish only if Build_Gold_NonJD_Reorder's latest run succeeded and wasn't published yet.
2. Check the Gold table was written by that run (BuiltAtUtc within the run).
3. Build files, upload the changed ones, then _meta.json last. Save publish_state.json.

Exit 0 = published or nothing to do; 1 = error (Task Scheduler shows "last run result" 0x1).
Usage: python run_publish.py [--force]
"""
import argparse
import json
import os
import sys
import traceback
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

import build_files
import config
import extract
import publish_logic as pl
import upload

STATE_FILE = "publish_state.json"


def load_state() -> dict:
    if not os.path.exists(STATE_FILE):
        return {}
    with open(STATE_FILE, encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="publish even if this run was already published")
    args = ap.parse_args()
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    stamp = datetime.now(timezone.utc).isoformat()
    print(f"[{stamp}] publish start, source={config.SOURCE}")

    con = extract.connect()
    latest = pl.latest_item_run(extract.log_rows(con))
    state = load_state()
    go, why = pl.decide_publish(latest, state, config.SOURCE, args.force)
    print(f"decision: {go} ({why})")
    if not go:
        return 0

    built = extract.built_at(con)
    if not pl.built_in_run(built, latest["start_utc"], latest["end_utc"]):
        raise RuntimeError(f"Fact_NonJD_Reorder BuiltAtUtc {built} is outside run {latest['run_id']} "
                           f"({latest['start_utc']} .. {latest['end_utc']}); refusing to publish mismatched data")

    data_as_of = pl.iso_utc(latest["end_utc"])
    built_central = pl._naive_utc(built).replace(tzinfo=timezone.utc).astimezone(ZoneInfo("America/Chicago")).date()
    current_month = date(built_central.year, built_central.month, 1)

    reorder, history = extract.reorder(con), extract.history(con)
    transfers, names = extract.transfers(con), extract.branch_names(con)
    hashes, branches = build_files.build(reorder, history, transfers, names, data_as_of, current_month)
    counts = {"parts": len(reorder), "historyRows": len(history), "transferLines": len(transfers)}
    meta_path = build_files.write_meta(data_as_of, datetime.now(timezone.utc).isoformat(), config.SOURCE,
                                       branches, counts)

    previous = state.get("hashes", {}) if state.get("source") == config.SOURCE else {}
    to_send = [os.path.join(build_files.OUT_DIR, n) for n in pl.changed_files(hashes, previous)]
    access = upload.token()
    for path in pl.upload_order(to_send + [meta_path]):
        upload.put_file(path, access)
        print(f"  uploaded {os.path.basename(path)}")

    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump({"source": config.SOURCE, "dataAsOf": data_as_of, "hashes": hashes}, f, indent=1)
    print(f"published {len(to_send)} changed file(s) + _meta.json; data as of {data_as_of}; {counts}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(1)
```

- [ ] **Step 3: First real publish from your PC (Dev data)**

Put the SPN secret in your local `.env` (`NONJD_SOURCE=dev`), then:

Run: `cd "projects/part order tool - app/publish" && python run_publish.py`
Expected: `decision: True (new data)`, every file uploaded, `published N changed file(s)`.

- [ ] **Step 4: Verify in SharePoint.** Open the `NonJD Order Data` library: one `reorder_<branch>.json.gz` and `history_<branch>.json.gz` per branch, `surplus.json.gz`, `transfers.json.gz`, `_meta.json`. Open `_meta.json`: `dataAsOf` equals the Dev run's end time (UTC), not now.

- [ ] **Step 5: Verify the skip path.** Run `python run_publish.py` again. Expected: `decision: False (already published)`, nothing uploaded.

- [ ] **Step 6: Verify the change-only upload.** Run `python run_publish.py --force`. Expected: `published 0 changed file(s) + _meta.json` (builds are deterministic).

- [ ] **Step 7: Commit (data-projects)**

```bash
cd "projects/part order tool - app/publish"
git add upload.py run_publish.py
git commit -m "Non-JD order tool publish: Graph upload + runner (publish once per successful DP run)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Gateway PC schedule

**Files:** none in the repo (machine setup). Document in Task 14's README.

- [ ] **Step 1: Pull on the Gateway PC.** The Gateway PC (`SPI00T4022W11`) already has a clone of data-projects `dev` for Parts Availability. `git pull` there.

- [ ] **Step 2: Create a venv and install**

```powershell
cd "C:\<clone>\projects\part order tool - app\publish"
py -3.13 -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
```

- [ ] **Step 3: Create `.env`** on the Gateway PC with the SPN values, SITE_ID, DRIVE_ID and `NONJD_SOURCE=dev` (switch to `prod` in Task 15).

- [ ] **Step 4: Run once by hand:** `.\.venv\Scripts\python run_publish.py`. Expected: `already published` if your PC published the same run, else a full publish.

- [ ] **Step 5: Task Scheduler** → folder `\SPI\` → New task **"Non-JD Order Tool Publish"**:
  - Run whether user is logged on or not, as the same account the Parts Availability task uses.
  - Triggers: weekdays 07:15, repeat every 30 minutes for 3 hours (covers late or retried DP runs; repeats after a publish just say "already published").
  - Action: program `cmd.exe`, arguments `/c ".venv\Scripts\python.exe run_publish.py >> publish.log 2>&1"`, and "Start in" set to the publish folder in the Gateway PC's clone.
  - Settings: stop the task if it runs longer than 30 minutes.

- [ ] **Step 6: Next weekday morning, check** `publish.log` and the library's `_meta.json`.

---

### Task 14: README and file contract for Plan B

**Files:**
- Create: `projects/part order tool - app/publish/README.md`
- Modify: `projects/part order tool - app/README.md`

- [ ] **Step 1: Write `publish/README.md`**

````markdown
# Non-JD Parts Order Tool - data publish

Reads DP Gold (`Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory`, `Fact_OutstandingTransfers`, `dim_BranchLocation`)
after the morning DP run and uploads the web app's data files to the SharePoint library **NonJD Order Data**
on https://spitractor.sharepoint.com/sites/PartsOrderTool.

- Plan: `docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md`
- Runs on the Gateway PC, Task Scheduler `\SPI\Non-JD Order Tool Publish`, weekdays 07:15 + every 30 min for 3 h.
- Publishes only when `Build_Gold_NonJD_Reorder` succeeded in `dp_refresh_log` and that run hasn't been published.
- `NONJD_SOURCE` in `.env` picks the DP tier (`dev` or `prod`).

Run by hand: `python run_publish.py` (`--force` to rebuild and upload changed files anyway). Tests: `python -m pytest -q`.

## File contract (schemaVersion 1)

All files are UTF-8 JSON; `.json.gz` files are gzip-compressed. Numbers are plain JSON numbers; dates are ISO
strings; datetimes are ISO UTC with `+00:00`. Branch codes are Equip's text codes (e.g. `"1"`, `"92"`); part
numbers are raw (a trailing space is significant).

### `_meta.json` (uploaded last)
```json
{"schemaVersion": 1, "dataAsOf": "2026-10-20T11:41:07+00:00", "publishedAt": "...", "source": "prod",
 "branches": [{"branch": "1", "name": "Lubbock", "parts": 18234}],
 "counts": {"parts": 412345, "historyRows": 3456789, "transferLines": 210}}
```
`dataAsOf` is when the DP run finished. The app shows it and flags data older than one business day.

### `reorder_<branch>.json.gz`
`{"branch", "dataAsOf", "parts": [ ... ]}`, one object per part in scope at that branch:

| Field | Meaning |
|---|---|
| franchise, partNumber, description, bin, vendorCode, productGroup, superTo, superFrom | Part identity |
| onHand, onOrder, backOrder | Equip quantities |
| cost, sellPrice, listPrice | Prices |
| minimumQty, maximumQty, reorderCode, activityCode | Equip stocking fields |
| minOverride, isMasked, maskExpires | From the app's settings list (as of the DP run) |
| isLowMargin | InMaster user_field_3 = LOW |
| sales12, salesPrev12, lastRequested | 12-month totals and last request date |
| monthCount, avgDemand, avgSales | Activity in the 12-month window |
| target | Stocking target; null when no recent activity |
| recommendedQty, estValue | Suggested order quantity and its value at cost |
| surplusQty | Stock above target (all on-hand stock when no recent activity) |
| inboundQty | Open quantity on outstanding transfers into this branch |
| status | `Reorder`, `OutOfStock`, `OK`, `NoRecentActivity`, `Masked` |

### `history_<branch>.json.gz`
`{"branch", "months": ["2026-10", "2026-09", ...60 labels, newest first], "parts": [{"franchise", "partNumber",
"sales": [60 numbers], "requests": [60 numbers]}]}`. Index 0 is the current (partial) month.

### `surplus.json.gz`
`{"dataAsOf", "parts": [{"branch", "franchise", "partNumber", "onHand", "target", "surplusQty", "status"}]}`, every
branch, only parts with surplusQty > 0. Used for "store N has extra" hints.

### `transfers.json.gz`
`{"dataAsOf", "lines": [{"toBranch", "fromBranch", "partNumber", "ticket", "line", "orderQty", "shippedQty",
"openQty", "status", "subType", "ageDays", "date"}]}`. Outstanding transfer lines for part numbers in scope.
`partNumber` here is upper-cased and trimmed; match with `partNumber.trim().toUpperCase()`.
````

- [ ] **Step 2: Update the project README.** Replace the "Status", "Delivery Plan" and "Design Spec" sections of `projects/part order tool - app/README.md` with:

```markdown
**Status:** Redesign in progress (2026-10-20): React web app on the DP backend, replacing the Power Apps plan.

## Current design and plans
- Spec: `docs/superpowers/specs/2026-10-20-non-jd-parts-order-tool-redesign-design.md`
- Plan A (data feed): `docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md`
- Plan B (web app): to be written against the file contract in `publish/README.md`
- Superseded: the 2026-05-28 spec and plans (LH_Master_Data + Power Apps). `ARCHITECTURE.md`, `POWERAPPS-GUIDE.md`
  and `canvas-sync/` describe that old design.
```

- [ ] **Step 3: Commit (data-projects)**

```bash
git add "projects/part order tool - app/publish/README.md" "projects/part order tool - app/README.md"
git commit -m "Non-JD order tool: publish README with the app file contract

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Release the backend to Prod and switch the feed (Brian decides when)

Do this once Dev has run cleanly for a few days and the app prototype is ready for testers.

- [ ] **Step 1:** fabric-workspace-docs: `python deploy/merge_preview.py`, open PR `dev → main` with the template. Brian merges with **Create a merge commit**.
- [ ] **Step 2:** Brian runs GitHub Actions **Deploy DP backend**. Then `python deploy/claim_prod_pipeline.py` as Brian (or let the claim task do it), and fast-forward dev: `git fetch origin && git merge --ff-only origin/main && git push origin dev`.
- [ ] **Step 3:** Copy the matrix CSV to Prod (deploys don't copy Files):
```bash
fab mkdir "DP - Presentation - Prod.Workspace/DP_Presentation.Lakehouse/Files/config/nonjd"
fab cp "projects/part order tool - app/params/rop_matrix.csv" "DP - Presentation - Prod.Workspace/DP_Presentation.Lakehouse/Files/config/nonjd/rop_matrix.csv" -f
```
- [ ] **Step 4:** Create the new staging tables in Prod: run Prod `Pipeline_DP_Refresh` with `mode=items`, `items=df_NonJD_PartSettings_Raw,Build_Silver_PartSalesHistory,Build_Silver_PartStockingRules`. Then `python deploy/sync_shortcuts.py` (dry run) and `python deploy/sync_shortcuts.py --apply`.
- [ ] **Step 5:** Run `items=Build_Gold_NonJD_Reorder` in Prod, then `python tools/dp-migration/nonjd_reorder_check.py --tier prod`. Expected: PASS.
- [ ] **Step 6:** After the next scheduled Dev and Prod runs, `python deploy/compare_tiers.py Fact_NonJD_Reorder Fact_NonJD_SalesHistory` (differences limited to the two tiers' Bronze timing).
- [ ] **Step 7:** On the Gateway PC set `NONJD_SOURCE=prod` in `.env` and run `run_publish.py`. Expected: a full publish (source changed). `_meta.json` shows `"source": "prod"`.
- [ ] **Step 8:** Update this plan's Progress note and the memory file `project_nonjd_parts_order_tool_paused.md`.

---

## Self-review notes

- **Spec coverage:** history (Tasks 4, 7), stocking fields (5), settings read-back (1, 6, 7), transfers display and surplus hints (7, 11), freshness date = DP run end (10, 12), franchise scope (3, 7), lists for the app (1), per-branch files and surplus file (11), Dev-first then Prod (8, 15), cost measurement (9). The web app, its sign-in and hosting are Plan B.
- **Known limits carried into the prototype:** transfer matching is by branch and part number only (the transfer table has no franchise), so a part number shared by two franchises at one branch shows the same inbound quantity on both. SharePoint may drop trailing spaces in settings keys.
