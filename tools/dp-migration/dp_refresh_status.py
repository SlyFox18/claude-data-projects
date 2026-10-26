"""Read-only DP refresh status: recent Pipeline_DP_Refresh runs and what the latest one reported.

Usage: python dp_refresh_status.py [prod|dev] [--runs N]
  --runs N  how many recent pipeline runs to list (default 5)

The detail comes from the Finish notebook's exit value (the summary the refresh email is built
from), read through the pipeline's activity runs. That takes seconds; reading dp_refresh_log with
DuckDB takes minutes because the table is ~1,300 small files.
A pipeline run shows Completed even when items failed (Fail activities fire only on orchestrator
crashes), so the summary status is what matters.
Exit codes: 0 latest run ok, 1 failed/partial/problems, 2 in progress, no runs, or no summary.
"""
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"

# DP - Presentation workspace per tier (lakehouse IDs kept for DuckDB reads)
PRESENTATION = {
    "dev": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91"),
    "prod": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f"),
}
PIPELINE = "Pipeline_DP_Refresh"
OK = {"Completed", "Succeeded"}


def fab_api(path, method=None, body=None):
    cmd = ["fab", "api", path] + (["-X", method] if method else [])
    tmp = None
    if body is not None:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(body, tmp)
        tmp.close()
        cmd += ["-i", tmp.name]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    finally:
        if tmp:
            os.unlink(tmp.name)
    start = out.find("{")
    return json.loads(out[start:]) if start >= 0 else {"raw": out[-800:]}


def pipeline_id(ws):
    items = fab_api(f"workspaces/{ws}/items?type=DataPipeline").get("text", {}).get("value", [])
    for it in items:
        if it.get("displayName") == PIPELINE:
            return it["id"]
    sys.exit(f"{PIPELINE} not found in workspace {ws}")


def runs(ws, item, n):
    vals = fab_api(f"workspaces/{ws}/items/{item}/jobs/instances").get("text", {}).get("value", [])
    vals.sort(key=lambda r: r.get("startTimeUtc") or "", reverse=True)
    return vals[:n]


def finish_summary(ws, run_id):
    """The Finish notebook's exit value: the same summary the refresh email is built from (None if absent)."""
    body = {"filters": [], "orderBy": [{"orderBy": "ActivityRunStart", "order": "ASC"}],
            "lastUpdatedAfter": "2026-01-01T00:00:00Z", "lastUpdatedBefore": "2099-01-01T00:00:00Z"}
    acts = fab_api(f"workspaces/{ws}/datapipelines/pipelineruns/{run_id}/queryactivityruns", "post", body)
    for a in acts.get("text", {}).get("value", []):
        if a.get("activityName") == "Finish":
            ev = ((a.get("output") or {}).get("result") or {}).get("exitValue")
            try:
                return json.loads(ev) if ev else None
            except ValueError:
                return {"teams_text": str(ev)[:1000]}
    return None


def minutes(r):
    if not (r.get("startTimeUtc") and r.get("endTimeUtc")):
        return None
    f = lambda s: datetime.fromisoformat(s[:26].rstrip("Z")).replace(tzinfo=timezone.utc)
    return round((f(r["endTimeUtc"]) - f(r["startTimeUtc"])).total_seconds() / 60)


def problems(summary):
    """Lines for every item/model that didn't succeed, plus warnings and Bronze problems."""
    out = []
    for kind in ("items", "models"):
        for name, v in sorted((summary.get(kind) or {}).items()):
            st = v.get("status")
            if st not in OK:
                why = v.get("error") or (f"skipped because {v['skipped_because']}" if v.get("skipped_because") else "")
                out.append(f"  [{kind[:-1]}] {name}: {st}" + (f" | {str(why)[:300]}" if why else ""))
    for w in summary.get("warnings") or []:
        out.append(f"  [warning] {str(w)[:300]}")
    for b in summary.get("bronze_problems") or []:
        out.append(f"  [bronze] {str(b)[:300]}")
    if summary.get("error"):
        out.append(f"  [error] {str(summary['error'])[:500]}")
    return out


def main(argv):
    sys.stdout.reconfigure(encoding="utf-8")
    args, n = list(argv), 5
    if "--runs" in args:
        i = args.index("--runs")
        value = args[i + 1] if i + 1 < len(args) else ""
        if not value.isdigit() or int(value) < 1:
            sys.exit("--runs needs a whole number of 1 or more")
        n = int(value)
        del args[i:i + 2]
    if len(args) > 1 or (args and args[0] not in PRESENTATION):
        sys.exit(f"unknown argument(s) {args}; usage: dp_refresh_status.py [prod|dev] [--runs N]")
    tier = args[0] if args else "prod"
    ws = PRESENTATION[tier][0]
    recent = runs(ws, pipeline_id(ws), n)
    if not recent:
        print(f"{tier}: no {PIPELINE} runs found")
        return 2
    print(f"{PIPELINE} ({tier}), latest first. Times UTC (Central = UTC-5 in CDT, UTC-6 in CST):")
    for r in recent:
        mins = minutes(r)
        print(f"  {r.get('startTimeUtc', '')[:16]}  {r.get('status', ''):<11} {r.get('invokeType', ''):<9}"
              f" {(str(mins) + ' min') if mins is not None else '':>7}")
        msg = (r.get("failureReason") or {}).get("message")
        if msg:
            print(f"      failure: {msg[:300]}")
    latest = recent[0]
    if latest.get("status") in ("NotStarted", "InProgress"):
        print("\nLatest run is still in progress.")
        return 2
    summary = finish_summary(ws, latest["id"])
    if summary is None:
        print("\nLatest run has no Finish summary (it crashed before Finish; see the failure above).")
        return 1 if latest.get("status") == "Failed" else 2
    items, models = summary.get("items") or {}, summary.get("models") or {}
    print(f"\nLatest run summary: {summary.get('subject')}")
    print(f"  mode={summary.get('mode')}  status={summary.get('status')}  items={len(items)}  models={len(models)}"
          f"  silver={round((summary.get('tier_seconds') or {}).get('silver', 0) / 60)} min"
          f"  gold={round((summary.get('tier_seconds') or {}).get('gold', 0) / 60)} min")
    issues = problems(summary)
    print("Problems:" if issues else "Problems: none")
    for line in issues:
        print(line)
    if summary.get("affected_reports"):
        print("Affected reports: " + ", ".join(map(str, summary["affected_reports"])))
    return 0 if summary.get("status") == "ok" and not issues else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
