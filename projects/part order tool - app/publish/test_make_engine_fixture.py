"""Tests for make_engine_fixture: stratification, determinism, file shape."""
import gzip
import json
import os

import pytest

import make_engine_fixture as mef

STATUSES = ("Masked", "NoRecentActivity", "NotStocked", "OutOfStock", "Reorder", "OK")


def _gold(pn, status="OK", **kw):
    g = {"franchise": "MC", "partNumber": pn, "status": status, "ruleName": "Default", "minimumIgnored": False,
         "demandBasis": "UnitsSold", "isMasked": status == "Masked", "minOverride": None, "minimumQty": None,
         "onHand": 1, "onOrder": 0, "windowDemand": 0, "effectiveMin": 0, "calcTarget": 0, "activeMonths": 0,
         "minActiveMonths": 3}
    g.update(kw)
    return g


def _write_output(tmp_path, branches):
    """branches: {key: [gold rows]}; every even-numbered part gets a history row."""
    meta = {"branches": [{"branch": b, "name": b, "parts": len(rows)} for b, rows in branches.items()]}
    (tmp_path / "_meta.json").write_text(json.dumps(meta), encoding="utf-8")
    months = [f"2026-{m:02d}" for m in range(10, 0, -1)] + ["x"] * 50
    for b, rows in branches.items():
        with gzip.open(tmp_path / f"reorder_{b}.json.gz", "wt", encoding="utf-8") as f:
            json.dump({"branch": b, "parts": rows}, f)
        hist = [{"franchise": r["franchise"], "partNumber": r["partNumber"], "sales": [i] * 60, "requests": [0] * 60}
                for i, r in enumerate(rows) if i % 2 == 0]
        with gzip.open(tmp_path / f"history_{b}.json.gz", "wt", encoding="utf-8") as f:
            json.dump({"branch": b, "months": months, "parts": hist}, f)
    with gzip.open(tmp_path / "rules.json.gz", "wt", encoding="utf-8") as f:
        json.dump({"rules": [{"id": 1, "ruleName": "Default"}]}, f)
    return str(tmp_path)


@pytest.fixture
def output(tmp_path):
    branches = {}
    for b in ("1", "2", "93C"):
        rows = []
        for i in range(300):
            status = "OK" if i % 50 else STATUSES[(i // 50) % len(STATUSES)]
            rows.append(_gold(f"{b}-{i:04d}", status))
        rows[7].update(minimumIgnored=True, minimumQty=2)
        rows[9].update(onHand=-3)
        rows[11].update(onHand=1.5)
        rows[13].update(minOverride=4, effectiveMin=4)
        branches[b] = rows
    return _write_output(tmp_path, branches)


def test_load_output_reads_month_rules_and_history(output):
    data = mef.load_output(output)
    assert data["month"] == "2026-10"
    assert data["rules"] == [{"id": 1, "ruleName": "Default"}]
    assert len(data["candidates"]) == 900
    first = data["candidates"][0]
    assert first["branch"] == "1" and first["history"]["sales"][0] == 0
    assert data["candidates"][1]["history"] is None


def test_load_output_needs_rules(output):
    os.remove(os.path.join(output, "rules.json.gz"))
    with pytest.raises(FileNotFoundError, match="rules.json.gz"):
        mef.load_output(output)


def test_sample_covers_every_stratum(output):
    cands = mef.load_output(output)["candidates"]
    parts = mef.sample(cands, size=60, per_tag=3)
    got = mef.stratum_counts(parts)
    for t in mef.stratum_counts(cands):
        assert got.get(t, 0) >= 1, t
    for s in STATUSES:
        assert got[f"status={s}"] >= 3
    for t in ("minimumIgnored=true", "negativeOnHand", "fractional", "minOverride", "masked", "history", "noHistory",
              "branch=93C"):
        assert got[t] >= 1, t
    assert len(parts) >= 60


def test_sample_is_deterministic_and_keeps_file_order(output):
    cands = mef.load_output(output)["candidates"]
    a = mef.sample(cands, size=50, per_tag=2)
    b = mef.sample(list(cands), size=50, per_tag=2)
    assert a == b
    order = {id(c): i for i, c in enumerate(cands)}
    assert [order[id(p)] for p in a] == sorted(order[id(p)] for p in a)
    assert mef.sample(cands, size=50, per_tag=2, seed=1) != a


def test_main_writes_the_fixture(output, tmp_path):
    dest = tmp_path / "out" / "gold-sample.json"
    assert mef.main(["--output", output, "--dest", str(dest), "--size", "40"]) == 0
    text = dest.read_text(encoding="utf-8")
    data = json.loads(text)
    assert data["month"] == "2026-10"
    assert data["rules"] == [{"id": 1, "ruleName": "Default"}]
    assert len(data["parts"]) >= 40
    p = data["parts"][0]
    assert set(p) == {"branch", "gold", "history"}
    assert any(q["history"] is None for q in data["parts"])
    # same input, same bytes
    mef.main(["--output", output, "--dest", str(dest), "--size", "40"])
    assert dest.read_text(encoding="utf-8") == text
