# tools/dp-migration/test_run_item.py
import pytest

from run_item import build_body, split_params


def test_no_params_gives_no_body():
    assert build_body([]) is None


def test_params_become_execution_data():
    body = build_body(["failure_drill=true", "concurrency=4", "label=proto a"])
    assert body == {"executionData": {"parameters": {
        "failure_drill": {"value": "true", "type": "string"},
        "concurrency": {"value": "4", "type": "string"},
        "label": {"value": "proto a", "type": "string"},
    }}}


def test_value_may_contain_equals():
    body = build_body(["expr=a=b"])
    assert body["executionData"]["parameters"]["expr"]["value"] == "a=b"


def test_missing_equals_is_rejected():
    with pytest.raises(ValueError):
        build_body(["justaname"])


def test_split_params_strips_pairs_keeps_positional_order():
    positional, params = split_params(
        ["ws1", "--param", "a=1", "item1", "RunNotebook", "--param", "b=2", "1800"]
    )
    assert positional == ["ws1", "item1", "RunNotebook", "1800"]
    assert params == ["a=1", "b=2"]


def test_split_params_trailing_flag_raises():
    with pytest.raises(ValueError):
        split_params(["ws1", "item1", "RunNotebook", "--param"])
