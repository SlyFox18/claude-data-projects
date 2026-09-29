"""Task 4A Steps 1-2: build the read-only cadence review table for the DP refresh DAG.

For every item in fabric-workspace-docs/deploy/dp_refresh_dag.json, gathers (all read-only against
Fabric -- GETs only):
  - Reads: DP-produced tables it depends on (mapped via each dependency's `produces`), plus
    external/Bronze reads found by re-scanning the notebook source and keeping only names that look
    like real tables (a `Files/` CSV read is called out separately, not folded into this list).
  - Static?: True only when the notebook has no real reads at all (Build_Gold_DateTable is the
    expected case). A notebook that reads only a Files/ CSV (Build_Gold_EngagedAcres) is flagged
    separately, not marked static.
  - Median run (s) / Runs seen: from Completed job instances (RunNotebook / dataflow Refresh) in the
    last 60 days.
  - Downstream items: count of other items whose transitive dependsOn closure includes this item.
  - Reports: report models whose table list directly includes one of this item's produced tables.
  - Current cadence source: "old config" if the item's name is in the old deploy/dp_backend_scope.json
    notebooks list, else "defaulted" (45 notebooks were never in the old scope and defaulted to daily).

Writes docs/architecture/dp-refresh-cadence-review.md with the Recommendation and Brian's decision
columns left empty for the controller (Task 4A Steps 3-4) to fill in.

Usage: python cadence_review.py
"""
import json
import re
import statistics
import subprocess
import sys
import urllib.parse
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

FABRIC_DOCS = Path(r"C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs")
DATA_PROJECTS = Path(r"C:\Users\bfox\Documents\Git-Projects\data-projects")
OUT_MD = DATA_PROJECTS / "docs" / "architecture" / "dp-refresh-cadence-review.md"

sys.path.insert(0, str(FABRIC_DOCS / "deploy"))
from dag_config import load_config, _closure  # noqa: E402
from dag_scan import scan_notebooks, READ_PATTERNS  # noqa: E402

STAGING = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
PRESENTATION = "73fd5443-240e-410a-990a-98827f32c087"
WORKSPACE_ID = {"staging": STAGING, "presentation": PRESENTATION}

LOOKBACK_DAYS = 60

# Words the FROM/JOIN regex (and stray matches) pick up that are not real table names: Python/SQL
# keywords, module names, and common English words that show up in comments/imports.
NOISE_WORDS = {
    "the", "this", "that", "with", "from", "import", "select", "where", "group", "order", "by", "as",
    "on", "when", "case", "then", "else", "and", "or", "not", "in", "is", "of", "for", "into", "join",
    "having", "left", "right", "inner", "outer", "full", "cross", "distinct", "count", "sum", "avg",
    "max", "min", "cast", "true", "false", "null", "none", "def", "class", "return", "print", "if",
    "elif", "while", "try", "except", "lambda", "yield", "spark", "df", "dbutils", "notebookutils",
    "pyspark", "datetime", "delta", "json", "re", "os", "sys", "pandas", "numpy", "functions", "types",
    "window", "sql", "table", "tables", "data", "file", "files", "int", "str", "float", "bool", "dict",
    "list", "set", "tuple", "self", "value", "values", "column", "columns", "row", "rows",
}

FILES_READ_PATTERN = re.compile(r'["\'][^"\']*Files/[^"\']*["\']')


def _code_original_case(src: str) -> str:
    return "\n".join(line for line in src.splitlines() if not line.lstrip().startswith("#"))


def raw_read_candidates(src: str) -> set:
    """Same READ_PATTERNS as dag_scan, but case preserved (dag_scan.scan_notebooks lower-cases)."""
    code = _code_original_case(src)
    return {m for p in READ_PATTERNS for m in re.findall(p, code)}


def looks_like_table(name: str) -> bool:
    return bool(name) and (name[0].isupper() or "_" in name) and name.lower() not in NOISE_WORDS


