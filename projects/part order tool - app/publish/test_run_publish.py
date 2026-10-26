import json
import os
from datetime import datetime

import pytest

import build_files
import extract
import publish_logic
import run_publish
import upload

START = datetime(2026, 10, 20, 10, 0, 0)
END = datetime(2026, 10, 20, 10, 30, 0)
BUILT = datetime(2026, 10, 20, 10, 20, 0)

DATA_FILES = {"reorder_01.json.gz", "history_01.json.gz", "reorder_02.json.gz", "history_02.json.gz",
              "surplus.json.gz", "transfers.json.gz", "rules.json.gz"}


class Env:
    def __init__(self):
        self.uploaded = []
        self.status = "Succeeded"
        self.built = [BUILT]  # successive built_at results; the last one repeats
        self.end = END
        self.on_hand_02 = 0
        self.rules = [{"id": 1, "ruleName": "Default", "priority": 99.0, "active": True, "archived": None,
                       "franchise": None, "dealerGroupCode": None, "branch": None, "startMonth": None,
                       "endMonth": None, "historyMonths": 12, "minDemands": 3, "weeksOfCover": 4.0,
                       "supplyUnit": None, "minLineValue": None, "maxLineValue": None, "demandBasis": "Sales"}]
        self.checked = 0
        self.fail_on = None   # upload call number (1-based) that raises


@pytest.fixture
def env(tmp_path, monkeypatch):
    e = Env()
    monkeypatch.setattr(build_files, "OUT_DIR", str(tmp_path / "out"))
    monkeypatch.setattr(run_publish, "STATE_FILE", str(tmp_path / "state.json"))
    monkeypatch.setattr(run_publish, "LOCK_FILE", str(tmp_path / "publish.lock"))
    monkeypatch.setattr(extract, "connect", lambda: object())
    monkeypatch.setattr(extract, "log_rows", lambda con: [
        {"run_id": "r1", "name": "run", "row_type": "run", "status": "Succeeded", "start_utc": START, "end_utc": e.end},
        {"run_id": "r1", "name": "Build_Gold_NonJD_Reorder", "row_type": "item", "status": e.status,
         "start_utc": None, "end_utc": e.end}])

    def built_at(con):
        return e.built.pop(0) if len(e.built) > 1 else e.built[0]
    monkeypatch.setattr(extract, "built_at", built_at)

    def check_columns(con):
        e.checked += 1
    monkeypatch.setattr(extract, "check_columns", check_columns)
    monkeypatch.setattr(extract, "reorder", lambda con: [
        {"branch": "01", "franchise": "A", "partNumber": "P1", "onHand": 5, "target": 2, "surplusQty": 3,
         "status": "ok"},
        {"branch": "02", "franchise": "A", "partNumber": "P2", "onHand": e.on_hand_02, "target": 2, "surplusQty": 0,
         "status": "low"}])
    monkeypatch.setattr(extract, "stage_history", lambda con: 1)
    monkeypatch.setattr(extract, "history_for", lambda con, b: [
        {"franchise": "A", "partNumber": "P1", "monthOffset": 1, "salesQty": 1, "requestCount": 1}])
    monkeypatch.setattr(extract, "rules", lambda con: e.rules)
    monkeypatch.setattr(extract, "transfers", lambda con: [])
    monkeypatch.setattr(extract, "branch_names", lambda con: {"01": "One", "02": "Two"})
    monkeypatch.setattr(upload, "token", lambda: "tok")
    def put_file(path, access):
        if e.fail_on is not None and len(e.uploaded) + 1 == e.fail_on:
            raise RuntimeError("HTTP 500 simulated")
        e.uploaded.append(os.path.basename(path))
    monkeypatch.setattr(upload, "put_file", put_file)
    e.state_file = tmp_path / "state.json"
    return e


def test_first_run_publishes_everything_meta_last(env):
    assert run_publish.main([]) == 0
    assert env.uploaded[-1] == "_meta.json"
    assert set(env.uploaded[:-1]) == DATA_FILES
    state = json.loads(env.state_file.read_text())
    assert state["source"] == "dev"
    assert state["dataAsOf"] == "2026-10-20T10:30:00+00:00"
    assert set(state["hashes"]) == DATA_FILES


def test_second_run_is_skipped(env):
    run_publish.main([])
    env.uploaded.clear()
    assert run_publish.main([]) == 0
    assert env.uploaded == []


