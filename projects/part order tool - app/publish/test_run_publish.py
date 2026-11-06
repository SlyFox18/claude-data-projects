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
              "surplus.json.gz", "transfers.json.gz", "rules.json.gz", "transfer_rules.json.gz",
              "transfer_suggestions.json.gz", "purchases.json.gz", "jd_01.json.gz", "jd_12.json.gz",
              "jd_idle_01.json.gz", "jd_idle_4.json.gz"}
ROUND2 = {"pendingQty": 0.0, "slc": None, "source": None, "commodityCode": None, "phaseInQty": None,
          "phaseInEnds": None, "phaseInOn": None, "phaseInActive": False, "phaseInEndReason": None,
          "appInboundQty": 0, "appOutboundQty": 0, "transferRuleId": None, "transferRuleName": "Built-in default",
          "excessSupply": 12.0, "excessUnit": "Months", "allowSend": True, "allowReceive": True, "redistMax": 6.0,
          "redistUnit": "Months", "redistMinValue": 0.0, "excessKeep": 2, "freeExcess": 0, "convNeed": 0,
          "redistCap": 0, "redistEligible": False, "suggestedInQty": 0, "suggestedConvInQty": 0,
          "suggestedOutQty": 0, "lastReceived": None,
          "equipStockValue": 0}
JD_ROW = {"partNumber": "J1", "description": "Pin", "cost": 1.5, "onHand": 0, "onOrder": 0, "packageQty": 1,
          "returnIndicator": "R", "source": "FF", "slc": "15C", "superTo": "", "commodityCode": "", "commodityGroup":
          "Other", "dealerGroupCode": "", "minimumQty": None, "maximumQty": None, "sales12": 2, "salesPrev12": 0,
          "corpDemands": 2, "binQty": 0, "piecesInSet": None, "pisInvoices": 0, "pisSalesQty": 0, "pisQty": 0,
          "pisQtyInvoices": 0, "pisMultipleInvoices": 0}
JD_IDLE_ROW = {"partNumber": "I1", "description": "Bolt", "cost": 2.25, "onOrder": 0, "packageQty": 1,
               "returnIndicator": "R", "source": "FF", "slc": "15C", "superTo": "", "commodityCode": "",
               "commodityGroup": "Other", "dealerGroupCode": "770", "minimumQty": None, "maximumQty": None}


