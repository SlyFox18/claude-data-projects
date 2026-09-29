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
        try:
            usage = api(f"workspaces/{ws}/notebooks/{nb}/livySessions/{s['livyId']}"
                        f"/applications/{s['sparkApplicationId']}/resourceUsage")
        except RuntimeError as e:
            # resourceUsage can 404 for sessions too recent or too old for the API to have data for
            # (Fabric's own "too early"/expired-retention behavior). Record it, don't fail the run.
            print(json.dumps({
                "submitted": s["submittedDateTime"], "state": s.get("state"),
                "error": str(e),
            }))
            continue
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
