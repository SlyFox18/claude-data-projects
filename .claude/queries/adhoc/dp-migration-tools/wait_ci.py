"""Wait for the GitHub Actions run of fabric-workspace-docs' current HEAD commit.

Usage: python wait_ci.py [repoPath]   (default: fabric-workspace-docs)
Exit code 0 only when the run concluded 'success'.
"""
import json
import subprocess
import sys
import time

repo = sys.argv[1] if len(sys.argv) > 1 else r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
sha = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
print("waiting for CI run of", sha[:8])
deadline = time.time() + 900
while time.time() < deadline:
    out = subprocess.run(
        ["gh", "run", "list", "--commit", sha, "--json", "databaseId,status,conclusion"],
        capture_output=True, text=True, cwd=repo,
    ).stdout
    runs = json.loads(out or "[]")
    if runs:
        run = runs[0]
        print(f"  run {run['databaseId']}: {run['status']} {run.get('conclusion') or ''}")
        if run["status"] == "completed":
            sys.exit(0 if run.get("conclusion") == "success" else 1)
    time.sleep(15)
print("TIMEOUT waiting for CI")
sys.exit(2)