class Env:
    def __init__(self):
        self.uploaded = []
        self.status = "Succeeded"
        self.built = [BUILT]  # successive built_at results; the last one repeats
        self.jd_built = [BUILT]  # the same for Fact_CorpParts_JD
        self.idle_built = [BUILT]  # and for Fact_CorpParts_JD_Idle
        self.end = END
        self.on_hand_02 = 0
        self.rules = [{"id": 1, "ruleName": "Default", "priority": 99.0, "active": True, "archived": None,
                       "franchise": None, "dealerGroupCode": None, "branch": None, "startMonth": None,
                       "endMonth": None, "historyMonths": 12, "minDemands": 3, "weeksOfCover": 4.0,
                       "supplyUnit": None, "minLineValue": None, "maxLineValue": None, "demandBasis": "Sales",
                       "slc": None, "source": None, "vendorCode": None, "productGroup": None,
                       "commodityCode": None}]
        self.trules = []
        self.suggestions = [{"kind": "Conventional", "franchise": "A", "partNumber": "P2", "fromBranch": "01",
                             "toBranch": "02", "seq": 1, "qty": 2, "fromCost": 1.5, "toCost": 1.5, "value": 3.0,
                             "description": "x", "fromBin": None, "toBin": None}]
        self.committed_on = []   # build dates extract.committed was called with
        self.checked = 0
        self.fail_on = None   # upload call number (1-based) that raises
        self.jd_status = None   # Plan S: Build_Gold_JD_Reorder's log row status; None = it has no run
        self.jd_end = END
        self.jd_order_built = [BUILT]
        self.jd_cost = 1.5


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
         "start_utc": None, "end_utc": e.end}] + ([] if e.jd_status is None else [
             {"run_id": "r2", "name": "run", "row_type": "run", "status": "Succeeded", "start_utc": START,
              "end_utc": e.jd_end},
             {"run_id": "r2", "name": "Build_Gold_JD_Reorder", "row_type": "item", "status": e.jd_status,
              "start_utc": None, "end_utc": e.jd_end}]))
    # Plan S: the JD order extracts (only called when Build_Gold_JD_Reorder has a successful run)
    monkeypatch.setattr(extract, "jd_order_available", lambda con: True)

    def jd_order_built_at(con):
        return e.jd_order_built.pop(0) if len(e.jd_order_built) > 1 else e.jd_order_built[0]
    monkeypatch.setattr(extract, "jd_order_built_at", jd_order_built_at)
    monkeypatch.setattr(extract, "jd_order", lambda con: [
        {"branch": "12", "franchise": "D", "partNumber": "J1", "onHand": 1, "target": 2, "surplusQty": 0, "status": "OK",
         "cost": e.jd_cost, "pendingQty": 0.0, "slc": None, "source": None, "commodityCode": None, "phaseInQty": None,
         "phaseInEnds": None, "phaseInOn": None, "phaseInActive": False, "phaseInEndReason": None,
         "lastReceived": None, "equipStockValue": 0}])
    monkeypatch.setattr(extract, "stage_jd_history", lambda con: 1)
    monkeypatch.setattr(extract, "jd_history_for", lambda con, b: [
        {"franchise": "D", "partNumber": "J1", "monthOffset": 1, "salesQty": 1, "requestCount": 1}])
    monkeypatch.setattr(extract, "jd_rules", lambda con: e.rules)

    def built_at(con):
        return e.built.pop(0) if len(e.built) > 1 else e.built[0]
    monkeypatch.setattr(extract, "built_at", built_at)

    def jd_built_at(con):
        return e.jd_built.pop(0) if len(e.jd_built) > 1 else e.jd_built[0]
    monkeypatch.setattr(extract, "jd_built_at", jd_built_at)
    # branch 12 is excluded from the reorder files (D6) but written for JD (L-D5)
    monkeypatch.setattr(extract, "jd_parts", lambda con: [
        {"branch": "12", **JD_ROW}, {"branch": "01", **JD_ROW}, {"branch": "01", **JD_ROW, "partNumber": "J2"}])

    def jd_idle_built_at(con):
        return e.idle_built.pop(0) if len(e.idle_built) > 1 else e.idle_built[0]
    monkeypatch.setattr(extract, "jd_idle_built_at", jd_idle_built_at)
    monkeypatch.setattr(extract, "jd_idle_parts", lambda con: [
        {"branch": "4", **JD_IDLE_ROW}, {"branch": "01", **JD_IDLE_ROW},
        {"branch": "01", **JD_IDLE_ROW, "partNumber": "I2", "onOrder": -1}, {"branch": "4", **JD_IDLE_ROW,
                                                                             "partNumber": "I0"}])

    def check_columns(con):
        e.checked += 1
    monkeypatch.setattr(extract, "check_columns", check_columns)
    monkeypatch.setattr(extract, "reorder", lambda con: [
        {"branch": "01", "franchise": "A", "partNumber": "P1", "onHand": 5, "target": 2, "surplusQty": 3,
         "status": "ok", **ROUND2},
        {"branch": "02", "franchise": "A", "partNumber": "P2", "onHand": e.on_hand_02, "target": 2, "surplusQty": 0,
         "status": "low", **ROUND2}])
    monkeypatch.setattr(extract, "stage_history", lambda con: 1)
    monkeypatch.setattr(extract, "history_for", lambda con, b: [
        {"franchise": "A", "partNumber": "P1", "monthOffset": 1, "salesQty": 1, "requestCount": 1}])
    monkeypatch.setattr(extract, "rules", lambda con: e.rules)
    monkeypatch.setattr(extract, "transfers", lambda con: [])
    monkeypatch.setattr(extract, "transfer_rules", lambda con: e.trules)
    monkeypatch.setattr(extract, "suggestions", lambda con: e.suggestions)
    monkeypatch.setattr(extract, "purchases", lambda con: [{"branch": "01", "franchise": "A", "purchases12": 12.5}])

    def committed(con, build_date):
        e.committed_on.append(build_date)
        return []
    monkeypatch.setattr(extract, "committed", committed)
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
                                      "transfers.json.gz", "rules.json.gz", "transfer_rules.json.gz",
                                      "transfer_suggestions.json.gz", "purchases.json.gz", "jd_01.json.gz",
                                      "jd_12.json.gz", "jd_idle_01.json.gz", "jd_idle_4.json.gz"}
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
    assert meta["contractVersion"] == 9 and meta["schemaVersion"] == 1



# ---- Round 2 (Plan E6): contract v3 files, --out local build ----

def test_meta_counts_transfer_suggestions(env, tmp_path):
    run_publish.main([])
    meta = json.loads((tmp_path / "out" / "_meta.json").read_bytes())
    assert meta["counts"]["transferSuggestions"] == 1


