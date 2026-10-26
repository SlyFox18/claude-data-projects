"""Tests for build_files (no config, no network)."""
import gzip
import json
import os
from datetime import date
from decimal import Decimal

import pytest

import build_files

AS_OF = "2026-10-20T11:40:00+00:00"
MONTH = date(2026, 10, 1)
NAMES = {"1": "Lubbock"}


def _row(branch, part, surplus, cost="12.50"):
    return {"branch": branch, "franchise": "A", "partNumber": part, "onHand": 5, "target": 3,
            "surplusQty": surplus, "status": "OK", "cost": Decimal(cost)}


REORDER = [_row("92", "P2", 0), _row("1", "P1", 4), _row("1", "P3", 0), _row("92", "P4", 2)]
HISTORY = [
    {"branch": "1", "franchise": "A", "partNumber": "P1", "monthOffset": 1, "salesQty": Decimal("3"), "requestCount": 2},
    {"branch": "92", "franchise": "A", "partNumber": "P2", "monthOffset": 60, "salesQty": 1, "requestCount": 1},
]
TRANSFERS = [{"toBranch": "1", "fromBranch": "92", "partNumber": "P1", "ticket": "T1", "line": 1,
              "orderQty": Decimal("2"), "date": date(2026, 10, 1)}]


@pytest.fixture
def out(tmp_path, monkeypatch):
    d = tmp_path / "out"
    monkeypatch.setattr(build_files, "OUT_DIR", str(d))
    return d


def _read(out, name):
    return json.loads(gzip.decompress((out / name).read_bytes()))


def _hist(b):
    return [h for h in HISTORY if h["branch"].strip() == b]


RULES = [
    {"id": 2, "ruleName": "B", "priority": 2.0, "active": True, "archived": None, "franchise": None,
     "dealerGroupCode": "770", "branch": "1", "startMonth": None, "endMonth": None, "historyMonths": 12,
     "minDemands": Decimal("3"), "weeksOfCover": 6.5, "supplyUnit": None, "minLineValue": 25.0,
     "maxLineValue": Decimal("500.50"), "demandBasis": "Sales", "minActiveMonths": 3, "extra": "dropped"},
    {"id": 1, "ruleName": "A", "priority": 1.0, "active": False, "archived": True, "franchise": "A",
     "dealerGroupCode": None, "branch": None, "startMonth": None, "endMonth": None, "historyMonths": 6,
     "minDemands": 2, "weeksOfCover": 4.0, "supplyUnit": "Months", "minLineValue": None, "maxLineValue": None,
     "demandBasis": "Requests"},
]
RULE_KEYS = {"id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode", "branch",
             "startMonth", "endMonth", "historyMonths", "minDemands", "weeksOfCover", "supplyUnit", "minLineValue",
             "maxLineValue", "demandBasis"}


def _build(reorder=None, rules=None):
    return build_files.build(REORDER if reorder is None else reorder, _hist, TRANSFERS, NAMES, AS_OF, MONTH,
                             RULES if rules is None else rules)


def test_files_and_branches(out):
    hashes, branches = _build()
    assert set(hashes) == {"reorder_1.json.gz", "history_1.json.gz", "reorder_92.json.gz",
                           "history_92.json.gz", "surplus.json.gz", "transfers.json.gz", "rules.json.gz"}
    assert sorted(os.listdir(out)) == sorted(hashes)
    assert [b["branch"] for b in branches] == ["1", "92"]
    assert branches[0]["name"] == "Lubbock"
    assert branches[1]["name"] == "92"
    assert [b["parts"] for b in branches] == [2, 2]


def test_reorder_file(out):
    _build()
    data = _read(out, "reorder_1.json.gz")
    assert set(data) == {"branch", "dataAsOf", "parts"}
    assert data["branch"] == "1" and data["dataAsOf"] == AS_OF
    assert [p["partNumber"] for p in data["parts"]] == ["P1", "P3"]
    assert all("branch" not in p for p in data["parts"])
    assert data["parts"][0]["cost"] == 12.5 and isinstance(data["parts"][0]["cost"], float)


def test_history_file(out):
    _build()
    data = _read(out, "history_1.json.gz")
    assert len(data["months"]) == 60
    assert data["months"][0] == "2026-10"
    assert data["months"][1] == "2026-09"
    part = data["parts"][0]
    assert len(part["sales"]) == 60 and len(part["requests"]) == 60
    assert part["sales"][0] == 3 and part["requests"][0] == 2


def test_surplus_only_positive_across_branches(out):
    _build()
    parts = _read(out, "surplus.json.gz")["parts"]
    assert sorted((p["branch"], p["partNumber"]) for p in parts) == [("1", "P1"), ("92", "P4")]


def test_transfers_file(out):
    _build()
    lines = _read(out, "transfers.json.gz")["lines"]
    assert lines[0]["date"] == "2026-10-01" and lines[0]["orderQty"] == 2


def test_deterministic(out):
    h1, _ = _build()
    h2, _ = _build()
    assert h1 == h2


