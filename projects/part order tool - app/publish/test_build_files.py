"""Tests for build_files (no config, no network)."""
import gzip
import json
import os
from datetime import date, datetime
from decimal import Decimal

import pytest

import build_files

AS_OF = "2026-10-20T11:40:00+00:00"
MONTH = date(2026, 10, 1)
NAMES = {"1": "Lubbock"}


# Round 2 reorder fields as Gold writes them for a part on the built-in transfer rule (contract v3).
ROUND2 = {"pendingQty": 0.0, "slc": None, "source": None, "commodityCode": None, "phaseInQty": None,
          "phaseInEnds": None, "phaseInOn": None, "phaseInActive": False, "phaseInEndReason": None,
          "appInboundQty": 0, "appOutboundQty": 0, "transferRuleId": None, "transferRuleName": "Built-in default",
          "excessSupply": 12.0, "excessUnit": "Months", "allowSend": True, "allowReceive": True, "redistMax": 6.0,
          "redistUnit": "Months", "redistMinValue": 0.0, "excessKeep": 3, "freeExcess": 2, "convNeed": 0,
          "redistCap": 0, "redistEligible": False, "suggestedInQty": 0, "suggestedConvInQty": 0,
          "suggestedOutQty": 0}
NULLABLE = {"slc", "source", "commodityCode", "phaseInQty", "phaseInEnds", "phaseInOn", "phaseInEndReason",
            "transferRuleId"}


def _row(branch, part, surplus, cost="12.50", **kw):
    r = {"branch": branch, "franchise": "A", "partNumber": part, "onHand": 5, "target": 3,
         "surplusQty": surplus, "status": "OK", "cost": Decimal(cost), **ROUND2}
    r.update(kw)
    return r


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
             "slc", "source", "vendorCode", "productGroup", "commodityCode",
             "startMonth", "endMonth", "historyMonths", "minDemands", "weeksOfCover", "supplyUnit", "minLineValue",
             "maxLineValue", "demandBasis"}
for _r in RULES:
    _r.update({"slc": None, "source": None, "vendorCode": None, "productGroup": None, "commodityCode": None})
RULES[1].update(slc="X1", vendorCode="1234", productGroup="PG", commodityCode="C1", source="S")

TRULE_KEYS = {"id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode", "branch", "slc",
              "source", "vendorCode", "productGroup", "commodityCode", "startMonth", "endMonth", "excessSupply",
              "excessUnit", "allowSend", "allowReceive", "redistMax", "redistUnit", "redistMinValue"}


def _trule(i, **kw):
    r = {k: None for k in TRULE_KEYS}
    r.update(id=i, ruleName=f"T{i}", priority=1.0, active=True, excessSupply=12.0, excessUnit="Months")
    r.update(kw)
    return r


TRULES = [_trule(5, redistMinValue=Decimal("25.00"), allowSend=False), _trule(2, extra="dropped")]
SUGGESTIONS = [
    {"kind": "Conventional", "franchise": "A", "partNumber": "P1", "fromBranch": "92", "toBranch": "1", "seq": 1,
     "qty": 2, "fromCost": 12.5, "toCost": Decimal("12.40"), "value": 24.8, "description": "Bolt", "fromBin": "A1",
     "toBin": None},
    {"kind": "Redistribution", "franchise": "A", "partNumber": "P1", "fromBranch": "92", "toBranch": "7", "seq": 2,
     "qty": 1, "fromCost": 12.5, "toCost": 12.5, "value": 12.5, "description": "Bolt", "fromBin": "A1",
     "toBin": "B2"}]
COMMITTED = [{"transferId": 3, "lineId": 9, "status": "Placed", "placedAt": datetime(2026, 10, 20, 15, 0),
              "fromBranch": "1", "toBranch": "92 ", "franchise": "A", "partNumber": "P3", "qty": 2.0}]