def test_suggestions_uploaded_before_meta(env):
    run_publish.main([])
    assert env.uploaded.index("transfer_suggestions.json.gz") < env.uploaded.index("_meta.json")
    assert env.uploaded.index("transfer_rules.json.gz") < env.uploaded.index("_meta.json")


def test_committed_lines_use_the_central_date_of_the_build(env):
    from datetime import date
    env.built = [datetime(2026, 10, 21, 4, 30, 0)]          # 2026-10-20 23:30 Central
    env.end = datetime(2026, 10, 21, 4, 40, 0)
    run_publish.main([])
    assert env.committed_on == [date(2026, 10, 20)]


def test_out_builds_locally_without_upload_state_or_lock(env, tmp_path, monkeypatch):
    monkeypatch.setattr(run_publish, "_lock", lambda: pytest.fail("took the lock"))
    monkeypatch.setattr(upload, "token", lambda: pytest.fail("asked for a token"))
    dest = tmp_path / "local" / "v3"
    assert run_publish.main(["--out", str(dest)]) == 0
    assert env.uploaded == []
    assert not env.state_file.exists()
    assert set(os.listdir(dest)) == DATA_FILES | {"_meta.json"}
    assert not (tmp_path / "out").exists()      # the publish's own output folder is untouched
    assert json.loads((dest / "_meta.json").read_bytes())["contractVersion"] == 9


def test_out_ignores_publish_state(env, tmp_path):
    run_publish.main([])
    env.uploaded.clear()
    state = env.state_file.read_text()
    dest = tmp_path / "v3"
    assert run_publish.main(["--out", str(dest), "--force"]) == 0
    assert env.uploaded == [] and env.state_file.read_text() == state
    assert set(os.listdir(dest)) == DATA_FILES | {"_meta.json"}


def test_out_still_refuses_a_failed_run(env, tmp_path):
    env.status = "Failed"
    assert run_publish.main(["--out", str(tmp_path / "v3")]) == 0
    assert not (tmp_path / "v3").exists()


# ---- Round 3 (Plan I3): contract v4 ----

def test_purchases_file_uploaded_before_meta(env):
    run_publish.main([])
    assert env.uploaded.index("purchases.json.gz") < env.uploaded.index("_meta.json")


def test_gold_without_round3_fails_before_writing(env, tmp_path, monkeypatch):
    def check(con):
        raise publish_logic.MissingColumnsError("Fact_NonJD_Reorder is missing column(s) LastReceived")
    monkeypatch.setattr(extract, "check_columns", check)
    monkeypatch.setattr(extract, "purchases", lambda con: pytest.fail("extracted after a failed check"))
    with pytest.raises(publish_logic.MissingColumnsError, match="LastReceived"):
        run_publish.main(["--out", str(tmp_path / "v4")])
    assert not (tmp_path / "v4").exists()


# ---- Plan L (L4): contract v6, jd_<branch>.json.gz ----

def test_meta_has_jd_branches_and_count(env, tmp_path):
    run_publish.main([])
    meta = json.loads((tmp_path / "out" / "_meta.json").read_bytes())
    assert meta["jdBranches"] == [{"branch": "01", "name": "One", "parts": 2},
                                  {"branch": "12", "name": "12", "parts": 1}]
    assert meta["counts"]["jdParts"] == 3
    assert [b["branch"] for b in meta["branches"]] == ["01", "02"]       # branch 12 stays out of the reorder list


def test_jd_files_uploaded_before_meta(env, tmp_path):
    run_publish.main([])
    assert {"jd_01.json.gz", "jd_12.json.gz"} <= set(env.uploaded[:-1]) and env.uploaded[-1] == "_meta.json"
    import gzip
    d = json.loads(gzip.decompress((tmp_path / "out" / "jd_01.json.gz").read_bytes()))
    assert d["dataAsOf"] == "2026-10-20T10:30:00+00:00" and [p["partNumber"] for p in d["parts"]] == ["J1", "J2"]


def test_gold_without_jd_table_fails_before_writing(env, tmp_path, monkeypatch):
    def check(con):
        raise RuntimeError("Fact_CorpParts_JD not found or unreadable in the dev DP_Presentation lakehouse")
    monkeypatch.setattr(extract, "check_columns", check)
    monkeypatch.setattr(extract, "jd_parts", lambda con: pytest.fail("extracted after a failed check"))
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD"):
        run_publish.main(["--out", str(tmp_path / "v6")])
    assert not (tmp_path / "v6").exists()
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD"):
        run_publish.main([])
    assert env.uploaded == [] and not env.state_file.exists()


def test_jd_built_outside_run_raises(env):
    env.jd_built = [datetime(2026, 10, 19, 10, 20, 0)]
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD BuiltAtUtc.*outside run"):
        run_publish.main([])
    assert env.uploaded == [] and not env.state_file.exists()


