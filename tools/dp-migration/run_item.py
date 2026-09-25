"""Run a Fabric item job by ID and wait for it to finish.

Usage: python run_item.py <workspaceId> <itemId> <jobType> [timeoutSeconds]
  jobType: RunNotebook (notebooks) | Refresh (Dataflow Gen2)
Exit codes: 0 completed, 1 failed/submit error, 2 timeout, 3 already running, 4 ambiguous.
"""
import json
import os
import subprocess
import sys
import time

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
TERMINAL = {"Completed", "Failed", "Cancelled", "Deduped"}
NON_TERMINAL = {"NotStarted", "InProgress"}


def fab_api(path, method=None):
    cmd = ["fab", "api", path] + (["-X", method] if method else [])
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    start = out.find("{")
    return json.loads(out[start:]) if start >= 0 else {"raw": out[-800:]}


def list_instances(ws, item):
    """All job instances for the item, following continuationToken pages."""
    path = f"workspaces/{ws}/items/{item}/jobs/instances"
    values = []
    token = None
    while True:
        p = path + (f"?continuationToken={token}" if token else "")
        body = fab_api(p).get("text", {})
        values.extend(body.get("value", []))
        token = body.get("continuationToken")
        if not token:
            break
    return values


def main():
    ws, item, job_type = sys.argv[1:4]
    timeout = int(sys.argv[4]) if len(sys.argv) > 4 else 1800

    existing = list_instances(ws, item)
    for inst in existing:
        if inst.get("status") in NON_TERMINAL:
            print("already running:", json.dumps(inst, indent=1))
            sys.exit(3)
    existing_ids = {i["id"] for i in existing}

    r = fab_api(f"workspaces/{ws}/items/{item}/jobs/instances?jobType={job_type}", "post")
    print("submit status:", r.get("status_code"))
    if r.get("status_code") not in (200, 201, 202):
        print(json.dumps(r, indent=1)[:2000])
        sys.exit(1)

    started = time.time()
    tracked_id = None
    while True:
        time.sleep(20)
        instances = list_instances(ws, item)
        if tracked_id is None:
            new = [i for i in instances if i.get("id") not in existing_ids]
            if len(new) > 1:
                print("ambiguous: multiple new job instances appeared:")
                print(json.dumps(new, indent=1)[:2000])
                sys.exit(4)
            if len(new) == 1:
                tracked_id = new[0]["id"]
        else:
            latest = next((i for i in instances if i.get("id") == tracked_id), None)
            status = latest.get("status") if latest else None
            print(f"  {int(time.time() - started)}s: {status}")
            if status in TERMINAL:
                keys = ("status", "startTimeUtc", "endTimeUtc", "failureReason")
                print(json.dumps({k: latest.get(k) for k in keys}, indent=1))
                sys.exit(0 if status == "Completed" else 1)
        if time.time() - started > timeout:
            print("TIMEOUT waiting for job")
            sys.exit(2)


if __name__ == "__main__":
    main()
