import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import duckdb  # noqa: E402
import parts_availability_check as pac  # noqa: E402
from parts_availability_check import compare_pair, log_entries, full_loads, pair_loads, persistent_keys, verdict  # noqa: E402


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


def res(**kw):
    r = {"only_lh": set(), "only_dp": set(), "diff": set(), "lh_dup_keys": 0, "dp_dup_keys": 0,
         "extracted_at": ["2026-10-14T12:52:00"]}
    r.update(kw)
    r["bad_keys"] = r["only_lh"] | r["only_dp"] | r["diff"]
    return r


def keys(n, tag="K"):
    return {("1", "D", f"{tag}{i}") for i in range(n)}


def test_verdict_basic():
    assert verdict([])[0] == 2
    assert verdict([res(diff={("1", "D", "A")}), res()]) == (0, [])
    code, problems = verdict([res(diff={("1", "D", "A")}), res(diff={("1", "D", "A")})])
    assert code == 1 and "1 key" in problems[0]


def test_verdict_one_sided_limit_applies_to_a_single_pair():
    assert verdict([res(only_lh=keys(3))])[0] == 0
    assert verdict([res(only_lh=keys(6, "L"), only_dp=keys(5, "D"))])[0] == 1
    assert verdict([res(only_lh=keys(10))])[0] == 0


def test_verdict_diff_limit():
    assert verdict([res(diff=keys(200))])[0] == 0
    code, problems = verdict([res(diff=keys(201))])
    assert code == 1 and "201" in problems[0]


def test_verdict_duplicates_on_either_side_fail():
    assert verdict([res(lh_dup_keys=1)])[0] == 1
    assert verdict([res(dp_dup_keys=1)])[0] == 1


def test_verdict_extracted_at_must_be_one_non_null_value():
    assert verdict([res(extracted_at=[])])[0] == 1
    assert verdict([res(extracted_at=[None])])[0] == 1
    assert verdict([res(extracted_at=["a", "b"])])[0] == 1


def test_verdict_unpaired_lh_only_fails_when_strict():
    assert verdict([res()], unpaired_lh=2) == (0, [])
    code, problems = verdict([res()], unpaired_lh=2, strict_unpaired=True)
    assert code == 1 and "2 LH load(s) had no DP load within 10 minutes" in problems[0]
    assert verdict([], unpaired_lh=2, strict_unpaired=True)[0] == 2


def test_compare_pair_with_real_parquet(tmp_path):
    con = duckdb.connect()
    con.execute("CREATE TABLE t(Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, Description VARCHAR, "
                "Bin VARCHAR, SuperFrom VARCHAR, SuperTo VARCHAR, VendorCode VARCHAR, SellPrice1 DOUBLE, "
                "Comments VARCHAR, OnHandQty INTEGER, PendingQty INTEGER, OnOrder INTEGER, BinQty INTEGER, "
                "ExtractedAtUtc TIMESTAMP)")

    def write(name, rows):
        con.execute("DELETE FROM t")
        for fr, pn, binqty in rows:
            con.execute("INSERT INTO t VALUES ('1', ?, ?, 'd', 'b', NULL, NULL, 'v', 1.5, NULL, 1, 2, 3, ?, "
                        "TIMESTAMP '2026-10-14 12:52:00')", [fr, pn, binqty])
        path = str(tmp_path / name).replace("\\", "/")
        con.execute(f"COPY t TO '{path}' (FORMAT parquet)")
        return path

    common = [("D", "X", 1), ("D", "X ", 1), (None, "N", 1)]
    lh = write("lh.parquet", common + [("D", "Y ", 1), ("D", "LHONLY", 1), ("D", "DIFF", 5), ("D", "DUP", 1)])
    dp = write("dp.parquet", common + [("D", "Y", 1), ("D", "DIFF", 6), ("D", "DUP", 1), ("D", "DUP", 1)])
    r = compare_pair(con, [lh], [dp])
    assert r["only_lh"] == {("1", "D", "LHONLY"), ("1", "D", "Y ")}
    assert r["only_dp"] == {("1", "D", "Y")}
    assert r["diff"] == {("1", "D", "DIFF")}
    assert r["dp_dup_keys"] == 1
    assert r["lh_dup_keys"] == 0
    assert len(r["extracted_at"]) == 1

def test_log_entries_retries_transient_onelake_errors(monkeypatch):
    rows = [("abfss://x/_delta_log/00000000000000000001.json", None, None)]

    class FakeResult:
        def fetchall(self):
            return rows

    class FakeCon:
        calls = 0

        def execute(self, sql):
            FakeCon.calls += 1
            if FakeCon.calls < 3:
                raise duckdb.IOException("IO Error: AzureStorageFileSystem could not open file: Failed to get token")
            return FakeResult()

    sleeps = []
    monkeypatch.setattr(pac.time, "sleep", sleeps.append)
    assert log_entries(FakeCon(), "t") == [(1, None, None)]
    assert FakeCon.calls == 3 and sleeps == [5, 10]


def test_log_entries_reraises_after_last_attempt(monkeypatch):
    class FakeCon:
        calls = 0

        def execute(self, sql):
            FakeCon.calls += 1
            raise duckdb.IOException("could not open file")

    monkeypatch.setattr(pac.time, "sleep", lambda s: None)
    try:
        log_entries(FakeCon(), "t")
        assert False, "should raise"
    except duckdb.IOException:
        pass
    assert FakeCon.calls == 3