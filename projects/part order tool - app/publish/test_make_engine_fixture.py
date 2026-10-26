"""Tests for make_engine_fixture: stratification, determinism, file shape."""
import gzip
import json
import os

import pytest

import make_engine_fixture as mef

STATUSES = ("ManualOrder", "Masked", "NoRecentActivity", "NotStocked", "BelowMinValue", "AboveMaxValue",
            "OutOfStock", "Reorder", "OK")


def _gold(pn, status="OK", **kw):
    g = {"franchise": "MC", "partNumber": pn, "status": status, "ruleName": "Default", "minimumNoDemand": False,
         "demandBasis": "UnitsSold", "isMasked": status == "Masked", "minOverride": None, "minimumQty": None,
         "onHand": 1, "onOrder": 0, "windowDemand": 0, "effectiveMin": 0, "calcTarget": 0, "activeMonths": 0,
         "demandCount": 0, "minDemands": 3, "unitsSoldWindow": 0, "supplyUnit": "Weeks", "supply": 12,
         "valueCapped": status == "AboveMaxValue", "belowMinValue": status == "BelowMinValue",
         "manualOrder": status == "ManualOrder", "maskedOn": None}
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
            status = "OK" if i % 30 else STATUSES[(i // 30) % len(STATUSES)]
            rows.append(_gold(f"{b}-{i:04d}", status))
        rows[7].update(minimumNoDemand=True, minimumQty=2)
        rows[15].update(demandCount=3, minDemands=3)
        rows[17].update(demandCount=2, minDemands=3, windowDemand=4, activeMonths=2)
        rows[19].update(unitsSoldWindow=5)
        rows[21].update(valueCapped=True, status="Reorder")
        rows[23].update(supplyUnit="Months", supply=2)
        rows[25].update(maskedOn="2026-09-01", isMasked=False, lastRequested="2026-09-15T00:00:00+00:00")
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
    for t in ("minimumNoDemand=true", "negativeOnHand", "fractional", "minOverride", "masked", "history", "noHistory",
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


def test_round1_tags():
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", demandCount=3, minDemands=3)})
    assert "demandsAtMin" in t and "belowMinDemands" not in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", demandCount=2, minDemands=3)})
    assert "belowMinDemands" in t and "demandsOneBelowMin" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", unitsSoldWindow=4)})
    assert "unitsNoDemands" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", minimumNoDemand=True)})
    assert "minimumNoDemand=true" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", "Reorder", valueCapped=True)})
    assert "valueCapped" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", supplyUnit="Months")})
    assert "unit=Months" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", "ManualOrder")})
    assert "manualOrder" in t and "status=ManualOrder" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", maskedOn="2026-09-01", isMasked=False)})
    assert "maskEnded" in t and "maskedOn" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", "Masked", maskedOn="2026-09-01")})
    assert "maskedOn" in t and "maskEnded" not in t


def test_round1_strata_are_sampled(output):
    cands = mef.load_output(output)["candidates"]
    got = mef.stratum_counts(mef.sample(cands, size=60, per_tag=3))
    for t in ("demandsAtMin", "belowMinDemands", "unitsNoDemands", "valueCapped", "unit=Months", "maskEnded",
              "manualOrder", "status=AboveMaxValue", "status=BelowMinValue", "status=ManualOrder"):
        assert got.get(t, 0) >= 1, t


def test_absent_strata_names_expected_strata_missing_from_the_data():
    cands = [{"branch": "1", "history": None, "gold": _gold("A")},
             {"branch": "1", "history": None, "gold": _gold("B", "Reorder", demandCount=3, minDemands=3)}]
    missing = mef.absent_strata(cands)
    for t in ("unit=Months", "manualOrder", "maskEnded", "valueCapped", "status=ManualOrder",
              "status=AboveMaxValue", "status=BelowMinValue"):
        assert t in missing
    assert "status=OK" not in missing and "status=Reorder" not in missing and "demandsAtMin" not in missing


def test_main_reports_absent_strata(output, tmp_path, capsys):
    assert mef.main(["--output", output, "--dest", str(tmp_path / "f.json"), "--size", "40"]) == 0
    assert "no part in the data" not in capsys.readouterr().out
    small = tmp_path / "small"
    small.mkdir()
    _write_output(small, {"1": [_gold("A"), _gold("B", "Reorder")]})
    assert mef.main(["--output", str(small), "--dest", str(tmp_path / "g.json"), "--size", "2"]) == 0
    line = [l for l in capsys.readouterr().out.splitlines() if "no part in the data" in l]
    assert len(line) == 1 and "unit=Months" in line[0] and "manualOrder" in line[0] and "status=OK" not in line[0]