def _build(reorder=None, rules=None, trules=None, suggestions=None, committed=None):
    return build_files.build(REORDER if reorder is None else reorder, _hist, TRANSFERS, NAMES, AS_OF, MONTH,
                             RULES if rules is None else rules,
                             transfer_rules=TRULES if trules is None else trules,
                             suggestions=SUGGESTIONS if suggestions is None else suggestions,
                             committed=COMMITTED if committed is None else committed)


def test_files_and_branches(out):
    hashes, branches = _build()
    assert set(hashes) == {"reorder_1.json.gz", "history_1.json.gz", "reorder_92.json.gz",
                           "history_92.json.gz", "surplus.json.gz", "transfers.json.gz", "rules.json.gz",
                           "transfer_rules.json.gz", "transfer_suggestions.json.gz"}
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
                    "branches": branches, "counts": counts, "schemaVersion": 1, "contractVersion": 3}


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
    build_files.build(REORDER, _hist, lines, NAMES, AS_OF, MONTH, RULES, transfer_rules=TRULES,
                      suggestions=SUGGESTIONS, committed=COMMITTED)
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
    assert json.loads(open(path, "rb").read())["contractVersion"] == 3


@pytest.mark.parametrize("bad", [float("nan"), float("inf"), float("-inf"), Decimal("NaN")])
@pytest.mark.parametrize("key", ["startMonth", "weeksOfCover", "minLineValue", "maxLineValue", "minDemands"])
def test_rules_non_finite_number_fails(out, key, bad):
    rules = [dict(RULES[0], **{key: bad}), RULES[1]]
    with pytest.raises(ValueError, match=f"rule 2.*{key}.*not a finite number"):
        _build(rules=rules)
    assert not (out / "rules.json.gz").exists()



# ---- Round 2 (Plan E6): contract v3 ----

def test_reorder_round2_fields(out):
    _build([_row("1", "P1", 0, slc="X1", phaseInQty=4, phaseInEnds=date(2026, 12, 31), transferRuleId=7,
                 transferRuleName="Cotton", allowSend=False)])
    p = _read(out, "reorder_1.json.gz")["parts"][0]
    assert set(ROUND2) <= set(p)
    assert (p["slc"], p["phaseInQty"], p["phaseInEnds"]) == ("X1", 4, "2026-12-31")
    assert (p["transferRuleId"], p["transferRuleName"], p["allowSend"]) == (7, "Cotton", False)
    assert p["excessSupply"] == 12 and p["redistMinValue"] == 0 and p["pendingQty"] == 0


def test_reorder_nullable_round2_fields_stay_null(out):
    _build([_row("1", "P1", 0)])
    p = _read(out, "reorder_1.json.gz")["parts"][0]
    assert {k for k in ROUND2 if p[k] is None} == NULLABLE


@pytest.mark.parametrize("key", ["transferRuleName", "excessUnit", "redistUnit"])
def test_reorder_blank_text_is_empty_string(out, key):
    _build([_row("1", "P1", 0, **{key: None})])
    assert _read(out, "reorder_1.json.gz")["parts"][0][key] == ""


def test_reorder_null_pending_qty_is_zero(out):
    _build([_row("1", "P1", 0, pendingQty=None)])
    assert _read(out, "reorder_1.json.gz")["parts"][0]["pendingQty"] == 0


@pytest.mark.parametrize("key", ["phaseInActive", "appInboundQty", "excessSupply", "allowSend", "freeExcess",
                                 "convNeed", "redistEligible", "suggestedInQty", "suggestedConvInQty"])
def test_reorder_null_never_null_field_fails(out, key):
    with pytest.raises(ValueError, match=f"{key}.*null"):
        _build([_row("1", "P1", 0, **{key: None})])


def test_reorder_row_missing_round2_field_fails(out):
    row = _row("1", "P1", 0)
    del row["suggestedOutQty"]
    with pytest.raises(ValueError, match="suggestedOutQty"):
        _build([row])


def test_rules_file_has_the_five_criteria(out):
    _build()
    r1 = _read(out, "rules.json.gz")["rules"][0]
    assert (r1["slc"], r1["source"], r1["vendorCode"], r1["productGroup"], r1["commodityCode"]) == \
        ("X1", "S", "1234", "PG", "C1")


