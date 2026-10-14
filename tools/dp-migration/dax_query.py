"""Run a DAX query against a published semantic model (Power BI executeQueries).

Usage: python dax_query.py <workspaceId> <datasetId> <file.dax>
Prints the result rows as JSON.
"""
import json
import os
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
ws, ds, dax_file = sys.argv[1], sys.argv[2], sys.argv[3]
body = {"queries": [{"query": open(dax_file, encoding="utf-8").read()}], "serializerSettings": {"includeNulls": True}}
tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
json.dump(body, tmp)
tmp.close()
out = subprocess.run(["fab", "api", "-A", "powerbi", f"groups/{ws}/datasets/{ds}/executeQueries", "-X", "post", "-i", tmp.name],
                     capture_output=True, text=True, encoding="utf-8").stdout
os.unlink(tmp.name)
r = json.loads(out[out.find("{"):])
if r.get("status_code") != 200:
    print(json.dumps(r, indent=1)[:2000])
    sys.exit(1)
for t in r["text"]["results"][0]["tables"]:
    print(json.dumps(t["rows"], indent=1))
