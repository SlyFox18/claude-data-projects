"""
PARTS LOOKUP REFRESH PIPELINE - VERIFY A PUBLISH
============================================================================
Downloads _meta.json, _manifest.json, the largest partition file and a
fixed random sample of others from the SharePoint library in the current
env file (PARTS_LOOKUP_ENV_FILE, default .env) and compares their decoded
JSON with the local output/2char/ files. Read-only on SharePoint.

Usage: python verify_publish.py [sample_size]     (default 20)
Exit 0 when every checked file matches.
============================================================================
"""

import glob
import gzip
import json
import os
import random
import sys

import requests

import config
from upload import GRAPH_BASE, get_access_token

LOCAL_DIR = os.path.join("output", "2char")


def download(name: str, token: str) -> bytes:
    url = f"{GRAPH_BASE}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}/root:/{name}:/content"
    r = requests.get(url, headers={"Authorization": f"Bearer {token}"}, timeout=(10, 120))
    r.raise_for_status()
    return r.content


def decode(name: str, data: bytes):
    return json.loads(gzip.decompress(data) if name.endswith(".gz") else data)


def main(sample_size: int = 20) -> int:
    token = get_access_token()
    paths = glob.glob(os.path.join(LOCAL_DIR, "*.json*"))
    parts = sorted(os.path.basename(p) for p in paths if not os.path.basename(p).startswith("_"))
    largest = os.path.basename(max(paths, key=os.path.getsize))
    sample = random.Random(0).sample(parts, min(sample_size, len(parts)))
    names = ["_meta.json", "_manifest.json", largest] + [n for n in sample if n != largest]
    bad = 0
    for name in names:
        with open(os.path.join(LOCAL_DIR, name), "rb") as f:
            local = decode(name, f.read())
        same = local == decode(name, download(name, token))
        bad += not same
        print(f"{'OK ' if same else 'BAD'} {name}")
    print("library:", config.LIBRARY_BASE)
    print("remote _meta.json:", decode("_meta.json", download("_meta.json", token)))
    print("PASS" if not bad else f"FAIL ({bad} file(s) differ)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 20))
