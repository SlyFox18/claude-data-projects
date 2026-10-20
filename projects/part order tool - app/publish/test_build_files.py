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


def _build():
    return build_files.build(REORDER, HISTORY, TRANSFERS, NAMES, AS_OF, MONTH)


def test_files_and_branches(out):
    hashes, branches = _build()
    assert set(hashes) == {"reorder_1.json.gz", "history_1.json.gz", "reorder_92.json.gz",
                           "history_92.json.gz", "surplus.json.gz", "transfers.json.gz"}
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
                    "branches": branches, "counts": counts, "schemaVersion": 1}


def test_nan_rejected():
    with pytest.raises(ValueError):
        build_files._bytes({"x": float("nan")})
