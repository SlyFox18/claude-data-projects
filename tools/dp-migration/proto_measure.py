"""Phase 0 measurement: jobs and Spark (Livy) sessions for the prototype notebooks in a UTC window.

Usage: python proto_measure.py <startUtcISO> <endUtcISO>
Prints, per notebook: job instances overlapping the window (status, start, end, seconds) and its
Livy sessions overlapping the window (state, running seconds). A record that starts before the
window or ends after it is marked "[straddles window]" (its full duration is still reported). Then
totals: session count, summed session running seconds, and wall clock (first start -> last end).
"""
import json
import os
import subprocess
import sys
import urllib.parse
from datetime import datetime

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"

STAGING = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
PRESENTATION = "73fd5443-240e-410a-990a-98827f32c087"
NOTEBOOKS = {
    STAGING: ["Build_Silver_WkMechFl", "Build_Silver_Contact", "Build_Silver_WkMechAdj",
              "Build_Silver_WkMechWk", "Build_Silver_WkOthSub", "Proto_RunMultiple"],
    PRESENTATION: ["Build_Gold_TechnicianCodeNames", "Build_Gold_TechnicianAttendance",
                   "Build_Gold_TechnicianPunchedTime", "Build_Gold_TechnicianEfficiency",
                   "Proto_RunMultiple", "Proto_FailProbe", "Proto_AfterFail"],
}


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


def ts(s):
    """Naive UTC datetime from Fabric's timestamps ('...Z', '+00:00', or 7 fractional digits)."""
    if not s:
        return None
    return datetime.fromisoformat(s.rstrip("Z").split("+")[0][:26])


def seconds(a, b):
    return round((ts(b) - ts(a)).total_seconds(), 1) if a and b else None


def duration_seconds(d):
    """Livy durations come as {'value': n, 'timeUnit': 'Seconds'|'Minutes'|...}."""
    if not isinstance(d, dict):
        return None
    mult = {"Seconds": 1, "Minutes": 60, "Hours": 3600, "Milliseconds": 0.001}.get(d.get("timeUnit"), None)
    return round(d["value"] * mult, 1) if mult is not None and d.get("value") is not None else None


def overlaps(start_s, end_s, w_start, w_end):
    """True if the [start_s, end_s] record interval overlaps [w_start, w_end] (parsed datetimes)."""
    s = ts(start_s)
    if s is None:
        return False
    e = ts(end_s)
    return s <= w_end and (e is None or e >= w_start)


def straddle_tag(start_s, end_s, w_start, w_end):
    s, e = ts(start_s), ts(end_s)
    return " [straddles window]" if (s and s < w_start) or (e and e > w_end) else ""


def main():
    start, end = sys.argv[1], sys.argv[2]
    w_start, w_end = ts(start), ts(end)
    total_sessions, total_running, starts, ends = 0, 0.0, [], []
    for ws, names in NOTEBOOKS.items():
        items = {i["displayName"]: i["id"] for i in api_list(f"workspaces/{ws}/items?type=Notebook")}
        for name in names:
            nid = items.get(name)
            if not nid:
                print(f"{name}: NOT FOUND in workspace {ws}")
                continue
            jobs = [j for j in api_list(f"workspaces/{ws}/items/{nid}/jobs/instances")
                    if overlaps(j.get("startTimeUtc"), j.get("endTimeUtc"), w_start, w_end)]
            sessions = [s for s in api_list(f"workspaces/{ws}/notebooks/{nid}/livySessions")
                        if overlaps(s.get("submittedDateTime"), s.get("endDateTime"), w_start, w_end)]
            print(f"\n{name} ({'staging' if ws == STAGING else 'presentation'})")
            for j in jobs:
                tag = straddle_tag(j.get("startTimeUtc"), j.get("endTimeUtc"), w_start, w_end)
                print(f"  job {j['status']:10s} {j.get('startTimeUtc')} -> {j.get('endTimeUtc')}"
                      f"  {seconds(j.get('startTimeUtc'), j.get('endTimeUtc'))}s{tag}")
                starts.append(j.get("startTimeUtc"))
                if j.get("endTimeUtc"):
                    ends.append(j["endTimeUtc"])
            for s in sessions:
                run = duration_seconds(s.get("runningDuration"))
                tag = straddle_tag(s.get("submittedDateTime"), s.get("endDateTime"), w_start, w_end)
                print(f"  spark session {s.get('state')}  running {run}s  queued "
                      f"{duration_seconds(s.get('queuedDuration'))}s  keys={sorted(s.keys())}{tag}")
                total_sessions += 1
                total_running += run or 0
    print("\nTOTALS")
    print(f"  spark sessions: {total_sessions}")
    print(f"  summed session running seconds: {round(total_running, 1)}")
    if starts and ends:
        print(f"  wall clock: {min(starts)} -> {max(ends)} = {seconds(min(starts), max(ends))}s")


if __name__ == "__main__":
    main()
