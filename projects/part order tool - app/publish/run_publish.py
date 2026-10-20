"""
Non-JD Parts Order Tool - daily publish.

1. Read dp_refresh_log; publish only if Build_Gold_NonJD_Reorder's latest run succeeded and wasn't published yet.
2. Check the Gold table was written by that run (BuiltAtUtc within the run).
3. Build files, upload the changed ones, then _meta.json last. Save publish_state.json.

Exit 0 = published or nothing to do; 1 = error (Task Scheduler shows "last run result" 0x1).
Usage: python run_publish.py [--force]
"""
import argparse
import json
import os
import sys
import traceback
from datetime import datetime, timezone

import build_files
import config
import extract
import publish_logic as pl
import upload

STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "publish_state.json")


def load_state() -> dict:
    if not os.path.exists(STATE_FILE):
        return {}
    with open(STATE_FILE, encoding="utf-8") as f:
        return json.load(f)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true",
                    help="publish even if this run was already published (never publishes a failed run)")
    args = ap.parse_args(argv)
    stamp = datetime.now(timezone.utc).isoformat()
    print(f"[{stamp}] publish start, source={config.SOURCE}")

    con = extract.connect()
    rows = extract.log_rows(con)
    latest = pl.latest_item_run(rows)
    state = load_state()
    go, why = pl.decide_publish(latest, state, config.SOURCE, args.force)
    print(f"decision: {go} ({why})")
    if not go:
        return 0

    built = extract.built_at(con)
    start = pl.run_start(rows, latest["run_id"])
    if not pl.built_in_run(built, start, latest["end_utc"]):
        raise RuntimeError(f"Fact_NonJD_Reorder BuiltAtUtc {built} is outside run {latest['run_id']} "
                           f"({start} .. {latest['end_utc']}); refusing to publish mismatched data")

    data_as_of = pl.iso_utc(latest["end_utc"])
    current_month = pl.central_month_start(built)

    reorder = extract.reorder(con)
    history_rows = extract.stage_history(con)     # copied into a DuckDB temp table; built one branch at a time
    transfers, names = extract.transfers(con), extract.branch_names(con)
    if extract.built_at(con) != built:
        raise RuntimeError("Fact_NonJD_Reorder was rewritten while extracting; rerun the publish")
    hashes, branches = build_files.build(reorder, lambda b: extract.history_for(con, b), transfers, names,
                                         data_as_of, current_month)
    counts = {"parts": len(reorder), "historyRows": history_rows, "transferLines": len(transfers)}
    meta_path = build_files.write_meta(data_as_of, datetime.now(timezone.utc).isoformat(), config.SOURCE,
                                       branches, counts)

    previous = state.get("hashes", {}) if state.get("source") == config.SOURCE else {}
    to_send = [os.path.join(build_files.OUT_DIR, n) for n in pl.changed_files(hashes, previous)]
    access = upload.token()
    for path in pl.upload_order(to_send + [meta_path]):
        upload.put_file(path, access)
        print(f"  uploaded {os.path.basename(path)}")

    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump({"source": config.SOURCE, "dataAsOf": data_as_of, "hashes": hashes}, f, indent=1)
    print(f"published {len(to_send)} changed file(s) + _meta.json; data as of {data_as_of}; {counts}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(1)