def test_jd_table_rewritten_mid_extract_raises(env):
    env.jd_built = [BUILT, datetime(2026, 10, 20, 10, 25, 0)]
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD was rewritten"):
        run_publish.main([])
    assert env.uploaded == [] and not env.state_file.exists()


# ---- Plan M (M3): contract v7, jd_idle_<branch>.json.gz ----

def test_meta_has_jd_idle_branches_and_count(env, tmp_path):
    run_publish.main([])
    meta = json.loads((tmp_path / "out" / "_meta.json").read_bytes())
    assert meta["jdIdleBranches"] == [{"branch": "01", "name": "One", "parts": 2},
                                      {"branch": "4", "name": "4", "parts": 2}]
    assert meta["counts"]["jdIdleParts"] == 4 and meta["counts"]["jdParts"] == 3
    assert [b["branch"] for b in meta["jdBranches"]] == ["01", "12"]


def test_idle_files_uploaded_before_meta(env, tmp_path):
    run_publish.main([])
    assert {"jd_idle_01.json.gz", "jd_idle_4.json.gz"} <= set(env.uploaded[:-1]) and env.uploaded[-1] == "_meta.json"
    import gzip
    d = json.loads(gzip.decompress((tmp_path / "out" / "jd_idle_4.json.gz").read_bytes()))
    assert d["dataAsOf"] == "2026-10-20T10:30:00+00:00" and [p["partNumber"] for p in d["parts"]] == ["I0", "I1"]
    d = json.loads(gzip.decompress((tmp_path / "out" / "jd_idle_01.json.gz").read_bytes()))
    assert [p["onOrder"] for p in d["parts"]] == [0, -1]


def test_gold_without_idle_table_fails_before_writing(env, tmp_path, monkeypatch):
    def check(con):
        raise RuntimeError("Fact_CorpParts_JD_Idle not found or unreadable in the dev DP_Presentation lakehouse")
    monkeypatch.setattr(extract, "check_columns", check)
    monkeypatch.setattr(extract, "jd_idle_parts", lambda con: pytest.fail("extracted after a failed check"))
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD_Idle"):
        run_publish.main(["--out", str(tmp_path / "v7")])
    assert not (tmp_path / "v7").exists()
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD_Idle"):
        run_publish.main([])
    assert env.uploaded == [] and not env.state_file.exists()


def test_idle_built_outside_run_raises(env):
    env.idle_built = [datetime(2026, 10, 19, 10, 20, 0)]
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD_Idle BuiltAtUtc.*outside run"):
        run_publish.main([])
    assert env.uploaded == [] and not env.state_file.exists()


def test_idle_built_by_another_build_than_the_active_table_raises(env):
    # both tables come from one Gold run with one BuiltAtUtc (Part 5); a different value inside the run means
    # they were written by two builds
    env.idle_built = [datetime(2026, 10, 20, 10, 21, 0)]
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD_Idle BuiltAtUtc.*Fact_CorpParts_JD"):
        run_publish.main([])
    assert env.uploaded == [] and not env.state_file.exists()


def test_idle_table_rewritten_mid_extract_raises(env):
    env.idle_built = [BUILT, datetime(2026, 10, 20, 10, 25, 0)]
    with pytest.raises(RuntimeError, match="Fact_CorpParts_JD_Idle was rewritten"):
        run_publish.main([])
    assert env.uploaded == [] and not env.state_file.exists()


def test_positive_idle_on_order_fails_before_meta(env, tmp_path, monkeypatch):
    monkeypatch.setattr(extract, "jd_idle_parts", lambda con: [{"branch": "4", **JD_IDLE_ROW, "onOrder": 2}])
    with pytest.raises(ValueError, match="onOrder"):
        run_publish.main([])
    assert env.uploaded == [] and not (tmp_path / "out" / "_meta.json").exists()


# ---- Plan S (contract 9): the JD order files; S-P4, the JD publish can't block non-JD ----
JD_FILES = {"jdorder_12.json.gz", "jdhistory_12.json.gz", "jd_rules.json.gz"}
JD_END = datetime(2026, 10, 20, 10, 45, 0)
JD_BUILT = datetime(2026, 10, 20, 10, 40, 0)


def _jd_ok(env, end=JD_END, built=JD_BUILT):
    env.jd_status, env.jd_end, env.jd_order_built = "Succeeded", end, [built]


