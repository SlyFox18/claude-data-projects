# projects/part order tool - app/publish/test_publish_logic.py
from datetime import date, datetime, timezone
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest

import publish_logic as pl

CHI = ZoneInfo("America/Chicago")


def _row(status, end, run="r1"):
    return {"run_id": run, "name": "Build_Gold_NonJD_Reorder", "row_type": "item", "status": status,
            "start_utc": None, "end_utc": end}


def test_latest_item_run_picks_newest_end():
    rows = [_row("Succeeded", datetime(2026, 10, 19, 11, 30), run="a"),
            _row("Failed", datetime(2026, 10, 20, 11, 30), run="b"),
            {**_row("Succeeded", datetime(2026, 10, 21)), "name": "Other"}]
    assert pl.latest_item_run(rows, "Build_Gold_NonJD_Reorder")["run_id"] == "b"


def test_latest_item_run_none_when_absent():
    assert pl.latest_item_run([], "Build_Gold_NonJD_Reorder") is None


def test_decide_publish_rules():
    ok = _row("Succeeded", datetime(2026, 10, 20, 11, 40))
    assert pl.decide_publish(None, {}, "prod") == (False, "no run of Build_Gold_NonJD_Reorder in the log")
    assert pl.decide_publish(_row("Failed", datetime(2026, 10, 20)), {}, "prod")[0] is False
    assert pl.decide_publish(ok, {}, "prod") == (True, "new data")
    state = {"source": "prod", "dataAsOf": pl.iso_utc(ok["end_utc"])}
    assert pl.decide_publish(ok, state, "prod") == (False, "already published")
    assert pl.decide_publish(ok, {**state, "source": "dev"}, "prod") == (True, "new data")
    assert pl.decide_publish(ok, state, "prod", force=True) == (True, "forced")


def test_built_in_run():
    s, e = datetime(2026, 10, 20, 11, 0), datetime(2026, 10, 20, 11, 40)
    assert pl.built_in_run(datetime(2026, 10, 20, 11, 20), s, e)
    assert not pl.built_in_run(datetime(2026, 10, 19, 11, 20), s, e)


def test_iso_utc_naive_is_utc():
    assert pl.iso_utc(datetime(2026, 10, 20, 11, 40)) == "2026-10-20T11:40:00+00:00"


def test_month_labels_newest_first():
    labels = pl.month_labels(date(2026, 2, 1), 4)
    assert labels == ["2026-02", "2026-01", "2025-12", "2025-11"]


def test_history_arrays_fill_zeros_and_sort():
    rows = [{"franchise": "MC", "partNumber": "B", "monthOffset": 1, "salesQty": Decimal("2.00"), "requestCount": 1},
            {"franchise": "MC", "partNumber": "B", "monthOffset": 3, "salesQty": Decimal("1.50"), "requestCount": 2},
            {"franchise": "MC", "partNumber": "A", "monthOffset": 2, "salesQty": None, "requestCount": None}]
    out = pl.history_arrays(rows, months=4)
    assert [p["partNumber"] for p in out] == ["A", "B"]
    assert out[1]["sales"] == [2, 0, 1.5, 0]
    assert out[1]["requests"] == [1, 0, 2, 0]
    assert out[0]["sales"] == [0, 0, 0, 0]


def test_history_arrays_ignores_out_of_range_offsets():
    rows = [{"franchise": "MC", "partNumber": "A", "monthOffset": 61, "salesQty": 5, "requestCount": 5}]
    assert pl.history_arrays(rows, months=60)[0]["sales"] == [0] * 60


def test_clean_value():
    assert pl.clean_value(Decimal("3.00")) == 3
    assert pl.clean_value(Decimal("3.25")) == 3.25
    assert pl.clean_value(datetime(2026, 10, 20, 5, 0)) == "2026-10-20T05:00:00+00:00"
    assert pl.clean_value(date(2026, 10, 20)) == "2026-10-20"
    assert pl.clean_value(float("nan")) is None
    assert pl.clean_value("x ") == "x "


