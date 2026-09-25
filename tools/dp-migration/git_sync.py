"""Update a Git-connected Fabric workspace from its branch (Fabric 'Update all').

Usage: python git_sync.py <workspaceId> [timeoutSeconds]

The Dev workspaces are Git-connected and Git sync is their single writer, so
this is how pushed notebook code reaches Dev. It refuses to run when any item
has changes on BOTH sides (conflict or uncommitted edit about to be
overwritten) and never passes a conflict-resolution policy, so it can't
silently discard workspace work. Items changed only in the workspace are left
alone by Fabric's update.

Exit codes: 0 synced (or already current), 1 refused/failed, 2 timeout.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"


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
    if start < 0:
        sys.exit(f"No JSON from `fab api {path}`:\n{out[-500:]}")
    return json.loads(out[start:])


def status(ws):
    r = fab_api(f"workspaces/{ws}/git/status")
    if r.get("status_code") != 200:
        sys.exit(f"git/status failed: {json.dumps(r)[:1500]}")
    return r["text"]


def main():
    ws = sys.argv[1]
    timeout = int(sys.argv[2]) if len(sys.argv) > 2 else 600
    s = status(ws)
    head, remote = s.get("workspaceHead"), s.get("remoteCommitHash")
    changes = s.get("changes", [])
    incoming = [c for c in changes if c.get("remoteChange")]
    both = [c for c in incoming if c.get("workspaceChange")]
    print(f"workspaceHead={str(head)[:8]} remote={str(remote)[:8]} "
          f"incoming={len(incoming)} workspace-only={len(changes) - len(incoming)}")
    for c in incoming:
        m = c.get("itemMetadata", {})
        print(f"  incoming {c.get('remoteChange'):8s} {m.get('displayName')} ({m.get('itemType')})"
              f"{'  <-- ALSO CHANGED IN WORKSPACE (' + str(c.get('conflictType')) + ')' if c.get('workspaceChange') else ''}")
    if head == remote:
        print("Already up to date.")
        sys.exit(0)
    if both:
        sys.exit("Refusing: items changed on both sides - resolve in the Fabric Source control panel.")

    # allowOverrideItems is Fabric's consent to apply incoming items (the same
    # confirmation the UI's Update dialog asks for); the API refuses to start
    # without it whenever an incoming change modifies an existing item. It is
    # safe here because we already refused above if any incoming item is also
    # changed in the workspace, and no conflictResolution policy is passed.
    body = {"remoteCommitHash": remote, "workspaceHead": head, "options": {"allowOverrideItems": True}}
    r = fab_api(f"workspaces/{ws}/git/updateFromGit", "post", body)
    print("updateFromGit status:", r.get("status_code"))
    if r.get("status_code") not in (200, 202):
        sys.exit(f"updateFromGit failed: {json.dumps(r)[:1500]}")

    started = time.time()
    while time.time() - started < timeout:
        time.sleep(10)
        s = status(ws)
        if s.get("workspaceHead") == remote:
            print(f"Synced to {remote[:8]} in {int(time.time() - started)}s.")
            sys.exit(0)
    print("TIMEOUT waiting for workspaceHead to reach", remote[:8])
    sys.exit(2)


if __name__ == "__main__":
    main()
