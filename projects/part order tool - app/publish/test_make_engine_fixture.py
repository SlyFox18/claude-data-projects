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
         "manualOrder": status == "ManualOrder", "maskedOn": None, "lastRequested": "1900-01-01T00:00:00+00:00",
         "minLineValue": None, "maxLineValue": None,
         # round 2 (contract v3)
         "phaseInActive": False, "phaseInEndReason": None, "appInboundQty": 0, "appOutboundQty": 0,
         "allowSend": True, "freeExcess": 0, "convNeed": 0, "redistEligible": False, "redistMinValue": 0}
    g.update(kw)
    return g


AS_OF = "2026-10-27T19:30:00+00:00"


def _write_output(tmp_path, branches, lines=(), committed=(), trules=None):
    """branches: {key: [gold rows]}; every even-numbered part gets a history row."""
    meta = {"dataAsOf": AS_OF,
            "branches": [{"branch": b, "name": b, "parts": len(rows)} for b, rows in branches.items()]}
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
    with gzip.open(tmp_path / "transfer_rules.json.gz", "wt", encoding="utf-8") as f:
        json.dump({"rules": [{"id": 4, "ruleName": "Cotton"}] if trules is None else trules}, f)
    with gzip.open(tmp_path / "transfer_suggestions.json.gz", "wt", encoding="utf-8") as f:
        json.dump({"dataAsOf": AS_OF, "lines": list(lines), "committed": list(committed)}, f)
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
        rows[27].update(demandBasis="Requests")
        rows[29].update(minDemands=0, demandCount=0, unitsSoldWindow=1)
        rows[31].update(minLineValue=10, maxLineValue=500)
        rows[9].update(onHand=-3)
        rows[11].update(onHand=1.5)
        rows[13].update(minOverride=4, effectiveMin=4)
        # round 2 row strata
        rows[33].update(phaseInActive=True)
        rows[35].update(phaseInEndReason="Expired")
        rows[37].update(phaseInEndReason="MetCriteria")
        rows[39].update(appInboundQty=1)
        rows[41].update(appOutboundQty=2)
        rows[43].update(allowSend=False)
        branches[b] = rows
    # round 2 group strata: 1-0047 is at branches 1 and 2; branch 1's excess is under a $25 minimum
    branches["1"][47].update(freeExcess=1, redistMinValue=25)
    branches["2"][47].update(partNumber="1-0047", redistEligible=True)
    lines = [{"kind": "Conventional", "franchise": "MC", "partNumber": "1-0049", "fromBranch": fb, "toBranch": "1",
              "seq": i + 1} for i, fb in enumerate(("2", "93C"))]
    lines.append({"kind": "Redistribution", "franchise": "MC", "partNumber": "1-0051", "fromBranch": "2",
                  "toBranch": "1", "seq": 1})
    return _write_output(tmp_path, branches, lines)


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
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", maskedOn="2026-09-01", isMasked=False,
                                                                 lastRequested="2026-09-02T00:00:00+00:00")})
    assert "maskEnded" in t and "maskedOn" in t
    # requested on the day it was masked, or earlier: the mask did not end at a request (it may have expired)
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", maskedOn="2026-09-01", isMasked=False,
                                                                 lastRequested="2026-09-01T00:00:00+00:00")})
    assert "maskedOn" in t and "maskEnded" not in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", "Masked", maskedOn="2026-09-01")})
    assert "maskedOn" in t and "maskEnded" not in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", minDemands=0)})
    assert "minDemands=0" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", minLineValue=10, maxLineValue=500)})
    assert "bothCaps" in t
    t = mef.tags({"branch": "1", "history": None, "gold": _gold("X", maxLineValue=500)})
    assert "bothCaps" not in t


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
              "status=AboveMaxValue", "status=BelowMinValue", "basis=Requests", "minDemands=0", "bothCaps"):
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



# ---- Round 2 (Plan E6, X9): whole Franchise + PartNumber groups, transfer strata, suggestions in the fixture ----

def _sugg(kind, pn, fb, tb, seq, qty=1, fr="MC"):
    return {"kind": kind, "franchise": fr, "partNumber": pn, "fromBranch": fb, "toBranch": tb, "seq": seq,
            "qty": qty, "fromCost": 1.0, "toCost": 1.0, "value": float(qty), "description": "", "fromBin": None,
            "toBin": None}


def _committed(pn, fb, tb, tid=1, fr="MC"):
    return {"transferId": tid, "lineId": 1, "status": "Draft", "placedAt": None, "fromBranch": fb, "toBranch": tb,
            "franchise": fr, "partNumber": pn, "qty": 2}


