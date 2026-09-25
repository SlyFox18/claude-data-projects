"""Wait for the GitHub Actions run of fabric-workspace-docs' current HEAD commit.

Usage: python wait_ci.py [repoPath]   (default: fabric-workspace-docs)
Exit code 0 only when the run concluded 'success'.
"""
import json
import subprocess
import sys
import time

repo = sys.argv[1] if len(sys.argv) > 1 else r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
rev = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"], capture_output=True, text=True)
sha = rev.stdout.strip()
if rev.returncode != 0 or not sha:
    print("git rev-parse HEAD failed:", rev.stderr.strip())
    sys.exit(1)
print("waiting for CI run of", sha[:8])
deadline = time.time() + 900
while time.time() < deadline:
    proc = subprocess.run(
        ["gh", "run", "list", "--commit", sha, "--workflow", "deploy.yml",
         "--json", "databaseId,status,conclusion"],
        capture_output=True, text=True, cwd=repo,
    )
    if proc.returncode != 0:
        print("gh run list failed:", proc.stderr.strip())
        sys.exit(1)
    runs = json.loads(proc.stdout or "[]")
    if runs:
        run = runs[0]
        print(f"  run {run['databaseId']}: {run['status']} {run.get('conclusion') or ''}")
        if run["status"] == "completed":
            sys.exit(0 if run.get("conclusion") == "success" else 1)
    time.sleep(15)
print("TIMEOUT waiting for CI")
sys.exit(2)