def test_upload_order_meta_last():
    assert pl.upload_order(["out/_meta.json", "out/b.json.gz", "out/a.json.gz"]) == \
        ["out/a.json.gz", "out/b.json.gz", "out/_meta.json"]


def test_changed_files():
    assert pl.changed_files({"a": "1", "b": "2", "c": "3"}, {"a": "1", "b": "9"}) == ["b", "c"]


def test_built_in_run_uses_run_row_start():
    rows = [{"run_id": "r1", "row_type": "run", "name": "Pipeline_DP_Refresh", "status": "InProgress",
             "start_utc": datetime(2026, 10, 20, 11, 15), "end_utc": None},
            {"run_id": "r1", "row_type": "item", "name": pl.ITEM, "status": "Succeeded",
             "start_utc": None, "end_utc": datetime(2026, 10, 20, 11, 40)}]
    assert pl.run_start(rows, "r1") == datetime(2026, 10, 20, 11, 15)
    assert pl.built_in_run(datetime(2026, 10, 20, 11, 20), pl.run_start(rows, "r1"), rows[1]["end_utc"])
    assert not pl.built_in_run(datetime(2026, 10, 20, 11, 20), None, rows[1]["end_utc"])


def test_built_in_run_none_and_edges():
    s, e = datetime(2026, 10, 20, 11, 0), datetime(2026, 10, 20, 11, 40)
    assert not pl.built_in_run(None, s, e)
    assert not pl.built_in_run(s, s, None)
    assert pl.built_in_run(s, s, e)
    assert pl.built_in_run(e, s, e)
    assert not pl.built_in_run(datetime(2026, 10, 20, 11, 41), s, e)
    aware_built = datetime(2026, 10, 20, 6, 20, tzinfo=CHI)  # 11:20 UTC
    assert pl.built_in_run(aware_built, s, e)
    assert pl.built_in_run(datetime(2026, 10, 20, 11, 20), s, datetime(2026, 10, 20, 6, 40, tzinfo=CHI))


def test_run_start_earliest_run_row_only():
    rows = [{"run_id": "r1", "row_type": "run", "start_utc": datetime(2026, 10, 20, 11, 30)},
            {"run_id": "r1", "row_type": "run", "start_utc": datetime(2026, 10, 20, 11, 15)},
            {"run_id": "r1", "row_type": "item", "start_utc": datetime(2026, 10, 20, 9, 0)},
            {"run_id": "r2", "row_type": "run", "start_utc": datetime(2026, 10, 20, 8, 0)}]
    assert pl.run_start(rows, "r1") == datetime(2026, 10, 20, 11, 15)
    assert pl.run_start(rows, "zz") is None


def test_latest_item_run_skips_skipped():
    t1, t2 = datetime(2026, 10, 19, 11, 40), datetime(2026, 10, 20, 11, 40)
    rows = [_row("Succeeded", t1, run="a"), _row("Skipped", t2, run="b")]
    assert pl.latest_item_run(rows)["run_id"] == "a"


def test_latest_item_run_ignores_non_item_and_no_end():
    t = datetime(2026, 10, 19, 11, 40)
    rows = [_row("Succeeded", t, run="a"),
            {**_row("Failed", datetime(2026, 10, 20)), "row_type": "run", "run_id": "b"},
            _row("Failed", None, run="c")]
    assert pl.latest_item_run(rows)["run_id"] == "a"


def test_latest_item_run_mixed_naive_aware():
    rows = [_row("Succeeded", datetime(2026, 10, 20, 11, 0), run="naive"),          # 11:00 UTC
            _row("Succeeded", datetime(2026, 10, 20, 6, 30, tzinfo=CHI), run="aware")]  # 11:30 UTC
    assert pl.latest_item_run(rows)["run_id"] == "aware"


def test_latest_item_run_tie_prefers_failed():
    t = datetime(2026, 10, 20, 11, 40)
    rows = [_row("Succeeded", t, run="a"), _row("Failed", t, run="b")]
    assert pl.latest_item_run(rows)["run_id"] == "b"
    assert pl.latest_item_run(list(reversed(rows)))["run_id"] == "b"


