"""
Non-JD Parts Order Tool - daily publish.

1. Read dp_refresh_log; publish only if Build_Gold_NonJD_Reorder's latest run succeeded and wasn't published yet.
2. Check the Gold tables (Fact_NonJD_Reorder, Fact_CorpParts_JD, Fact_CorpParts_JD_Idle) were written by that run
   (BuiltAtUtc within it; the two JD tables share one BuiltAtUtc).
3. Build files (contract v6's jd_<branch>.json.gz and v7's jd_idle_<branch>.json.gz last), upload the changed ones (and
   transfer_suggestions.json.gz every run), then _meta.json last.
   Save publish_state.json.
4. Contract v9 (Plan S): the JD order files come from Build_Gold_JD_Reorder, a separate item. S-P4: they can't block the
   rest. Without a successful run whose table is readable and from that run, the publish goes ahead and the JD files
   stay as they were; a JD build that finishes later triggers its own publish.

--out DIR builds the same files plus _meta.json into DIR and stops there: no upload, no publish_state.json, no
lock (a local build for the app's parity checks; the checks of steps 1-2 still apply, publish_state is ignored).

Exit 0 = published or nothing to do; 1 = error (Task Scheduler shows "last run result" 0x1).
Usage: python run_publish.py [--force] [--out DIR]
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


def _jd_order_files(con, rows: list, names: dict, out_dir: str, state: dict) -> dict:
    """Plan S: build the JD order files, or carry what's published (S-P4: nothing here can stop the non-JD publish).
    Returns {"built": this run's {file name: sha256}, "hashes", "branches", "asOf", "historyRows"}: what's published
    once this run is done. Carried hashes go into the saved state, not into the files to send, so --force never looks
    for a file this run didn't write."""
    carried = {"built": {}, "hashes": {}, "branches": [], "asOf": None, "historyRows": 0}
    if state.get("source") == config.SOURCE:
        carried.update(hashes=state.get("jdOrderHashes", {}), branches=state.get("jdOrderBranches", []),
                       asOf=state.get("jdOrderAsOf"), historyRows=state.get("jdHistoryRows", 0))

    def keep(why: str) -> dict:
        print(f"JD order files kept as published ({why})")
        return carried

    run = pl.latest_item_run(rows, pl.JD_ITEM)
    if run is None:
        return keep("no run")
    if run.get("status") != "Succeeded":
        return keep(run.get("status"))
    try:
        if not extract.jd_order_available(con):
            return keep("the JD tables aren't readable yet, or lack a column")
        built = extract.jd_order_built_at(con)
        start = pl.run_start(rows, run["run_id"])
        if not pl.built_in_run(built, start, run["end_utc"]):
            return keep(f"Fact_JD_Reorder BuiltAtUtc {built} is outside run {run['run_id']} ({start} .. {run['end_utc']})")
        as_of = pl.iso_utc(run["end_utc"])
        order_rows = extract.jd_order(con)
        history_rows = extract.stage_jd_history(con)
        rules = extract.jd_rules(con)
        if extract.jd_order_built_at(con) != built:
            return keep("Fact_JD_Reorder was rewritten while extracting")
        hashes, branches = build_files.build_jd_order(order_rows, names, as_of, out_dir=out_dir)
        hashes.update(build_files.build_jd_history(lambda b: extract.jd_history_for(con, b),
                                                   [b["branch"] for b in branches], pl.central_month_start(built),
                                                   out_dir=out_dir))
        hashes.update(build_files.build_jd_rules(rules, as_of, out_dir=out_dir))
    except Exception as ex:
        traceback.print_exc()
        return keep(f"{type(ex).__name__}: {ex}")
    return {"built": hashes, "hashes": hashes, "branches": branches, "asOf": as_of, "historyRows": history_rows}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true",
                    help="re-publish this run and re-send every file (never publishes a failed run)")
    ap.add_argument("--out", metavar="DIR",
                    help="build the files and _meta.json into DIR only: no upload, no publish_state.json, no lock")
    args = ap.parse_args(argv)
    if args.out:
        return _publish(args)
    lock = _lock()
    if lock is None:
        print(f"[{_ts()}] another publish is running; exiting", flush=True)
        return 0
    try:
        return _publish(args)
    finally:
        lock.close()