def test_force_resends_everything(env):
    run_publish.main([])
    env.uploaded.clear()
    assert run_publish.main(["--force"]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES
    assert env.uploaded[-1] == "_meta.json"


def test_upload_failure_keeps_state_and_next_run_resends_all(env):
    env.fail_on = 3
    with pytest.raises(RuntimeError, match="simulated"):
        run_publish.main([])
    assert len(env.uploaded) == 2
    assert "_meta.json" not in env.uploaded
    assert not env.state_file.exists()
    env.fail_on = None
    env.uploaded.clear()
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES
    assert env.uploaded[-1] == "_meta.json"


def test_data_change_uploads_only_changed_files(env):
    run_publish.main([])
    env.uploaded.clear()
    env.end = datetime(2026, 10, 21, 10, 30, 0)
    env.built = [datetime(2026, 10, 21, 10, 20, 0)]
    env.on_hand_02 = 7
    assert run_publish.main([]) == 0
    # reorder/surplus/transfers embed dataAsOf so they change with every run; history files do not
    assert set(env.uploaded[:-1]) == {"reorder_01.json.gz", "reorder_02.json.gz", "surplus.json.gz",
                                      "transfers.json.gz", "rules.json.gz"}
    assert env.uploaded[-1] == "_meta.json"


def test_source_switch_uploads_everything(env):
    env.state_file.write_text(json.dumps({"source": "prod", "dataAsOf": "2026-10-20T10:30:00+00:00",
                                          "hashes": {n: "x" for n in DATA_FILES}}))
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES


def test_corrupt_state_is_first_publish(env, capsys):
    env.state_file.write_text("{not json")
    assert run_publish.main([]) == 0
    assert "WARNING" in capsys.readouterr().out
    assert set(env.uploaded[:-1]) == DATA_FILES
    assert json.loads(env.state_file.read_text())["source"] == "dev"


def test_lock_held_exits_quietly(env, monkeypatch):
    monkeypatch.setattr(run_publish, "_lock", lambda: None)
    assert run_publish.main([]) == 0
    assert env.uploaded == []


def test_failed_latest_run_publishes_nothing(env):
    env.status = "Failed"
    assert run_publish.main([]) == 0
    assert env.uploaded == []
    assert not env.state_file.exists()


def test_built_outside_run_raises(env):
    env.built = [datetime(2026, 10, 20, 9, 0, 0)]
    with pytest.raises(RuntimeError, match="outside run"):
        run_publish.main([])
    assert env.uploaded == []
    assert not env.state_file.exists()


def test_table_rewritten_mid_extract_raises(env):
    env.built = [BUILT, datetime(2026, 10, 20, 10, 25, 0)]
    with pytest.raises(RuntimeError, match="rewritten"):
        run_publish.main([])
    assert env.uploaded == []
    assert not env.state_file.exists()


def test_rules_uploaded_before_meta(env):
    run_publish.main([])
    assert env.uploaded.index("rules.json.gz") < env.uploaded.index("_meta.json")
    assert len(env.uploaded) == len(DATA_FILES) + 1


def test_empty_rules_still_published(env, tmp_path):
    env.rules = []
    assert run_publish.main([]) == 0
    assert "rules.json.gz" in env.uploaded
    import gzip
    d = json.loads(gzip.decompress((tmp_path / "out" / "rules.json.gz").read_bytes()))
    assert d["rules"] == []


def test_missing_rules_table_is_clear_error(env, monkeypatch):
    def boom(con):
        raise IOError("no such table\nsecond line")
    monkeypatch.setattr(extract, "rules", boom)
    with pytest.raises(RuntimeError, match="NonJD_OrderRules") as ei:
        run_publish.main([])
    assert "second line" not in str(ei.value)
    assert isinstance(ei.value.__cause__, IOError)
    assert env.uploaded == []
    assert not env.state_file.exists()


# ---- Round 1 (Plan C4): Gold/publish mismatch fails clearly ----

def test_columns_are_checked_before_extracting(env):
    assert run_publish.main([]) == 0
    assert env.checked == 1


def test_missing_gold_columns_fail_naming_them(env, monkeypatch):
    def check(con):
        raise publish_logic.MissingColumnsError("Fact_NonJD_Reorder is missing column(s) MinDemands, SupplyUnit")
    monkeypatch.setattr(extract, "check_columns", check)
    monkeypatch.setattr(extract, "reorder", lambda con: pytest.fail("read the reorder table after a failed check"))
    with pytest.raises(publish_logic.MissingColumnsError, match="MinDemands, SupplyUnit"):
        run_publish.main([])
    assert env.uploaded == []
    assert not env.state_file.exists()


def test_missing_rules_columns_fail_before_extracting(env, monkeypatch):
    def check(con):
        raise publish_logic.MissingColumnsError("NonJD_OrderRules is missing column(s) Archived")
    monkeypatch.setattr(extract, "check_columns", check)
    monkeypatch.setattr(extract, "reorder", lambda con: pytest.fail("extracted after a failed check"))
    monkeypatch.setattr(extract, "rules", lambda con: pytest.fail("extracted after a failed check"))
    with pytest.raises(publish_logic.MissingColumnsError, match="Archived") as ei:
        run_publish.main([])
    assert "not found or unreadable" not in str(ei.value)
    assert env.uploaded == []


def test_meta_carries_contract_version(env, tmp_path):
    run_publish.main([])
    meta = json.loads((tmp_path / "out" / "_meta.json").read_bytes())
    assert meta["contractVersion"] == 2 and meta["schemaVersion"] == 1