def api(path):
    """Call `fab api <path>` and return its parsed 'text' body. Raises on non-2xx (copied from
    tools/dp-migration/proto_measure.py's api())."""
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    resp = None
    i = out.find("{")
    if i >= 0:
        try:
            resp = json.loads(out[i:])
        except json.JSONDecodeError:
            resp = None
    if resp is None:
        for line in out.splitlines():
            if line.startswith("{"):
                try:
                    resp = json.loads(line)
                    break
                except json.JSONDecodeError:
                    continue
    if resp is None:
        raise RuntimeError(f"fab api {path}: no parseable JSON in output:\n{out}")
    status = resp.get("status_code")
    if not isinstance(status, int) or not (200 <= status <= 299):
        text = resp.get("text")
        err = text.get("errorCode") if isinstance(text, dict) else None
        msg = text.get("message") if isinstance(text, dict) else None
        raise RuntimeError(f"fab api {path}: status_code={status} errorCode={err} message={msg}")
    return resp.get("text", {})


def api_list(path):
    """All `value` items from a Fabric API list endpoint, following continuationToken (copied from
    proto_measure.py's api_list())."""
    base = path
    page_path = path
    values = []
    while True:
        resp = api(page_path)
        values.extend(resp.get("value", []))
        token = resp.get("continuationToken")
        if not token:
            break
        sep = "&" if "?" in base else "?"
        page_path = f"{base}{sep}continuationToken={urllib.parse.quote(token)}"
    return values


def ts(s):
    if not s:
        return None
    return datetime.fromisoformat(s.rstrip("Z").split("+")[0][:26])


def median_run_seconds(workspace_id: str, item_id: str, cutoff: datetime):
    """(median seconds or None, run count) over Completed job instances since `cutoff` (naive UTC)."""
    try:
        jobs = api_list(f"workspaces/{workspace_id}/items/{item_id}/jobs/instances")
    except RuntimeError as e:
        print(f"  ! job history fetch failed for {item_id}: {e}")
        return None, 0
    durations = []
    for j in jobs:
        if j.get("status") != "Completed":
            continue
        start, end = ts(j.get("startTimeUtc")), ts(j.get("endTimeUtc"))
        if start is None or end is None or start < cutoff:
            continue
        durations.append((end - start).total_seconds())
    if not durations:
        return None, 0
    return round(statistics.median(durations), 1), len(durations)


