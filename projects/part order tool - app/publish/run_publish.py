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
import msvcrt
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


LOCK_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "publish.lock")


def _ts() -> str:
    return datetime.now(timezone.utc).isoformat()


def _lock():
    """Single-instance lock; the OS releases it when the process dies. Returns the open handle, or None if held."""
    fh = open(LOCK_FILE, "a+")
    try:
        msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1)
    except OSError:
        fh.close()
        return None
    return fh   # keep open for the life of the process


def load_state() -> dict:
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as ex:
        print(f"[{_ts()}] WARNING: cannot read {STATE_FILE} ({ex}); treating this as a first publish", flush=True)
        return {}


def save_state(state: dict) -> None:
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=1)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, STATE_FILE)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true",
                    help="re-publish this run and re-send every file (never publishes a failed run)")
    args = ap.parse_args(argv)
    lock = _lock()
    if lock is None:
        print(f"[{_ts()}] another publish is running; exiting", flush=True)
        return 0
    try:
        return _publish(args)
    finally:
        lock.close()


def _publish(args) -> int:
    print(f"[{_ts()}] publish start, source={config.SOURCE}", flush=True)

    con = extract.connect()
    rows = extract.log_rows(con)
    latest = pl.latest_item_run(rows)
    state = load_state()
    go, why = pl.decide_publish(latest, state, config.SOURCE, args.force)
    print(f"decision: {go} ({why})")
    if not go:
        return 0

    # Gold and the publish must agree on the columns (rules list included); a mismatch fails here, before any
    # extract, naming them (MissingColumnsError).
    extract.check_columns(con)
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
    try:
        rules = extract.rules(con)
    except pl.MissingColumnsError:
        raise   # already names the missing columns
    except Exception as ex:
        first = (str(ex).splitlines() or [""])[0]
        raise RuntimeError(f"NonJD_OrderRules not found or unreadable in the {config.SOURCE} DP_Presentation "
                           f"lakehouse ({type(ex).__name__}: {first}); deploy the rules dataflow and shortcut "
                           f"before publishing") from ex
    if extract.built_at(con) != built:
        raise RuntimeError("Fact_NonJD_Reorder was rewritten while extracting; rerun the publish")
    hashes, branches = build_files.build(reorder, lambda b: extract.history_for(con, b), transfers, names,
                                         data_as_of, current_month, rules)
    counts = {"parts": len(reorder), "historyRows": history_rows, "transferLines": len(transfers)}
    meta_path = build_files.write_meta(data_as_of, datetime.now(timezone.utc).isoformat(), config.SOURCE,
                                       branches, counts)

    previous = {} if args.force else (state.get("hashes", {}) if state.get("source") == config.SOURCE else {})
    to_send = [os.path.join(build_files.OUT_DIR, n) for n in pl.changed_files(hashes, previous)]
    access = upload.token()
    print(f"[{_ts()}] uploading {len(to_send) + 1} file(s)", flush=True)
    for path in pl.upload_order(to_send + [meta_path]):
        upload.put_file(path, access)
        print(f"  uploaded {os.path.basename(path)}")

    save_state({"source": config.SOURCE, "dataAsOf": data_as_of, "hashes": hashes})
    print(f"[{_ts()}] done: published {len(to_send)} file(s) + _meta.json; data as of {data_as_of}; {counts}",
          flush=True)
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(line_buffering=True)
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        print(f"[{_ts()}] publish FAILED", flush=True)
        sys.exit(1)