def test_decide_publish_already_published_across_tz():
    state = {"source": "prod", "dataAsOf": pl.iso_utc(datetime(2026, 10, 20, 11, 40))}
    latest = _row("Succeeded", datetime(2026, 10, 20, 6, 40, tzinfo=CHI))
    assert pl.decide_publish(latest, state, "prod") == (False, "already published")


def test_central_month_start_month_boundary():
    assert pl.central_month_start(datetime(2026, 11, 1, 4, 30)) == date(2026, 10, 1)   # 23:30 CDT Oct 31
    assert pl.central_month_start(datetime(2026, 11, 1, 6, 0, tzinfo=timezone.utc)) == date(2026, 11, 1)


def test_iso_utc_aware_chicago():
    assert pl.iso_utc(datetime(2026, 10, 20, 6, 40, tzinfo=CHI)) == "2026-10-20T11:40:00+00:00"


def test_clean_value_bool_and_numbers():
    assert pl.clean_value(True) is True
    assert pl.clean_value(False) is False
    assert pl.clean_value(Decimal("-0.00")) == 0
    assert pl.clean_value(2.0) == 2 and isinstance(pl.clean_value(2.0), int)


def test_clean_value_numpy():
    np = pytest.importorskip("numpy")
    v = pl.clean_value(np.int64(7))
    assert v == 7 and type(v) is int
    b = pl.clean_value(np.bool_(True))
    assert b is True


def test_clean_value_non_finite():
    assert pl.clean_value(Decimal("NaN")) is None
    assert pl.clean_value(float("inf")) is None
    assert pl.clean_value(float("-inf")) is None


def test_history_arrays_drops_zero_and_negative_offsets():
    rows = [{"franchise": "MC", "partNumber": "A", "monthOffset": 0, "salesQty": 9, "requestCount": 9},
            {"franchise": "MC", "partNumber": "A", "monthOffset": -1, "salesQty": 9, "requestCount": 9}]
    out = pl.history_arrays(rows, months=3)
    assert out[0]["sales"] == [0, 0, 0] and out[0]["requests"] == [0, 0, 0]


def test_history_arrays_none_request_count_is_zero():
    rows = [{"franchise": "MC", "partNumber": "A", "monthOffset": 1, "salesQty": 4, "requestCount": None}]
    out = pl.history_arrays(rows, months=2)
    assert out[0]["sales"] == [4, 0] and out[0]["requests"] == [0, 0]


def test_history_arrays_duplicate_slot_raises():
    r = {"franchise": "MC", "partNumber": "A", "monthOffset": 1, "salesQty": 1, "requestCount": 1}
    with pytest.raises(ValueError):
        pl.history_arrays([r, dict(r)], months=2)


# ---- Round 1 (Plan C4): contract version, required columns, excluded branches ----

def test_contract_version_is_2():
    assert pl.CONTRACT_VERSION == 2


def test_require_columns_passes_when_all_present():
    pl.require_columns("T", ["A", "B", "C"], ["A", "C"])


def test_require_columns_names_every_missing_column():
    with pytest.raises(pl.MissingColumnsError) as ei:
        pl.require_columns("Fact_NonJD_Reorder", ["A", "MinimumIgnored"], ["A", "MinDemands", "SupplyUnit"])
    msg = str(ei.value)
    assert "Fact_NonJD_Reorder" in msg and "MinDemands" in msg and "SupplyUnit" in msg
    assert "MinimumIgnored" not in msg
    assert isinstance(ei.value, RuntimeError)


def test_require_columns_is_case_sensitive():
    with pytest.raises(pl.MissingColumnsError, match="MinDemands"):
        pl.require_columns("T", ["mindemands"], ["MinDemands"])


@pytest.mark.parametrize("raw", ["12", "5", "97", "4B", "4b", "93C", " 93c ", "12 "])
def test_excluded_branches(raw):
    assert pl.is_excluded_branch(raw)


@pytest.mark.parametrize("raw", ["1", "92", "93", "4", "125", "", None])
def test_not_excluded_branches(raw):
    assert not pl.is_excluded_branch(raw)


def test_excluded_branch_list_matches_gold():
    assert pl.EXCLUDED_BRANCHES == ("12", "5", "97", "4B", "93C")