def test_write_meta_plain_json(out):
    _, branches = _build()
    counts = {"parts": 4}
    path = build_files.write_meta(AS_OF, "2026-10-20T12:00:00+00:00", "dev", branches, counts)
    raw = open(path, "rb").read()
    assert raw[:2] != b"\x1f\x8b"
    meta = json.loads(raw)
    assert meta == {"dataAsOf": AS_OF, "publishedAt": "2026-10-20T12:00:00+00:00", "source": "dev",
                    "branches": branches, "counts": counts, "schemaVersion": 1, "contractVersion": 2}


def test_nan_rejected():
    with pytest.raises(ValueError):
        build_files._bytes({"x": float("nan")})


def test_stale_files_cleared(out):
    _build()
    hashes, _ = _build([r for r in REORDER if r["branch"] == "1"])
    assert sorted(os.listdir(out)) == sorted(hashes)
    assert "reorder_92.json.gz" not in hashes


def test_branch_without_history_gives_empty_parts(out):
    _build([_row("7", "P9", 0)])
    assert _read(out, "history_7.json.gz")["parts"] == []


def test_numeric_branch_order(out):
    _, branches = _build([_row("10", "A", 0), _row("2", "B", 0)])
    assert [b["branch"] for b in branches] == ["2", "10"]


def test_branch_key_collision_raises(out):
    with pytest.raises(ValueError, match="1"):
        _build([_row("1", "A", 0), _row("1 ", "B", 0)])


def test_unsafe_branch_raises(out):
    with pytest.raises(ValueError):
        _build([_row("../x", "A", 0)])


def test_rules_file(out):
    hashes, _ = _build()
    assert "rules.json.gz" in hashes
    d = _read(out, "rules.json.gz")
    assert d["dataAsOf"] == AS_OF
    assert [r["id"] for r in d["rules"]] == [1, 2]
    assert all(set(r) == RULE_KEYS for r in d["rules"])
    r1, r2 = d["rules"]
    assert r2["priority"] == 2 and isinstance(r2["priority"], int)
    assert r2["minDemands"] == 3 and isinstance(r2["minDemands"], int)
    assert r2["weeksOfCover"] == 6.5
    assert r2["startMonth"] is None and r2["active"] is True
    # blank SupplyUnit / Archived stay null (the engine reads them as Weeks / No, as Gold does)
    assert r2["supplyUnit"] is None and r2["archived"] is None
    assert r2["minLineValue"] == 25 and r2["maxLineValue"] == 500.5
    assert r1["supplyUnit"] == "Months" and r1["archived"] is True
    assert r1["minLineValue"] is None and r1["maxLineValue"] is None
    # MinActiveMonths is left in the list unused (D1) and is not published
    assert "minActiveMonths" not in r2


def test_rules_empty_still_written_and_deterministic(out):
    h1, _ = _build(rules=[])
    assert _read(out, "rules.json.gz")["rules"] == []
    h2, _ = _build(rules=[])
    assert h1["rules.json.gz"] == h2["rules.json.gz"]


def test_rules_row_missing_key_raises(out):
    bad = [{k: v for k, v in RULES[0].items() if k != "weeksOfCover"}]
    with pytest.raises(ValueError, match="weeksOfCover"):
        _build(rules=bad)


@pytest.mark.parametrize("key", ["minDemands", "supplyUnit", "minLineValue", "maxLineValue", "archived"])
def test_rules_row_missing_new_key_raises(out, key):
    bad = [{k: v for k, v in RULES[0].items() if k != key}]
    with pytest.raises(ValueError, match=key):
        _build(rules=bad)


# ---- Round 1: excluded branches (D6) ----

def test_transfers_to_or_from_excluded_branches_are_dropped(out):
    lines = [dict(TRANSFERS[0], toBranch=to, fromBranch=fr, ticket=f"T{i}")
             for i, (to, fr) in enumerate([("1", "92"), ("12", "1"), ("1", "93C "), ("4b", "92"), ("92", "5"),
                                           (" 97", "1"), ("", "1"), ("1", None)])]
    build_files.build(REORDER, _hist, lines, NAMES, AS_OF, MONTH, RULES)
    got = [t["ticket"] for t in _read(out, "transfers.json.gz")["lines"]]
    assert got == ["T0", "T6", "T7"]


@pytest.mark.parametrize("branch", ["12", "93C", "4b", "5 "])
def test_reorder_row_at_excluded_branch_raises(out, branch):
    with pytest.raises(ValueError, match="excluded"):
        _build([_row("1", "P1", 0), _row(branch, "P2", 3)])
    assert not (out / f"reorder_{branch.strip()}.json.gz").exists()


def test_meta_has_contract_version(out):
    _, branches = _build()
    path = build_files.write_meta(AS_OF, AS_OF, "dev", branches, {})
    assert json.loads(open(path, "rb").read())["contractVersion"] == 2


@pytest.mark.parametrize("bad", [float("nan"), float("inf"), float("-inf"), Decimal("NaN")])
@pytest.mark.parametrize("key", ["startMonth", "weeksOfCover", "minLineValue", "maxLineValue", "minDemands"])
def test_rules_non_finite_number_fails(out, key, bad):
    rules = [dict(RULES[0], **{key: bad}), RULES[1]]
    with pytest.raises(ValueError, match=f"rule 2.*{key}.*not a finite number"):
        _build(rules=rules)
    assert not (out / "rules.json.gz").exists()