def _publish(args) -> int:
    out_dir = os.path.abspath(args.out) if args.out else build_files.OUT_DIR
    print(f"[{_ts()}] publish start, source={config.SOURCE}" + (f", local build into {out_dir}" if args.out else ""),
          flush=True)

    con = extract.connect()
    rows = extract.log_rows(con)
    latest = pl.latest_item_run(rows)
    state = {} if args.out else load_state()
    jd_run = pl.latest_item_run(rows, pl.JD_ITEM)
    jd_end = jd_run["end_utc"] if jd_run is not None and jd_run.get("status") == "Succeeded" else None
    go, why = pl.decide_publish(latest, state, config.SOURCE, args.force, jd_end=jd_end)
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
    jd_built = extract.jd_built_at(con)        # the same Gold item writes Fact_CorpParts_JD (Plan L, Part 5)
    if not pl.built_in_run(jd_built, start, latest["end_utc"]):
        raise RuntimeError(f"Fact_CorpParts_JD BuiltAtUtc {jd_built} is outside run {latest['run_id']} "
                           f"({start} .. {latest['end_utc']}); refusing to publish mismatched data")
    idle_built = extract.jd_idle_built_at(con)  # Plan M: written with Fact_CorpParts_JD, with the same BuiltAtUtc
    if not pl.built_in_run(idle_built, start, latest["end_utc"]):
        raise RuntimeError(f"Fact_CorpParts_JD_Idle BuiltAtUtc {idle_built} is outside run {latest['run_id']} "
                           f"({start} .. {latest['end_utc']}); refusing to publish mismatched data")
    if idle_built != jd_built:
        raise RuntimeError(f"Fact_CorpParts_JD_Idle BuiltAtUtc {idle_built} differs from Fact_CorpParts_JD's "
                           f"{jd_built} (one Gold build writes both); refusing to publish mismatched data")

    data_as_of = pl.iso_utc(latest["end_utc"])
    current_month = pl.central_month_start(built)

    reorder = extract.reorder(con)
    history_rows = extract.stage_history(con)     # copied into a DuckDB temp table; built one branch at a time
    transfers, names = extract.transfers(con), extract.branch_names(con)
    transfer_rules, suggestions = extract.transfer_rules(con), extract.suggestions(con)
    purchases = extract.purchases(con)
    committed = extract.committed(con, pl.central_date(built))
    jd_rows = extract.jd_parts(con)
    jd_idle_rows = extract.jd_idle_parts(con)
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
    if extract.jd_built_at(con) != jd_built:
        raise RuntimeError("Fact_CorpParts_JD was rewritten while extracting; rerun the publish")
    if extract.jd_idle_built_at(con) != idle_built:
        raise RuntimeError("Fact_CorpParts_JD_Idle was rewritten while extracting; rerun the publish")
    hashes, branches = build_files.build(reorder, lambda b: extract.history_for(con, b), transfers, names,
                                         data_as_of, current_month, rules, transfer_rules=transfer_rules,
                                         suggestions=suggestions, committed=committed, purchases=purchases,
                                         out_dir=out_dir)
    jd_hashes, jd_branches = build_files.build_jd(jd_rows, names, data_as_of, out_dir=out_dir)   # contract v6
    hashes.update(jd_hashes)
    idle_hashes, jd_idle_branches = build_files.build_jd_idle(jd_idle_rows, names, data_as_of,
                                                              out_dir=out_dir)   # contract v7
    hashes.update(idle_hashes)
    jd_order = _jd_order_files(con, rows, names, out_dir, state)     # contract v9; never raises (S-P4)
    hashes.update(jd_order["built"])
    counts = {"parts": len(reorder), "historyRows": history_rows, "transferLines": len(transfers),
              "transferSuggestions": len(suggestions), "jdParts": len(jd_rows), "jdIdleParts": len(jd_idle_rows),
              "jdOrderParts": sum(b["parts"] for b in jd_order["branches"]), "jdHistoryRows": jd_order["historyRows"]}
    meta_path = build_files.write_meta(data_as_of, datetime.now(timezone.utc).isoformat(), config.SOURCE,
                                       branches, counts, out_dir=out_dir, jd_branches=jd_branches,
                                       jd_idle_branches=jd_idle_branches, jd_order_branches=jd_order["branches"],
                                       jd_order_as_of=jd_order["asOf"])
    if args.out:
        print(f"[{_ts()}] done: built {len(hashes)} file(s) + _meta.json into {out_dir} (nothing uploaded); "
              f"data as of {data_as_of}; {counts}", flush=True)
        return 0

    previous = ({} if args.force or state.get("source") != config.SOURCE
                else {**state.get("hashes", {}), **state.get("jdOrderHashes", {})})
    to_send = [os.path.join(out_dir, n) for n in pl.changed_files(hashes, previous)]
    access = upload.token()
    print(f"[{_ts()}] uploading {len(to_send) + 1} file(s)", flush=True)
    for path in pl.upload_order(to_send + [meta_path]):
        upload.put_file(path, access)
        print(f"  uploaded {os.path.basename(path)}")

    save_state({"source": config.SOURCE, "dataAsOf": data_as_of, "hashes": hashes, "jdOrderAsOf": jd_order["asOf"],
                "jdOrderBranches": jd_order["branches"], "jdOrderHashes": jd_order["hashes"],
                "jdHistoryRows": jd_order["historyRows"]})
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
