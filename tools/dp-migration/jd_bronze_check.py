"""Health check for JD's Bronze load pipelines (JD_FabricOneLake workspace).

Checks the latest run of each pipeline at the ACTIVITY level (the Full pipeline reports
"Completed" even when every copy fails), plus the incremental watermark table.

Usage: python tools/dp-migration/jd_bronze_check.py
Requires: fab CLI logged in; duckdb with delta/azure extensions; az login.
"""
import collections, json, os, subprocess, sys, tempfile
import duckdb

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
WS = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
LH = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
PIPES = {"Full": "e2094bc4-2b08-4510-83db-bd0d19ec754f", "Incremental": "c310aa3b-3143-49aa-b77c-a3ae13e5660b"}


def api(path, method=None, body=None):
    cmd = ["fab", "api", path] + (["-X", method] if method else [])
    if body is not None:
        f = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(body, f); f.close()
        cmd += ["-i", f.name]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    i = out.find("{")
    return json.loads(out[i:]) if i >= 0 else {}


healthy = True
for name, pid in PIPES.items():
    runs = sorted(api(f"workspaces/{WS}/items/{pid}/jobs/instances").get("text", {}).get("value", []),
                  key=lambda r: r.get("startTimeUtc") or "", reverse=True)
    if not runs:
        print(f"{name}: no runs found"); healthy = False; continue
    r = runs[0]
    q = api(f"workspaces/{WS}/datapipelines/pipelineruns/{r['id']}/queryactivityruns", "post",
            {"filters": [], "orderBy": [{"orderBy": "ActivityRunStart", "order": "ASC"}],
             "lastUpdatedAfter": "2026-01-01T00:00:00Z", "lastUpdatedBefore": "2099-01-01T00:00:00Z"})
    t = q.get("text")
    acts = t.get("value", []) if isinstance(t, dict) else []
    copies = [a for a in acts if a.get("activityType") == "Copy"]
    c = collections.Counter(a.get("status") for a in copies)
    print(f"\n{name}: latest run {r['startTimeUtc'][:16]} UTC  pipeline={r['status']}  copies={dict(c)}")
    failed = [a for a in acts if a.get("status") == "Failed"]
    if failed:
        healthy = False
        for m, n in collections.Counter(str((a.get("error") or {}).get("message"))[:200] for a in failed).most_common(3):
            print(f"  FAILED x{n}: {m}")

con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
wm = con.sql(f"""SELECT TableName, WatermarkValue, LastSyncToLakeHouse
                 FROM delta_scan('abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Tables/watermarktable_incremental')
                 ORDER BY LastSyncToLakeHouse""").fetchall()
print("\nIncremental watermarks (oldest sync first):")
for t, w, s in wm:
    print(f"  {t:28s} last sync {s}   watermark {str(w)[:19]}")
print("\nHEALTHY" if healthy else "\nPROBLEM - see README runbook: projects/jd-bronze-pipelines/README.md")