def main():
    config = load_config()
    items = config["items"]
    by_name = {i["name"]: i for i in items}

    old_scope = json.loads((FABRIC_DOCS / "deploy" / "dp_backend_scope.json").read_text(encoding="utf-8"))
    old_names = {n["name"] for n in old_scope["notebooks"]}

    notebook_scan = scan_notebooks(FABRIC_DOCS)

    print("Resolving item IDs...")
    id_by_name = {}
    for ws_logical, ws_id in WORKSPACE_ID.items():
        for it in api_list(f"workspaces/{ws_id}/items?type=Notebook"):
            id_by_name[(ws_logical, it["displayName"])] = it["id"]
    for it in api_list(f"workspaces/{STAGING}/items?type=Dataflow"):
        id_by_name[("staging", it["displayName"])] = it["id"]

    missing_ids = [i["name"] for i in items if (i["workspace"], i["name"]) not in id_by_name]
    if missing_ids:
        print(f"WARNING: {len(missing_ids)} item(s) with no matching Fabric item: {missing_ids}")

    # All tables any item produces (any case), for classifying a raw read as "DP-produced" vs external.
    all_produced_lower = {t.lower() for i in items for t in i["produces"]}
    # producer: table (lower) -> item name (for downstream/report lookups elsewhere if needed)
    producer = {t.lower(): i["name"] for i in items for t in i["produces"]}

    # Precompute each item's upstream closure once, then invert for downstream counts.
    closures = {name: _closure(by_name, name) for name in by_name}
    downstream_count = {
        name: sum(1 for other, up in closures.items() if other != name and name in up)
        for name in by_name
    }

    cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=LOOKBACK_DAYS)

    rows = []
    n_with_history = 0
    print(f"Querying job history since {cutoff.isoformat()} UTC for {len(items)} items...")
    for idx, item in enumerate(items, 1):
        name = item["name"]
        ws_logical = item["workspace"]
        item_id = id_by_name.get((ws_logical, name))
        print(f"  [{idx}/{len(items)}] {name}", end=" ")

        # --- Reads ---
        dep_tables = set()
        for dep in item["dependsOn"]:
            dep_tables |= set(by_name[dep]["produces"])
        own_lower = {p.lower() for p in item["produces"]}
        ignore_lower = {t.lower() for t in item.get("scanIgnore", [])}

        files_read = []
        external = set()
        notes = []

        if item["type"] == "notebook":
            scan = notebook_scan.get(name)
            if scan is None:
                notes.append("notebook not found by scanner")
            else:
                src = (FABRIC_DOCS / scan["path"] / "notebook-content.py").read_text(encoding="utf-8")
                raw = raw_read_candidates(src) | set(item.get("extraReads", []))
                # spark.(read.)table("x") literals are certain table reads whatever their case
                # (e.g. Bronze "contact"); the noise filter only needs to police FROM/JOIN words.
                explicit = set(re.findall(READ_PATTERNS[0], _code_original_case(src)))
                for cand in raw:
                    low = cand.lower()
                    if low in own_lower or low in ignore_lower or low in all_produced_lower:
                        continue
                    if cand in explicit or looks_like_table(cand):
                        external.add(cand)
                files_read = sorted(set(FILES_READ_PATTERN.findall(_code_original_case(src))))
        else:  # dataflow: pulls from the ODBC source system, no notebook code to scan
            external = set()
            notes.append("dataflow: ODBC source, not scanned")

        reads_parts = sorted(dep_tables) + sorted(external)
        if files_read:
            notes.append(f"reads Files/ CSV: {', '.join(f.strip(chr(34)+chr(39)) for f in files_read)}")

        if item["type"] == "dataflow":
            reads_display = "external ODBC source (not scanned)"
            static = "No"
        elif reads_parts:
            reads_display = ", ".join(reads_parts) + (" *" if external else "")
            static = "No"
        elif files_read:
            reads_display = "(no table reads) " + "; ".join(notes)
            static = "No (Files/ CSV)"
        else:
            reads_display = "(none)"
            static = "Yes"

        # --- Median run / runs seen ---
        if item_id:
            median_s, runs = median_run_seconds(WORKSPACE_ID[ws_logical], item_id, cutoff)
        else:
            median_s, runs = None, 0
            notes.append("no matching Fabric item id")
        if runs:
            n_with_history += 1
        print(f"-> median={median_s} runs={runs}")

        # --- Reports ---
        reports_using = sorted(
            r["model"] for r in config["reports"]
            if {t.lower() for t in r["tables"]} & own_lower
        )

        rows.append({
            "name": name,
            "tier": item["tier"],
            "cadence": item["cadence"],
            "cadence_source": "old config" if name in old_names else "defaulted",
            "reads": reads_display,
            "static": static,
            "median_s": median_s,
            "runs": runs,
            "downstream": downstream_count[name],
            "reports": ", ".join(reports_using) if reports_using else "",
            "notes": "; ".join(notes),
        })

    tier_order = {"staging": 0, "silver": 1, "gold": 2}
    rows.sort(key=lambda r: (tier_order.get(r["tier"], 9), r["name"]))

    static_names = [r["name"] for r in rows if r["static"] == "Yes"]
    csv_note_names = [r["name"] for r in rows if r["static"].startswith("No (Files")]

    lines = []
    lines.append("# DP Refresh Cadence Review")
    lines.append("")
    lines.append(
        f"Generated by `tools/dp-migration/cadence_review.py` "
        f"({datetime.now(timezone.utc).strftime('%Y-%m-%d')})."
    )
    lines.append("")
    lines.append(
        "This table exists so Brian can set each producer's refresh cadence deliberately instead of "
        "everything defaulting to daily. For every item in `deploy/dp_refresh_dag.json` it shows what "
        "the item currently reads and produces, how often it's actually run in the last "
        f"{LOOKBACK_DAYS} days, how many other items and reports sit downstream of it, and whether the "
        "old `dp_backend_scope.json` ever assigned it a cadence at all (45 of the 98 notebooks never "
        "were in that file and simply defaulted to daily when this config was bootstrapped)."
    )
    lines.append("")
    lines.append(
        "**How to read it:** `Reads` lists DP-produced tables this item depends on (resolved from its "
        "`dependsOn`) plus external/Bronze source tables found by re-scanning the notebook code -- "
        "external reads are marked with `*`. `Static?` is `Yes` only when the notebook has no real "
        "table reads at all (e.g. a fixed calendar); a notebook that reads only a `Files/` CSV is called "
        "out separately rather than marked static, since the CSV's contents can still change. "
        "`Median run (s)` / `Runs seen` come from Completed job instances in the Fabric job history over "
        f"the last {LOOKBACK_DAYS} days -- `\u2014` means no completed runs were found in that window. "
        "`Downstream items` is the count of other items whose dependency chain includes this one. "
        "`Reports` lists report models that read a table this item produces directly (not "
        "transitively). The scanner's read-detection is regex-based and a few noise words can slip "
        "through as spurious external reads; treat `Reads` as a strong hint, not ground truth -- see the "
        "caveats at the bottom."
    )
    lines.append("")
    lines.append(
        "**Recommendation** and **Brian's decision** are left empty here for Task 4A Steps 3-4 "
        "(controller + Brian)."
    )
    lines.append("")
    lines.append(
        "| Item | Tier | Current cadence | Current cadence source | Reads | Static? | Median run (s) | "
        "Runs seen | Downstream items | Reports | Recommendation | Brian's decision |"
    )
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        median_display = r["median_s"] if r["median_s"] is not None else "\u2014"
        reads_cell = r["reads"].replace("|", "\\|")
        reports_cell = r["reports"].replace("|", "\\|")
        lines.append(
            f"| {r['name']} | {r['tier']} | {r['cadence']} | {r['cadence_source']} | {reads_cell} | "
            f"{r['static']} | {median_display} | {r['runs']} | {r['downstream']} | {reports_cell} | | |"
        )
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append(f"- {len(rows)} items reviewed ({sum(1 for r in rows if r['runs'] > 0)} have run "
                  f"history in the last {LOOKBACK_DAYS} days).")
    lines.append(f"- Static (no reads at all): {', '.join(static_names) if static_names else 'none'}.")
    lines.append(f"- Reads only a `Files/` CSV, not a table: "
                  f"{', '.join(csv_note_names) if csv_note_names else 'none'}.")
    lines.append(
        "- Reads marked `*` are external/Bronze source tables (found by re-scanning notebook source "
        "for `spark.read.table(...)` / `FROM`/`JOIN` patterns and keeping only names that look like real "
        "tables -- start with a capital letter or contain an underscore, and aren't a Python/SQL keyword "
        "or module name). A handful of stray matches (e.g. local variable or alias names that happen to "
        "look table-like) can still slip through; spot-check before trusting an unfamiliar name."
    )
    lines.append(
        "- Dataflow items (`df_RepairOrderDetail_Raw`, `df_InSalPar_Audit_Raw`) pull directly from the "
        "ODBC source system, so there's no notebook code to scan for reads."
    )
    for r in rows:
        if r["notes"]:
            lines.append(f"- {r['name']}: {r['notes']}")

    OUT_MD.parent.mkdir(parents=True, exist_ok=True)
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\nWrote {OUT_MD} ({len(rows)} rows).")


if __name__ == "__main__":
    main()