def test_transfer_rules_file_ordered_by_id(out):
    hashes, _ = _build()
    d = _read(out, "transfer_rules.json.gz")
    assert set(d) == {"dataAsOf", "rules"} and d["dataAsOf"] == AS_OF
    assert [r["id"] for r in d["rules"]] == [2, 5]
    assert all(set(r) == TRULE_KEYS for r in d["rules"])
    assert d["rules"][1]["redistMinValue"] == 25 and d["rules"][1]["allowSend"] is False
    assert d["rules"][0]["redistMinValue"] is None   # raw: blank stays null (Gold reads it as 0)


def test_transfer_rules_empty_still_written(out):
    _build(trules=[])
    assert _read(out, "transfer_rules.json.gz")["rules"] == []


def test_transfer_rules_row_missing_key_raises(out):
    bad = {k: v for k, v in _trule(1).items() if k != "redistUnit"}
    with pytest.raises(ValueError, match="redistUnit"):
        _build(trules=[bad])


@pytest.mark.parametrize("bad", [float("nan"), float("inf"), Decimal("-Infinity")])
@pytest.mark.parametrize("key", ["priority", "excessSupply", "redistMax", "redistMinValue", "endMonth"])
def test_transfer_rules_non_finite_number_fails(out, key, bad):
    with pytest.raises(ValueError, match=f"NonJD_TransferRules rule 3.*{key}.*not a finite number"):
        _build(trules=[_trule(3, **{key: bad})])
    assert not (out / "transfer_rules.json.gz").exists()


def test_transfer_suggestions_file(out):
    _build()
    d = _read(out, "transfer_suggestions.json.gz")
    assert set(d) == {"dataAsOf", "lines", "committed"} and d["dataAsOf"] == AS_OF
    assert [l["seq"] for l in d["lines"]] == [1, 2]
    assert set(d["lines"][0]) == {"kind", "franchise", "partNumber", "fromBranch", "toBranch", "seq", "qty",
                                  "fromCost", "toCost", "value", "description", "fromBin", "toBin"}
    assert d["lines"][0]["toCost"] == 12.4 and d["lines"][0]["toBin"] is None
    c = d["committed"][0]
    assert set(c) == {"transferId", "lineId", "status", "placedAt", "fromBranch", "toBranch", "franchise",
                      "partNumber", "qty"}
    assert c["placedAt"] == "2026-10-20T15:00:00+00:00" and c["toBranch"] == "92 " and c["qty"] == 2


def test_transfer_suggestions_empty_still_written(out):
    _build(suggestions=[], committed=[])
    assert _read(out, "transfer_suggestions.json.gz") == {"dataAsOf": AS_OF, "lines": [], "committed": []}


def test_transfer_suggestions_line_missing_key_raises(out):
    bad = {k: v for k, v in SUGGESTIONS[0].items() if k != "toBin"}
    with pytest.raises(ValueError, match="toBin"):
        _build(suggestions=[bad])


def test_transfer_suggestions_deterministic_whatever_the_input_order(out):
    h1, _ = _build()
    h2, _ = _build(suggestions=list(reversed(SUGGESTIONS)))
    assert h1["transfer_suggestions.json.gz"] == h2["transfer_suggestions.json.gz"]


def test_build_into_another_folder(out, tmp_path):
    other = tmp_path / "local"
    other.mkdir()
    (other / "keep.txt").write_text("not ours")
    hashes, branches = build_files.build(REORDER, _hist, TRANSFERS, NAMES, AS_OF, MONTH, RULES, transfer_rules=TRULES,
                                         suggestions=SUGGESTIONS, committed=COMMITTED, out_dir=str(other))
    meta = build_files.write_meta(AS_OF, AS_OF, "dev", branches, {}, out_dir=str(other))
    assert sorted(os.listdir(other)) == sorted(list(hashes) + ["_meta.json", "keep.txt"])
    assert os.path.dirname(meta) == str(other)
    assert not out.exists()