@pytest.fixture
def groups(tmp_path):
    """Three branches, 200 parts each, shared part numbers (so every group spans the three branches), plus
    groups with transfer strata."""
    branches = {}
    for b in ("1", "2", "3"):
        rows = [_gold(f"P{i:04d}", "OK" if i % 30 else STATUSES[(i // 30) % len(STATUSES)]) for i in range(200)]
        branches[b] = rows
    branches["1"][3].update(phaseInActive=True)
    branches["2"][5].update(phaseInEndReason="Expired")
    branches["3"][7].update(phaseInEndReason="MetCriteria")
    branches["1"][9].update(appInboundQty=2)
    branches["2"][9].update(appOutboundQty=2)
    branches["3"][11].update(allowSend=False)
    # P0013: branch 1 gets a conventional line from 2 and from 3
    branches["2"][13].update(freeExcess=3)
    branches["3"][13].update(freeExcess=3)
    branches["1"][13].update(convNeed=5)
    # P0015: redistribution 2 -> 3
    branches["2"][15].update(freeExcess=4)
    branches["3"][15].update(redistEligible=True)
    # P0017: branch 1 has excess under a $25 minimum and branch 2 takes redistribution, but gets nothing from 1
    branches["1"][17].update(freeExcess=1, redistMinValue=25)
    branches["2"][17].update(redistEligible=True)
    lines = [_sugg("Conventional", "P0013", "2", "1", 1, 3), _sugg("Conventional", "P0013", "3", "1", 2, 2),
             _sugg("Redistribution", "P0015", "2", "3", 1, 4)]
    committed = [_committed("P0009", "2", "1"), _committed("P0199", "1", "3", tid=2)]
    out = tmp_path / "g"
    out.mkdir()
    return _write_output(out, branches, lines, committed)


def test_load_output_reads_transfer_files(groups):
    data = mef.load_output(groups)
    assert data["dataAsOf"] == AS_OF
    assert data["transferRules"] == [{"id": 4, "ruleName": "Cotton"}]
    assert len(data["suggestions"]) == 3 and len(data["committed"]) == 2


@pytest.mark.parametrize("name", ["transfer_rules.json.gz", "transfer_suggestions.json.gz"])
def test_load_output_needs_transfer_files(groups, name):
    os.remove(os.path.join(groups, name))
    with pytest.raises(FileNotFoundError, match=name):
        mef.load_output(groups)


def test_round2_row_tags():
    t = lambda **kw: mef.tags({"branch": "1", "history": None, "gold": _gold("X", **kw)})
    assert "phaseInActive" in t(phaseInActive=True)
    assert "phaseIn=Expired" in t(phaseInEndReason="Expired")
    assert "phaseIn=MetCriteria" in t(phaseInEndReason="MetCriteria")
    assert "committedIn" in t(appInboundQty=1) and "committedOut" in t(appOutboundQty=1)
    assert "allowSendFalse" in t(allowSend=False)
    assert not {"phaseInActive", "committedIn", "committedOut", "allowSendFalse"} & set(t())


def test_group_tags(groups):
    data = mef.load_output(groups)
    by_group = mef.group_tags(data["candidates"], data["suggestions"])
    assert "group=conventionalTwoSenders" in by_group[("MC", "P0013")]
    assert "group=redistribution" in by_group[("MC", "P0015")]
    assert "group=redistMinSkip" in by_group[("MC", "P0017")]
    assert "group=redistMinSkip" not in by_group[("MC", "P0015")]
    assert by_group.get(("MC", "P0100"), set()) == set()


def test_sample_takes_whole_groups(groups):
    data = mef.load_output(groups)
    parts = mef.sample(data["candidates"], size=30, per_tag=2, suggestions=data["suggestions"])
    keys = {(p["gold"]["franchise"], p["gold"]["partNumber"]) for p in parts}
    for k in keys:
        assert sum(1 for p in parts if (p["gold"]["franchise"], p["gold"]["partNumber"]) == k) == 3, k
    for pn in ("P0003", "P0005", "P0007", "P0009", "P0011", "P0013", "P0015", "P0017"):
        assert ("MC", pn) in keys, pn


def test_main_writes_group_suggestions_and_committed(groups, tmp_path):
    dest = tmp_path / "fx.json"
    assert mef.main(["--output", groups, "--dest", str(dest), "--size", "30"]) == 0
    data = json.loads(dest.read_text(encoding="utf-8"))
    assert data["dataAsOf"] == AS_OF and data["transferRules"] == [{"id": 4, "ruleName": "Cotton"}]
    keys = {(p["gold"]["franchise"], p["gold"]["partNumber"]) for p in data["parts"]}
    assert all((l["franchise"], l["partNumber"]) in keys for l in data["suggestions"])
    assert len(data["suggestions"]) == 3
    assert all((c["franchise"], c["partNumber"]) in keys for c in data["committed"])
    assert ("MC", "P0009") in {(c["franchise"], c["partNumber"]) for c in data["committed"]}
    text = dest.read_text(encoding="utf-8")
    mef.main(["--output", groups, "--dest", str(dest), "--size", "30"])
    assert dest.read_text(encoding="utf-8") == text


def test_absent_round2_strata_reported(tmp_path, capsys):
    small = tmp_path / "small"
    small.mkdir()
    _write_output(small, {"1": [_gold("A"), _gold("B", "Reorder")]})
    assert mef.main(["--output", str(small), "--dest", str(tmp_path / "g.json"), "--size", "2"]) == 0
    line = [l for l in capsys.readouterr().out.splitlines() if "no part in the data" in l][0]
    for t in ("phaseInActive", "phaseIn=Expired", "committedIn", "allowSendFalse", "group=redistribution",
              "group=redistMinSkip", "group=conventionalTwoSenders"):
        assert t in line, t
