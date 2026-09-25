"""Run a Fabric item job by ID and wait for it to finish.

Usage: python run_item.py <workspaceId> <itemId> <jobType> [timeoutSeconds]
  jobType: RunNotebook (notebooks) | Refresh (Dataflow Gen2)
Exit code 0 only when the job's status is Completed.
"""
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
TERMINAL = {"Completed", "Failed", "Cancelled", "Deduped"}


def fab_api(path, method=None):
    cmd = ["fab", "api", path] + (["-X", method] if method else [])
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    start = out.find("{")
    return json.loads(out[start:]) if start >= 0 else {"raw": out[-800:]}


def main():
    ws, item, job_type = sys.argv[1:4]
    timeout = int(sys.argv[4]) if len(sys.argv) > 4 else 1800
    submitted = (datetime.now(timezone.utc) - timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%S")
    r = fab_api(f"workspaces/{ws}/items/{item}/jobs/instances?jobType={job_type}", "post")
    print("submit status:", r.get("status_code"))
    if r.get("status_code") not in (200, 201, 202):
        print(json.dumps(r, indent=1)[:2000])
        sys.exit(1)
    started = time.time()
    while True:
        time.sleep(20)
        body = fab_api(f"workspaces/{ws}/items/{item}/jobs/instances")
        runs = [i for i in body.get("text", {}).get("value", []) if (i.get("startTimeUtc") or "") >= submitted]
        if runs:
            latest = max(runs, key=lambda i: i.get("startTimeUtc") or "")
            status = latest.get("status")
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
