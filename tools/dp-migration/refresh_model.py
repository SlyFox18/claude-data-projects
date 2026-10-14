"""Trigger a Power BI semantic model refresh (service) and wait for the result.

Usage: python refresh_model.py <workspaceId> <datasetId> [timeoutSeconds]
Exit 0 only on Completed. A 'DMTS_MonikerWithUnboundDataSources' failure means the
model's data-source credentials must be set in the service (Brian's action).
"""
import json
import os
import subprocess
import sys
import tempfile
import time

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"


def pbi(path, method=None, body=None):
    cmd = ["fab", "api", "-A", "powerbi", path] + (["-X", method] if method else [])
    tmp = None
    if body is not None:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(body, tmp)
        tmp.close()
        cmd += ["-i", tmp.name]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    if tmp:
        os.unlink(tmp.name)
    start = out.find("{")
    return json.loads(out[start:]) if start >= 0 else {"raw": out[-600:]}


ws, ds = sys.argv[1], sys.argv[2]
timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 1800
r = pbi(f"groups/{ws}/datasets/{ds}/refreshes", "post", {"notifyOption": "NoNotification"})
print("submit:", r.get("status_code"))
if r.get("status_code") not in (200, 202):
    print(json.dumps(r, indent=1)[:1500])
    sys.exit(1)
start = time.time()
while time.time() - start < timeout:
    time.sleep(20)
    hist = pbi(f"groups/{ws}/datasets/{ds}/refreshes?$top=1").get("text", {}).get("value", [])
    if hist:
        st = hist[0].get("status")
        print(f"  {int(time.time() - start)}s: {st}")
        if st in ("Completed", "Failed", "Disabled", "Cancelled"):
            keys = ("status", "startTime", "endTime", "refreshType", "serviceExceptionJson")
            print(json.dumps({k: hist[0].get(k) for k in keys}, indent=1))
            sys.exit(0 if st == "Completed" else 1)
print("TIMEOUT")
sys.exit(2)
