"""Fabric Git status for one or more Git-connected workspaces.

Usage: python git_status.py [workspaceId ...]   (default: both DP Dev workspaces + RP - Dev)
Prints head/remote and every pending change (workspace side, remote side, conflict).
"""
import json
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
DEFAULT = {
    "73fd5443-240e-410a-990a-98827f32c087": "DP - Presentation - Dev",
    "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201": "DP - Staging - Dev",
    "e888a4dc-a02d-4fd4-839d-5daa5763ab44": "RP - Dev",
}


def api(path):
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    start = out.find("{")
    if start < 0:
        sys.exit(f"No JSON from fab api {path}:\n{out[-500:]}")
    return json.loads(out[start:])


targets = {w: w for w in sys.argv[1:]} or DEFAULT
for ws, label in targets.items():
    r = api(f"workspaces/{ws}/git/status")
    s = r.get("text", {})
    changes = s.get("changes", [])
    print(f"=== {label}: head={str(s.get('workspaceHead'))[:8]} remote={str(s.get('remoteCommitHash'))[:8]} changes={len(changes)}")
    for c in sorted(changes, key=lambda c: c.get("itemMetadata", {}).get("displayName") or ""):
        m = c.get("itemMetadata", {})
        print(f"  {m.get('displayName', '?'):50s} {m.get('itemType', ''):16s} ws={c.get('workspaceChange')} "
              f"remote={c.get('remoteChange')} conflict={c.get('conflictType')}")
