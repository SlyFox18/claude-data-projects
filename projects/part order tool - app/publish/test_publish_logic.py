# projects/part order tool - app/publish/test_publish_logic.py
from datetime import date, datetime, timezone
from decimal import Decimal

import publish_logic as pl


def _row(status, end, start=None, run="r1"):
    return {"run_id": run, "name": "Build_Gold_NonJD_Reorder", "row_type": "item", "status": status,
            "start_utc": start or end, "end_utc": end}


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