def test_jd_files_are_published_with_their_own_as_of(env, tmp_path):
    _jd_ok(env)
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES | JD_FILES and env.uploaded[-1] == "_meta.json"
    meta = json.loads((tmp_path / "out" / "_meta.json").read_bytes())
    assert meta["jdOrderBranches"] == [{"branch": "12", "name": "12", "parts": 1}]
    assert meta["jdOrderAsOf"] == "2026-10-20T10:45:00+00:00"
    assert meta["counts"]["jdOrderParts"] == 1 and meta["counts"]["jdHistoryRows"] == 1
    state = json.loads(env.state_file.read_text())
    assert state["jdOrderAsOf"] == meta["jdOrderAsOf"] and state["jdOrderBranches"] == meta["jdOrderBranches"]
    assert set(state["jdOrderHashes"]) == JD_FILES


def test_no_jd_run_publishes_non_jd_with_empty_jd_fields(env, tmp_path):
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES
    meta = json.loads((tmp_path / "out" / "_meta.json").read_bytes())
    assert meta["contractVersion"] == 9 and meta["jdOrderBranches"] == [] and meta["jdOrderAsOf"] is None
    assert meta["counts"]["jdOrderParts"] == 0 and meta["counts"]["jdHistoryRows"] == 0


def test_a_jd_build_that_finishes_later_triggers_its_own_publish_of_only_the_jd_files(env):
    assert run_publish.main([]) == 0
    env.uploaded.clear()
    _jd_ok(env)
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == JD_FILES | set(publish_logic.ALWAYS_UPLOAD)
    assert env.uploaded[-1] == "_meta.json"
    env.uploaded.clear()
    assert run_publish.main([]) == 0                  # already published
    assert env.uploaded == []


def test_failed_jd_build_keeps_what_is_published_and_non_jd_goes_ahead(env, tmp_path):
    _jd_ok(env)
    assert run_publish.main([]) == 0
    first = json.loads(env.state_file.read_text())
    env.uploaded.clear()
    env.status, env.jd_status = "Succeeded", "Failed"
    env.end = datetime(2026, 10, 21, 10, 30, 0)
    env.built = [datetime(2026, 10, 21, 10, 20, 0)]
    env.on_hand_02 = 7
    assert run_publish.main([]) == 0
    assert "reorder_02.json.gz" in env.uploaded and not JD_FILES & set(env.uploaded)
    state = json.loads(env.state_file.read_text())
    assert state["dataAsOf"] == "2026-10-21T10:30:00+00:00"
    for k in ("jdOrderAsOf", "jdOrderBranches", "jdOrderHashes"):
        assert state[k] == first[k]
    meta = json.loads((tmp_path / "out" / "_meta.json").read_bytes())
    assert meta["jdOrderAsOf"] == first["jdOrderAsOf"] and meta["jdOrderBranches"] == first["jdOrderBranches"]
    assert meta["counts"]["jdOrderParts"] == 1 and meta["counts"]["jdHistoryRows"] == 1


def test_force_with_carried_jd_files_does_not_look_for_them(env):
    _jd_ok(env)
    assert run_publish.main([]) == 0
    env.uploaded.clear()
    env.jd_status = "Failed"
    assert run_publish.main(["--force"]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES


def test_jd_table_not_from_that_run_is_kept_as_published(env):
    _jd_ok(env, built=datetime(2026, 10, 19, 1, 0, 0))
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES
    assert json.loads(env.state_file.read_text())["jdOrderHashes"] == {}


def test_jd_table_rewritten_while_extracting_is_kept_as_published(env):
    env.jd_status, env.jd_end = "Succeeded", JD_END
    env.jd_order_built = [JD_BUILT, datetime(2026, 10, 20, 10, 44, 0)]
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES


def test_jd_table_missing_is_kept_as_published(env, monkeypatch):
    _jd_ok(env)
    monkeypatch.setattr(extract, "jd_order_available", lambda con: False)
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES


def test_a_jd_file_over_the_limit_does_not_block_non_jd(env, monkeypatch):
    _jd_ok(env)

    def too_big(*a, **kw):
        raise ValueError("jdorder_12.json.gz would be 5,000,000 bytes, over the upload limit")
    monkeypatch.setattr(build_files, "build_jd_order", too_big)
    assert run_publish.main([]) == 0
    assert set(env.uploaded[:-1]) == DATA_FILES


def test_non_jd_hashes_are_the_same_with_and_without_the_jd_build(env, tmp_path):
    run_publish.main([])
    without = json.loads(env.state_file.read_text())["hashes"]
    env.state_file.unlink()
    _jd_ok(env)
    run_publish.main([])
    with_jd = json.loads(env.state_file.read_text())["hashes"]
    assert {k: v for k, v in with_jd.items() if k not in JD_FILES} == without
