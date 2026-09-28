"""Phase 0 baseline: run the Labor Performance chain as one job per notebook (each its own Spark
session), 3 at a time (ThreadPoolExecutor max_workers=3, mirroring today's pipeline ForEach
batchCount 3). All 5 Silver notebooks (Staging workspace) must complete before any of the 4 Gold
notebooks (Presentation workspace) start.

Usage: python proto_baseline.py

Prints each notebook's exit code and local wall seconds as it finishes (plus the last 20 lines of
its stdout on failure), then a WINDOW line (`WINDOW <startUtc> <endUtc>`, %Y-%m-%dT%H:%M:%S UTC)
for proto_measure.py to consume.

Exit codes:
  0 - all notebooks completed
  1 - one or more notebooks failed (Gold is skipped entirely if any Silver notebook failed)
  2 - a notebook name could not be resolved to an item id in its workspace (checked for ALL
      notebooks in both workspaces before anything is launched)
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"

STAGING = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
PRESENTATION = "73fd5443-240e-410a-990a-98827f32c087"
SILVER = ["Build_Silver_WkMechFl", "Build_Silver_Contact", "Build_Silver_WkMechAdj",
          "Build_Silver_WkMechWk", "Build_Silver_WkOthSub"]
GOLD = ["Build_Gold_TechnicianCodeNames", "Build_Gold_TechnicianAttendance",
        "Build_Gold_TechnicianPunchedTime", "Build_Gold_TechnicianEfficiency"]

RUN_ITEM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "run_item.py")
TIMEOUT_SECONDS = "3600"


def api(path):
    """Call `fab api <path>` and return its parsed 'text' body.

    Raises RuntimeError if the response has no parseable JSON, or a status_code outside 200-299 --
    a failed call must never silently look like an empty result.
    """
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
    """All `value` items from a Fabric API list endpoint, following continuationToken.

    Each page URL is built from the ORIGINAL base path (not the previous page's path) to avoid
    accumulating stale continuationToken query params on the 3rd+ page.
    """
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


def resolve_ids():
    """{workspaceId: {displayName: itemId}} for both workspaces (Notebook items only).

    Read-only -- safe to call on its own without launching anything.
    """
    return {
        ws: {i["displayName"]: i["id"] for i in api_list(f"workspaces/{ws}/items?type=Notebook")}
        for ws in (STAGING, PRESENTATION)
    }


def run_notebook(ws, name, item_id):
    """Launch run_item.py for one notebook and wait for it. Returns (name, exit_code, seconds)."""
    started = time.time()
    proc = subprocess.run(
        [sys.executable, RUN_ITEM, ws, item_id, "RunNotebook", TIMEOUT_SECONDS],
        capture_output=True, text=True, encoding="utf-8",
    )
    elapsed = round(time.time() - started, 1)
    print(f"{name}: exit {proc.returncode} ({elapsed}s)")
    if proc.returncode != 0:
        for line in proc.stdout.strip().splitlines()[-20:]:
            print(f"    {line}")
    return name, proc.returncode, elapsed


def run_tier(ws, names, ids):
    """Run all `names` (workspace `ws`) 3 at a time. Returns True iff every one exited 0."""
    with ThreadPoolExecutor(max_workers=3) as pool:
        results = [f.result() for f in [pool.submit(run_notebook, ws, name, ids[name]) for name in names]]
    return all(code == 0 for _, code, _ in results)


def main():
    resolved = resolve_ids()
    missing = [f"{name} (workspace {ws})"
               for ws, names in ((STAGING, SILVER), (PRESENTATION, GOLD))
               for name in names if name not in resolved.get(ws, {})]
    if missing:
        print("Could not resolve notebook name(s) to item ids:")
        for m in missing:
            print(f"  {m}")
        sys.exit(2)

    window_start = datetime.now(timezone.utc)

    print(f"--- Silver ({len(SILVER)} notebooks, 3 at a time) ---")
    silver_ok = run_tier(STAGING, SILVER, resolved[STAGING])

    if silver_ok:
        print(f"\n--- Gold ({len(GOLD)} notebooks, 3 at a time) ---")
        gold_ok = run_tier(PRESENTATION, GOLD, resolved[PRESENTATION])
    else:
        print("\nSilver had failures -- skipping Gold.")
        gold_ok = False

    window_end = datetime.now(timezone.utc)
    fmt = "%Y-%m-%dT%H:%M:%S"
    print(f"\nWINDOW {window_start.strftime(fmt)} {window_end.strftime(fmt)}")

    sys.exit(0 if (silver_ok and gold_ok) else 1)


if __name__ == "__main__":
    main()
