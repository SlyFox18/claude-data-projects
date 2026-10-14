import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from parts_availability_check import full_loads, pair_loads, persistent_keys, verdict  # noqa: E402


def ms(h, m):
    return int(datetime(2026, 10, 14, h, m, tzinfo=timezone.utc).timestamp() * 1000)


def test_full_loads_keeps_whole_table_replacements_only():
    entries = [
        (5, {"operation": "ReplaceTable"}, None), (5, None, {"path": "a.parquet", "modificationTime": ms(12, 52)}),
        (5, None, {"path": "b.parquet", "modificationTime": ms(12, 52)}),
        (6, {"operation": "OPTIMIZE", "timestamp": ms(13, 0)}, None), (6, None, {"path": "c.parquet"}),
        (7, {"operation": "CREATE TABLE AS SELECT", "timestamp": ms(13, 52)}, None), (7, None, {"path": "d.parquet"}),
    ]
    loads = full_loads(entries)
    assert [l["version"] for l in loads] == [5, 7]
    assert loads[0]["adds"] == ["a.parquet", "b.parquet"]
    assert loads[0]["ts"] == datetime(2026, 10, 14, 12, 52, tzinfo=timezone.utc)
    assert loads[1]["ts"] == datetime(2026, 10, 14, 13, 52, tzinfo=timezone.utc)


def load(v, h, m):
    return {"version": v, "ts": datetime(2026, 10, 14, h, m, tzinfo=timezone.utc), "adds": []}


def test_pair_loads_matches_nearest_within_gap_and_uses_each_dp_load_once():
    lh = [load(1, 12, 52), load(2, 13, 52), load(3, 14, 52)]
    dp = [load(10, 11, 52), load(11, 12, 53), load(12, 13, 49), load(13, 15, 30)]
    pairs = pair_loads(lh, dp, max_gap_minutes=10)
    assert [(a["version"], b["version"]) for a, b in pairs] == [(1, 11), (2, 12)]


def test_persistent_keys_needs_two_consecutive_pairs():
    r = [{"bad_keys": {("1", "D", "A"), ("1", "D", "B")}},
         {"bad_keys": {("1", "D", "B")}},
         {"bad_keys": {("1", "D", "A")}}]
    assert persistent_keys(r) == {("1", "D", "B")}


def test_verdict():
    assert verdict([])[0] == 2
    ok = [{"bad_keys": {("1", "D", "A")}}, {"bad_keys": set()}]
    assert verdict(ok) == (0, [])
    code, problems = verdict([{"bad_keys": {("1", "D", "A")}}, {"bad_keys": {("1", "D", "A")}}])
    assert code == 1 and "1 key" in problems[0]
    big = {("1", "D", str(i)) for i in range(501)}
    code, problems = verdict([{"bad_keys": big}])
    assert code == 1 and "501" in problems[0]
