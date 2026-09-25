"""Compare each registered notebook's Fabric folder against its repo path.

Usage: python folder_check.py
Prints every registered notebook whose Fabric folder != its repo folder
(relative to workspaces/<workspace>/). Exit 1 if any mismatch.
"""
import json
import os
import subprocess
import sys

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
SCOPE = r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/deploy/dp_backend_scope.json"


def api(path):
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    return json.loads(out[out.find("{"):])["text"]


def folder_paths(ws):
    folders = {f["id"]: f for f in api(f"workspaces/{ws}/folders").get("value", [])}

    def full(fid):
        f = folders[fid]
        parent = f.get("parentFolderId")
        return (full(parent) + "/" if parent in folders else "") + f["displayName"]

    return {fid: full(fid) for fid in folders}


scope = json.load(open(SCOPE, encoding="utf-8"))
by_ws = {}
for nb in scope["notebooks"]:
    by_ws.setdefault(nb["workspaceId"], []).append(nb)

mismatches = 0
for ws, nbs in by_ws.items():
    paths = folder_paths(ws)
    items = {i["displayName"]: i for i in api(f"workspaces/{ws}/items?type=Notebook")["value"]}
    for nb in nbs:
        rel = nb["path"].split("/", 2)[2]          # drop "workspaces/<ws>/"
        repo_dir = rel.rsplit("/", 1)[0] if "/" in rel else ""
        it = items.get(nb["name"])
        fabric_dir = paths.get(it.get("folderId"), "") if it else "<MISSING>"
        ok = fabric_dir == repo_dir
        mismatches += not ok
        print(f"{'OK  ' if ok else 'DIFF'} {nb['name']:45s} fabric='{fabric_dir}' repo='{repo_dir}'")
print(f"\n{mismatches} mismatch(es) across {sum(len(v) for v in by_ws.values())} registered notebooks")
sys.exit(1 if mismatches else 0)
