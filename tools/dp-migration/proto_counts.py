"""Phase 0 correctness check: row counts of the 9 output tables, and that every Silver_* table
visible under DP_Presentation is a genuine OneLake shortcut into DP_Staging.

DP_Presentation's Gold notebooks read Silver via `spark.read.table` against OneLake shortcuts, so
the 5 Silver_* names are *expected* to resolve under DP_Presentation/Tables -- that's not a bug.
A stray entry is one that is NOT a shortcut (i.e. a real table written there by a wrongly-routed
job), or a shortcut whose target isn't DP_Staging.

Usage: python proto_counts.py
"""
import json
import os
import subprocess
import sys

import duckdb

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"

STAGING_WS = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
STAGING_ITEM = "876255e0-d462-4697-adc1-4a655f5bb101"
PRESENTATION_WS = "73fd5443-240e-410a-990a-98827f32c087"
PRESENTATION_ITEM = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
STAGING = f"abfss://{STAGING_WS}@onelake.dfs.fabric.microsoft.com/{STAGING_ITEM}/Tables/"
PRESENTATION = f"abfss://{PRESENTATION_WS}@onelake.dfs.fabric.microsoft.com/{PRESENTATION_ITEM}/Tables/"
SILVER = ["Silver_WkMechFl", "Silver_Contact", "Silver_WkMechAdj", "Silver_WkMechWk", "Silver_WkOthSub"]
GOLD = ["dim_Technician_Code_Names", "TechnicianAttendance", "TechnicianPunchedTime", "TechnicianEfficiency"]


def api(path):
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    i = out.find("{")
    return json.loads(out[i:]).get("text", {}) if i >= 0 else {}


def list_shortcuts(ws, item):
    """All shortcuts defined on an item, following continuationToken if present."""
    path = f"workspaces/{ws}/items/{item}/shortcuts"
    values = []
    while True:
        data = api(path)
        values.extend(data.get("value", []))
        token = data.get("continuationToken")
        if not token:
            break
        sep = "&" if "?" in path else "?"
        path = f"workspaces/{ws}/items/{item}/shortcuts{sep}continuationToken={token}"
    return values


con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
for root, tables in ((STAGING, SILVER), (PRESENTATION, GOLD)):
    for t in tables:
        n = con.sql(f"SELECT count(*) FROM delta_scan('{root}{t}')").fetchone()[0]
        print(f"{t:28s} {n:>12,}")

shortcuts = {s["name"]: s for s in list_shortcuts(PRESENTATION_WS, PRESENTATION_ITEM)
             if s.get("path") in ("Tables", "/Tables")}

stray = []
for t in SILVER:
    sc = shortcuts.get(t)
    one_lake = (sc or {}).get("target", {}).get("oneLake", {})
    target_ws, target_item = one_lake.get("workspaceId"), one_lake.get("itemId")
    is_shortcut = sc is not None
    points_to_staging = target_ws == STAGING_WS and target_item == STAGING_ITEM
    print(f"{t:28s} shortcut={is_shortcut}  target_ws={target_ws}  target_item={target_item}"
          f"  points_to_staging={points_to_staging}")
    if not (is_shortcut and points_to_staging):
        stray.append(t)

print("stray Silver tables in DP_Presentation:", stray or "none")
sys.exit(1 if stray else 0)
