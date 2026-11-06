"""Tests for build_files (no config, no network)."""
import gzip
import hashlib
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
         "surplusQty": surplus, "status": "OK", "cost": Decimal(cost), **ROUND2, "lastReceived": None,
         "equipStockValue": Decimal("0.00")}
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
PURCHASES = [{"branch": "92", "franchise": "A", "purchases12": 10.0},
             {"branch": "1", "franchise": "MC", "purchases12": Decimal("2.25")},
             {"branch": "1", "franchise": "A", "purchases12": 1234.5678}]


def _build(reorder=None, rules=None, trules=None, suggestions=None, committed=None, purchases=None):
    return build_files.build(REORDER if reorder is None else reorder, _hist, TRANSFERS, NAMES, AS_OF, MONTH,
                             RULES if rules is None else rules,
                             transfer_rules=TRULES if trules is None else trules,
                             suggestions=SUGGESTIONS if suggestions is None else suggestions,
                             committed=COMMITTED if committed is None else committed,
                             purchases=PURCHASES if purchases is None else purchases)


def test_files_and_branches(out):
    hashes, branches = _build()
    assert set(hashes) == {"reorder_1.json.gz", "history_1.json.gz", "reorder_92.json.gz",
                           "history_92.json.gz", "surplus.json.gz", "transfers.json.gz", "rules.json.gz",
                           "transfer_rules.json.gz", "transfer_suggestions.json.gz", "purchases.json.gz"}
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
    jd_branches = [{"branch": "12", "name": "12", "parts": 3}]
    jd_idle_branches = [{"branch": "4", "name": "4", "parts": 5}]
    path = build_files.write_meta(AS_OF, "2026-10-20T12:00:00+00:00", "dev", branches, counts,
                                  jd_branches=jd_branches, jd_idle_branches=jd_idle_branches)
    raw = open(path, "rb").read()
    assert raw[:2] != b"\x1f\x8b"
    meta = json.loads(raw)
    assert meta == {"dataAsOf": AS_OF, "publishedAt": "2026-10-20T12:00:00+00:00", "source": "dev",
                    "branches": branches, "counts": counts, "schemaVersion": 1, "contractVersion": 9,
                    "jdBranches": jd_branches, "jdIdleBranches": jd_idle_branches,
                    "jdOrderBranches": [], "jdOrderAsOf": None}


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
                      suggestions=SUGGESTIONS, committed=COMMITTED, purchases=PURCHASES)
    got = [t["ticket"] for t in _read(out, "transfers.json.gz")["lines"]]
    assert got == ["T0", "T6", "T7"]


@pytest.mark.parametrize("branch", ["12", "93C", "4b", "5 "])
def test_reorder_row_at_excluded_branch_raises(out, branch):
    with pytest.raises(ValueError, match="excluded"):
        _build([_row("1", "P1", 0), _row(branch, "P2", 3)])
    assert not (out / f"reorder_{branch.strip()}.json.gz").exists()


def test_meta_has_contract_version(out):
    _, branches = _build()
    path = build_files.write_meta(AS_OF, AS_OF, "dev", branches, {}, jd_branches=[], jd_idle_branches=[])
    assert json.loads(open(path, "rb").read())["contractVersion"] == 9


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
                                         suggestions=SUGGESTIONS, committed=COMMITTED, purchases=PURCHASES,
                                         out_dir=str(other))
    meta = build_files.write_meta(AS_OF, AS_OF, "dev", branches, {}, out_dir=str(other), jd_branches=[],
                                  jd_idle_branches=[])
    assert sorted(os.listdir(other)) == sorted(list(hashes) + ["_meta.json", "keep.txt"])
    assert os.path.dirname(meta) == str(other)
    assert not out.exists()


# ---- Round 3 (Plan I3): contract v4 ----

def test_reorder_last_received_is_a_date_string_or_null(out):
    _build([_row("1", "P1", 0, lastReceived=date(2026, 9, 14)), _row("1", "P2", 0),
            _row("1", "P3", 0, lastReceived=datetime(2026, 8, 1, 0, 0))])
    parts = _read(out, "reorder_1.json.gz")["parts"]
    assert [p["lastReceived"] for p in parts] == ["2026-09-14", None, "2026-08-01"]


def test_reorder_row_missing_last_received_fails(out):
    row = _row("1", "P1", 0)
    del row["lastReceived"]
    with pytest.raises(ValueError, match="lastReceived"):
        _build([row])


def test_purchases_file(out):
    hashes, _ = _build()
    assert "purchases.json.gz" in hashes
    d = _read(out, "purchases.json.gz")
    assert d == {"dataAsOf": AS_OF, "rows": [{"branch": "1", "franchise": "A", "purchases12": 1234.57},
                                             {"branch": "1", "franchise": "MC", "purchases12": 2.25},
                                             {"branch": "92", "franchise": "A", "purchases12": 10}]}


def test_purchases_numeric_branch_order_and_deterministic(out):
    rows = [{"branch": "10", "franchise": "A", "purchases12": 1.0},
            {"branch": "2", "franchise": "A", "purchases12": 1.0},
            {"branch": "BX", "franchise": "A", "purchases12": 1.0}]
    h1, _ = _build(purchases=rows)
    assert [r["branch"] for r in _read(out, "purchases.json.gz")["rows"]] == ["2", "10", "BX"]
    h2, _ = _build(purchases=list(reversed(rows)))
    assert h1["purchases.json.gz"] == h2["purchases.json.gz"]


def test_purchases_empty_still_written(out):
    _build(purchases=[])
    assert _read(out, "purchases.json.gz") == {"dataAsOf": AS_OF, "rows": []}


def test_purchases_row_missing_key_fails(out):
    with pytest.raises(ValueError, match="purchases12"):
        _build(purchases=[{"branch": "1", "franchise": "A"}])


@pytest.mark.parametrize("bad", [None, float("nan"), float("inf"), Decimal("NaN")])
def test_purchases_null_or_non_finite_fails(out, bad):
    with pytest.raises(ValueError, match="purchases12"):
        _build(purchases=[{"branch": "1", "franchise": "A", "purchases12": bad}])
    assert not (out / "purchases.json.gz").exists()


def test_purchases_row_at_excluded_branch_fails(out):
    with pytest.raises(ValueError, match="excluded"):
        _build(purchases=[{"branch": "12", "franchise": "A", "purchases12": 1.0}])


def test_purchases_duplicate_key_fails(out):
    with pytest.raises(ValueError, match="duplicate"):
        _build(purchases=[{"branch": "1", "franchise": "A", "purchases12": 1.0},
                          {"branch": "1", "franchise": "A", "purchases12": 2.0}])


# ---- Round 3 phase 3 (Plan K3): contract v5, equipStockValue ----

def test_reorder_equip_stock_value_is_a_number_rounded_to_cents(out):
    _build([_row("1", "P1", 0, equipStockValue=Decimal("123.45")),
            _row("1", "P2", 0, equipStockValue=Decimal("0.00")),
            _row("1", "P3", 0, equipStockValue=Decimal("-7.10"), onHand=0),
            _row("1", "P4", 0, equipStockValue=12.3456),
            _row("1", "P5", 0, equipStockValue=-0.001),
            _row("1", "P6", 0, equipStockValue=Decimal("40")),
            _row("1", "P7", 0, equipStockValue=5)])
    parts = _read(out, "reorder_1.json.gz")["parts"]
    vals = [p["equipStockValue"] for p in parts]
    assert vals == [123.45, 0, -7.1, 12.35, 0, 40, 5]
    assert all(type(v) in (int, float) for v in vals)
    assert str(vals[4]) == "0"          # -0 is written as 0


@pytest.mark.parametrize("bad", [None, float("nan"), float("inf"), float("-inf"), Decimal("NaN"), Decimal("Infinity"),
                                 "12.5", True])
def test_reorder_equip_stock_value_not_a_finite_number_fails(out, bad):
    with pytest.raises(ValueError, match="equipStockValue"):
        _build([_row("1", "P1", 0, equipStockValue=bad)])


def test_reorder_row_missing_equip_stock_value_fails(out):
    row = _row("1", "P1", 0)
    del row["equipStockValue"]
    with pytest.raises(ValueError, match="equipStockValue"):
        _build([row])


# ---- Plan L (L4): contract v6, jd_<branch>.json.gz ----

JD_FIELDS = {"partNumber", "description", "cost", "onHand", "onOrder", "packageQty", "returnIndicator", "source",
             "slc", "superTo", "commodityCode", "commodityGroup", "dealerGroupCode", "minimumQty", "maximumQty",
             "sales12", "salesPrev12", "corpDemands", "binQty", "piecesInSet", "pisInvoices", "pisSalesQty", "pisQty",
             "pisQtyInvoices", "pisMultipleInvoices"}


def _jd(branch, part, **kw):
    """A Fact_CorpParts_JD row as extract.jd_parts returns it (Gold's types: DECIMAL numbers, INTEGER demands)."""
    r = {"branch": branch, "partNumber": part, "description": "Pin", "cost": Decimal("459.01"),
         "onHand": Decimal("0.00"), "onOrder": Decimal("0.00"), "packageQty": Decimal("1.00"),
         "returnIndicator": "R", "source": "FF", "slc": "15C", "superTo": "", "commodityCode": "07A",
         "commodityGroup": "Tillage", "dealerGroupCode": "", "minimumQty": None, "maximumQty": None,
         "sales12": Decimal("2.00"), "salesPrev12": Decimal("0.00"), "corpDemands": 2,
         "binQty": Decimal("3.00"), "piecesInSet": None, "pisInvoices": 4, "pisSalesQty": Decimal("7.00"),
         "pisQty": Decimal("2.00"), "pisQtyInvoices": 3, "pisMultipleInvoices": 0}
    r.update(kw)
    return r


JD = [_jd("2", "B1"), _jd("1", "A2"), _jd("12", "C1"), _jd("1", "A1")]
JD_NAMES = {"1": "Lubbock", "12": "Corporate"}


def _build_jd(rows=None, names=None):
    return build_files.build_jd(JD if rows is None else rows, JD_NAMES if names is None else names, AS_OF)


def test_jd_files_and_branches(out):
    hashes, jd_branches = _build_jd()
    assert set(hashes) == {"jd_1.json.gz", "jd_2.json.gz", "jd_12.json.gz"}
    assert sorted(os.listdir(out)) == sorted(hashes)
    assert jd_branches == [{"branch": "1", "name": "Lubbock", "parts": 2},
                           {"branch": "2", "name": "2", "parts": 1},
                           {"branch": "12", "name": "Corporate", "parts": 1}]


@pytest.mark.parametrize("branch", ["12", "5", "97", "4B", "93C"])
def test_jd_excluded_branches_are_written(out, branch):
    # L-D5: the Corp Parts reports cover every JD branch, so there is no D6 check on JD rows
    hashes, jd_branches = _build_jd([_jd(branch, "P1")])
    assert f"jd_{branch}.json.gz" in hashes
    assert [b["branch"] for b in jd_branches] == [branch]


def test_jd_file_layout(out):
    _build_jd()
    data = _read(out, "jd_1.json.gz")
    assert set(data) == {"branch", "dataAsOf", "parts"}
    assert data["branch"] == "1" and data["dataAsOf"] == AS_OF
    assert all(set(p) == JD_FIELDS for p in data["parts"])
    raw = gzip.decompress((out / "jd_1.json.gz").read_bytes())
    assert raw == json.dumps(json.loads(raw), sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def test_jd_values(out):
    _build_jd([_jd("1", "A1")])
    p = _read(out, "jd_1.json.gz")["parts"][0]
    assert p == {"partNumber": "A1", "description": "Pin", "cost": 459.01, "onHand": 0, "onOrder": 0,
                 "packageQty": 1, "returnIndicator": "R", "source": "FF", "slc": "15C", "superTo": "",
                 "commodityCode": "07A", "commodityGroup": "Tillage", "dealerGroupCode": "", "minimumQty": None,
                 "maximumQty": None, "sales12": 2, "salesPrev12": 0, "corpDemands": 2, "binQty": 3, "piecesInSet": None,
                 "pisInvoices": 4, "pisSalesQty": 7, "pisQty": 2, "pisQtyInvoices": 3, "pisMultipleInvoices": 0}
    assert type(p["onHand"]) is int and type(p["corpDemands"]) is int


def test_jd_pieces_in_set_fields_v8(out):
    # Plan R: quantities to 2 decimals, the invoice counts whole, piecesInSet numeric or null
    _build_jd([_jd("1", "A1", binQty=Decimal("-1.504"), piecesInSet=Decimal("4.00"), pisInvoices=Decimal("9"),
                   pisSalesQty=Decimal("18.255"), pisQty=Decimal("2.50"), pisQtyInvoices=7, pisMultipleInvoices=6),
               _jd("1", "A2", piecesInSet=None)])
    a1, a2 = _read(out, "jd_1.json.gz")["parts"]
    assert (a1["binQty"], a1["piecesInSet"], a1["pisSalesQty"], a1["pisQty"]) == (-1.5, 4, 18.25, 2.5)
    assert (a1["pisInvoices"], a1["pisQtyInvoices"], a1["pisMultipleInvoices"]) == (9, 7, 6)
    assert type(a1["piecesInSet"]) is int and type(a1["pisInvoices"]) is int
    assert a2["piecesInSet"] is None


def test_jd_idle_files_have_no_pieces_in_set_fields(out):
    # Plan R: the idle files carry no stats (spec section 1); no report's 3+ invoices condition can need one
    _build_idle([_idle("1", "A1")])
    assert not {"binQty", "piecesInSet", "pisInvoices", "pisSalesQty", "pisQty", "pisQtyInvoices",
                "pisMultipleInvoices"} & set(_read(out, "jd_idle_1.json.gz")["parts"][0])


def test_jd_text_trimmed_and_null_text_is_empty(out):
    _build_jd([_jd(" 1 ", " A1  ", description="  Pin  ", returnIndicator=" R ", source=None, slc="  ",
                   superTo=None, commodityCode=" 07A", commodityGroup="Other ", dealerGroupCode=None)])
    data = _read(out, "jd_1.json.gz")
    p = data["parts"][0]
    assert data["branch"] == "1"
    assert (p["partNumber"], p["description"], p["returnIndicator"]) == ("A1", "Pin", "R")
    assert (p["source"], p["slc"], p["superTo"], p["dealerGroupCode"]) == ("", "", "", "")
    assert (p["commodityCode"], p["commodityGroup"]) == ("07A", "Other")


def test_jd_nullable_fields_stay_null(out):
    _build_jd([_jd("1", "A1", description=None, packageQty=None, minimumQty=None, maximumQty=None)])
    p = _read(out, "jd_1.json.gz")["parts"][0]
    assert (p["description"], p["packageQty"], p["minimumQty"], p["maximumQty"]) == (None, None, None, None)


def test_jd_rounding(out):
    _build_jd([_jd("1", "A1", cost=12.3456, onHand=Decimal("1.004"), onOrder=2.499, packageQty=Decimal("2.50"),
                   minimumQty=Decimal("3.00"), maximumQty=7.777, sales12=Decimal("-0.001"), salesPrev12=15664,
                   corpDemands=Decimal("3"))])
    p = _read(out, "jd_1.json.gz")["parts"][0]
    assert (p["cost"], p["onHand"], p["onOrder"], p["packageQty"]) == (12.35, 1.0, 2.5, 2.5)
    assert (p["minimumQty"], p["maximumQty"], p["sales12"], p["salesPrev12"]) == (3, 7.78, 0, 15664)
    assert p["corpDemands"] == 3 and type(p["corpDemands"]) is int
    assert type(p["minimumQty"]) is int and str(p["sales12"]) == "0"     # whole values as integers, -0 -> 0


@pytest.mark.parametrize("key", ["cost", "onHand", "onOrder", "sales12", "salesPrev12", "corpDemands", "binQty",
                                 "pisInvoices", "pisSalesQty", "pisQty", "pisQtyInvoices", "pisMultipleInvoices"])
def test_jd_null_never_null_number_fails(out, key):
    with pytest.raises(ValueError, match=key):
        _build_jd([_jd("1", "A1", **{key: None})])


@pytest.mark.parametrize("key", ["cost", "onHand", "packageQty", "maximumQty", "binQty", "piecesInSet", "pisQty",
                                 "pisSalesQty"])
@pytest.mark.parametrize("bad", [float("nan"), float("inf"), Decimal("NaN"), Decimal("-Infinity"), "1", True])
def test_jd_non_finite_or_non_number_fails(out, key, bad):
    with pytest.raises(ValueError, match=key):
        _build_jd([_jd("1", "A1", **{key: bad})])


@pytest.mark.parametrize("key", ["corpDemands", "pisInvoices", "pisQtyInvoices", "pisMultipleInvoices"])
@pytest.mark.parametrize("bad", [2.5, Decimal("2.5"), "2", True, float("nan")])
def test_jd_counts_must_be_whole(out, key, bad):
    with pytest.raises(ValueError, match=key):
        _build_jd([_jd("1", "A1", **{key: bad})])


def test_jd_row_missing_field_fails(out):
    row = _jd("1", "A1")
    del row["commodityGroup"]
    with pytest.raises(ValueError, match="commodityGroup"):
        _build_jd([row])


def test_jd_twins_allowed_and_sorted_by_trimmed_part_then_raw(out):
    # L-D12: the trailing-space twins stay two rows; sorted by trimmed partNumber, then the raw value
    _build_jd([_jd("8", "E63245 ", onHand=1), _jd("8", "B2"), _jd("8", "E63245", onHand=2), _jd("8", " A9"),
               _jd("8", "E6324")])
    parts = _read(out, "jd_8.json.gz")["parts"]
    assert [p["partNumber"] for p in parts] == ["A9", "B2", "E6324", "E63245", "E63245"]
    assert [p["onHand"] for p in parts[3:]] == [2, 1]


def test_jd_deterministic_whatever_the_input_order(out):
    h1, b1 = _build_jd()
    h2, b2 = _build_jd(list(reversed(JD)))
    assert h1 == h2 and b1 == b2


def test_jd_branch_order_numeric_then_alpha(out):
    _, jd_branches = _build_jd([_jd(b, "P") for b in ["4B", "93C", "10", "2", "15I", "97"]])
    assert [b["branch"] for b in jd_branches] == ["2", "10", "97", "15I", "4B", "93C"]


def test_jd_branch_key_collision_raises(out):
    with pytest.raises(ValueError, match="both map to file key"):
        _build_jd([_jd("1", "A"), _jd("1 ", "B")])


@pytest.mark.parametrize("branch", ["../x", "", None, "1 2"])
def test_jd_unsafe_branch_raises(out, branch):
    with pytest.raises(ValueError):
        _build_jd([_jd(branch, "A")])


def test_jd_file_over_the_upload_limit_fails_naming_the_branch(out, monkeypatch):
    monkeypatch.setattr(build_files, "JD_FILE_LIMIT", 1000)
    rows = [_jd("1", "A1")] + [_jd("92", f"P{i:05d}", description=f"part {i * 7919 % 10007}") for i in range(200)]
    with pytest.raises(ValueError, match=r"jd_92\.json\.gz .*bytes.*branch 92"):
        _build_jd(rows)
    assert not (out / "jd_92.json.gz").exists()


def test_jd_file_limit_is_the_upload_limit():
    import upload
    assert build_files.JD_FILE_LIMIT == upload.SIMPLE_LIMIT == 4 * 1024 * 1024


def test_jd_build_keeps_the_other_files(out):
    # build() clears the folder's old outputs; build_jd runs after it and adds to them
    hashes, _ = _build()
    jd_hashes, _ = _build_jd()
    assert sorted(os.listdir(out)) == sorted(set(hashes) | set(jd_hashes))


def test_stale_jd_files_cleared_by_build(out):
    _build_jd()
    _build()
    assert not [f for f in os.listdir(out) if f.startswith("jd_")]


def test_jd_build_into_another_folder(out, tmp_path):
    dest = tmp_path / "local"
    hashes, _ = build_files.build_jd(JD, JD_NAMES, AS_OF, out_dir=str(dest))
    assert sorted(os.listdir(dest)) == sorted(hashes)
    assert not out.exists()


def test_jd_empty_gives_no_files(out):
    assert _build_jd([]) == ({}, [])


def test_write_meta_has_jd_branches(out):
    _, branches = _build()
    _, jd_branches = _build_jd()
    path = build_files.write_meta(AS_OF, AS_OF, "dev", branches, {"parts": 4, "jdParts": 4},
                                  jd_branches=jd_branches, jd_idle_branches=[])
    meta = json.loads(open(path, "rb").read())
    assert meta["jdBranches"] == jd_branches and meta["counts"]["jdParts"] == 4
    assert meta["contractVersion"] == 9
    assert [b["branch"] for b in meta["branches"]] == ["1", "92"]


# ---- Plan M (M3): contract v7, jd_idle_<branch>.json.gz ----

JD_IDLE_FIELDS = {"partNumber", "description", "cost", "onOrder", "packageQty", "returnIndicator", "source", "slc",
                  "superTo", "commodityCode", "commodityGroup", "dealerGroupCode", "minimumQty", "maximumQty"}


def _idle(branch, part, **kw):
    """A Fact_CorpParts_JD_Idle row as extract.jd_idle_parts returns it (Gold's types: DECIMAL numbers)."""
    r = {"branch": branch, "partNumber": part, "description": "Pin", "cost": Decimal("459.01"),
         "onOrder": Decimal("0.00"), "packageQty": Decimal("1.00"), "returnIndicator": "R", "source": "FF",
         "slc": "15C", "superTo": "", "commodityCode": "07A", "commodityGroup": "Tillage", "dealerGroupCode": "",
         "minimumQty": None, "maximumQty": None}
    r.update(kw)
    return r


IDLE = [_idle("4", "B1"), _idle("1", "A2"), _idle("12", "C1"), _idle("1", "A1")]


def _build_idle(rows=None, names=None):
    return build_files.build_jd_idle(IDLE if rows is None else rows, JD_NAMES if names is None else names, AS_OF)


def test_idle_files_and_branches(out):
    hashes, idle_branches = _build_idle()
    assert set(hashes) == {"jd_idle_1.json.gz", "jd_idle_4.json.gz", "jd_idle_12.json.gz"}
    assert sorted(os.listdir(out)) == sorted(hashes)
    assert idle_branches == [{"branch": "1", "name": "Lubbock", "parts": 2},
                             {"branch": "4", "name": "4", "parts": 1},
                             {"branch": "12", "name": "Corporate", "parts": 1}]


@pytest.mark.parametrize("branch", ["12", "5", "97", "4B", "93C"])
def test_idle_excluded_branches_are_written(out, branch):
    # as the active JD files (L-D5): every JD branch, no D6 check
    hashes, idle_branches = _build_idle([_idle(branch, "P1")])
    assert f"jd_idle_{branch}.json.gz" in hashes
    assert [b["branch"] for b in idle_branches] == [branch]


def test_idle_file_layout(out):
    _build_idle()
    data = _read(out, "jd_idle_1.json.gz")
    assert set(data) == {"branch", "dataAsOf", "parts"}
    assert data["branch"] == "1" and data["dataAsOf"] == AS_OF
    assert all(set(p) == JD_IDLE_FIELDS for p in data["parts"])
    raw = gzip.decompress((out / "jd_idle_1.json.gz").read_bytes())
    assert raw == json.dumps(json.loads(raw), sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def test_idle_values(out):
    _build_idle([_idle("1", "A1", onOrder=Decimal("-2.00"))])
    p = _read(out, "jd_idle_1.json.gz")["parts"][0]
    assert p == {"partNumber": "A1", "description": "Pin", "cost": 459.01, "onOrder": -2, "packageQty": 1,
                 "returnIndicator": "R", "source": "FF", "slc": "15C", "superTo": "", "commodityCode": "07A",
                 "commodityGroup": "Tillage", "dealerGroupCode": "", "minimumQty": None, "maximumQty": None}
    assert type(p["onOrder"]) is int


def test_idle_zero_by_definition_fields_left_out(out):
    # on hand, sales and Corp demands are 0 for every idle row (M-D12); extra keys in a row are not published
    _build_idle([_idle("1", "A1", onHand=0, sales12=0, salesPrev12=0, corpDemands=0)])
    p = _read(out, "jd_idle_1.json.gz")["parts"][0]
    assert not {"onHand", "sales12", "salesPrev12", "corpDemands"} & set(p)


def test_idle_text_trimmed_and_null_text_is_empty(out):
    _build_idle([_idle(" 1 ", " A1  ", description="  Pin  ", returnIndicator=" R ", source=None, slc="  ",
                       superTo=None, commodityCode=" 07A", commodityGroup="Other ", dealerGroupCode=" 770 ")])
    data = _read(out, "jd_idle_1.json.gz")
    p = data["parts"][0]
    assert data["branch"] == "1"
    assert (p["partNumber"], p["description"], p["returnIndicator"]) == ("A1", "Pin", "R")
    assert (p["source"], p["slc"], p["superTo"]) == ("", "", "")
    assert (p["commodityCode"], p["commodityGroup"], p["dealerGroupCode"]) == ("07A", "Other", "770")


def test_idle_nullable_fields_stay_null(out):
    _build_idle([_idle("1", "A1", description=None, packageQty=None, minimumQty=None, maximumQty=None)])
    p = _read(out, "jd_idle_1.json.gz")["parts"][0]
    assert (p["description"], p["packageQty"], p["minimumQty"], p["maximumQty"]) == (None, None, None, None)


def test_idle_rounding(out):
    _build_idle([_idle("1", "A1", cost=12.3456, onOrder=Decimal("-1.004"), packageQty=Decimal("2.50"),
                       minimumQty=Decimal("3.00"), maximumQty=7.777)])
    p = _read(out, "jd_idle_1.json.gz")["parts"][0]
    assert (p["cost"], p["onOrder"], p["packageQty"], p["minimumQty"], p["maximumQty"]) == (12.35, -1, 2.5, 3, 7.78)
    assert type(p["minimumQty"]) is int and type(p["onOrder"]) is int


def test_idle_negative_zero_on_order_is_zero(out):
    _build_idle([_idle("1", "A1", onOrder=Decimal("-0.001"))])
    p = _read(out, "jd_idle_1.json.gz")["parts"][0]
    assert str(p["onOrder"]) == "0"


@pytest.mark.parametrize("pos", [Decimal("1.00"), Decimal("0.001"), 3, 0.5])
def test_idle_positive_on_order_fails_naming_the_part(out, pos):
    # a positive on order makes the record active (L-D14), so Gold's active / idle split is wrong
    with pytest.raises(ValueError, match=r"'7'.*'E63245 '.*onOrder.*active"):
        _build_idle([_idle("1", "A1"), _idle("7", "E63245 ", onOrder=pos)])
    assert not out.exists() or not os.listdir(out)


@pytest.mark.parametrize("key", ["cost", "onOrder"])
def test_idle_null_never_null_number_fails(out, key):
    with pytest.raises(ValueError, match=key):
        _build_idle([_idle("1", "A1", **{key: None})])


@pytest.mark.parametrize("key", ["cost", "onOrder", "packageQty", "maximumQty"])
@pytest.mark.parametrize("bad", [float("nan"), float("-inf"), Decimal("NaN"), Decimal("-Infinity"), "-1", True])
def test_idle_non_finite_or_non_number_fails(out, key, bad):
    with pytest.raises(ValueError, match=key):
        _build_idle([_idle("1", "A1", **{key: bad})])


@pytest.mark.parametrize("key", sorted(JD_IDLE_FIELDS))
def test_idle_row_missing_field_fails(out, key):
    row = _idle("1", "A1")
    del row[key]
    with pytest.raises(ValueError, match=key):
        _build_idle([row])


def test_idle_twins_allowed_and_sorted_by_trimmed_part_then_raw(out):
    _build_idle([_idle("8", "E63245 ", cost=1), _idle("8", "B2"), _idle("8", "E63245", cost=2), _idle("8", " A9"),
                 _idle("8", "E6324")])
    parts = _read(out, "jd_idle_8.json.gz")["parts"]
    assert [p["partNumber"] for p in parts] == ["A9", "B2", "E6324", "E63245", "E63245"]
    assert [p["cost"] for p in parts[3:]] == [2, 1]


def test_idle_deterministic_whatever_the_input_order(out):
    h1, b1 = _build_idle()
    h2, b2 = _build_idle(list(reversed(IDLE)))
    assert h1 == h2 and b1 == b2


def test_idle_branch_order_numeric_then_alpha(out):
    _, idle_branches = _build_idle([_idle(b, "P") for b in ["4B", "93C", "10", "2", "15I", "97"]])
    assert [b["branch"] for b in idle_branches] == ["2", "10", "97", "15I", "4B", "93C"]


def test_idle_branch_key_collision_raises(out):
    with pytest.raises(ValueError, match="both map to file key"):
        _build_idle([_idle("1", "A"), _idle("1 ", "B")])


@pytest.mark.parametrize("branch", ["../x", "", None, "1 2"])
def test_idle_unsafe_branch_raises(out, branch):
    with pytest.raises(ValueError):
        _build_idle([_idle(branch, "A")])


def test_idle_file_over_the_upload_limit_fails_naming_the_branch(out, monkeypatch):
    monkeypatch.setattr(build_files, "JD_FILE_LIMIT", 1000)
    rows = [_idle("1", "A1")] + [_idle("92", f"P{i:05d}", description=f"part {i * 7919 % 10007}") for i in range(200)]
    with pytest.raises(ValueError, match=r"jd_idle_92\.json\.gz .*bytes.*branch 92"):
        _build_idle(rows)
    assert not (out / "jd_idle_92.json.gz").exists()


def test_idle_and_active_files_live_side_by_side(out):
    # build() clears the folder's old outputs; build_jd and build_jd_idle run after it and add to them
    hashes, _ = _build()
    jd_hashes, _ = _build_jd()
    idle_hashes, _ = _build_idle()
    assert not set(jd_hashes) & set(idle_hashes)
    assert sorted(os.listdir(out)) == sorted(set(hashes) | set(jd_hashes) | set(idle_hashes))


def test_is_output_covers_idle_files():
    assert build_files._is_output("jd_idle_4.json.gz") and build_files._is_output("jd_idle_93C.json.gz")


def test_stale_idle_files_cleared_by_build(out):
    _build_idle()
    _build()
    assert not [f for f in os.listdir(out) if f.startswith("jd_idle_")]


def test_idle_build_into_another_folder(out, tmp_path):
    dest = tmp_path / "local"
    hashes, _ = build_files.build_jd_idle(IDLE, JD_NAMES, AS_OF, out_dir=str(dest))
    assert sorted(os.listdir(dest)) == sorted(hashes)
    assert not out.exists()


def test_idle_empty_gives_no_files(out):
    assert _build_idle([]) == ({}, [])


def test_write_meta_has_jd_idle_branches(out):
    _, branches = _build()
    _, jd_branches = _build_jd()
    _, idle_branches = _build_idle()
    path = build_files.write_meta(AS_OF, AS_OF, "dev", branches, {"parts": 4, "jdParts": 4, "jdIdleParts": 4},
                                  jd_branches=jd_branches, jd_idle_branches=idle_branches)
    meta = json.loads(open(path, "rb").read())
    assert meta["jdIdleBranches"] == idle_branches and meta["counts"]["jdIdleParts"] == 4
    assert meta["jdBranches"] == jd_branches and meta["contractVersion"] == 9


# ---- Plan S (contract 9): the JD order files ----
JD_ROUND2 = {k: v for k, v in ROUND2.items()
             if k in ("pendingQty", "slc", "source", "commodityCode", "phaseInQty", "phaseInEnds", "phaseInOn",
                      "phaseInActive", "phaseInEndReason")}


def jd_order_row(branch="1", partNumber="P", **kw):
    r = {"branch": branch, "franchise": "D", "partNumber": partNumber, "onHand": 5, "target": 3, "surplusQty": 2,
         "status": "OK", "cost": Decimal("12.50"), **JD_ROUND2, "lastReceived": date(2026, 10, 2),
         "equipStockValue": Decimal("62.50")}
    r.update(kw)
    return r


def hist_row(branch, partNumber="P", monthOffset=1):
    return {"branch": branch, "franchise": "D", "partNumber": partNumber, "monthOffset": monthOffset, "salesQty": 2,
            "requestCount": 1}


def read_gz(path):
    return json.loads(gzip.decompress(path.read_bytes()))


def test_build_jd_order_files(tmp_path):
    rows = [jd_order_row(branch="12", partNumber="B"), jd_order_row(branch="12", partNumber="A")]
    hashes, branches = build_files.build_jd_order(rows, {"12": "Vault"}, AS_OF, out_dir=str(tmp_path))
    assert set(hashes) == {"jdorder_12.json.gz"}                           # branch 12 allowed (S-D5)
    assert branches == [{"branch": "12", "name": "Vault", "parts": 2}]
    doc = read_gz(tmp_path / "jdorder_12.json.gz")
    assert doc["branch"] == "12" and doc["dataAsOf"] == AS_OF
    assert [p["partNumber"] for p in doc["parts"]] == ["A", "B"]
    assert "transferRuleId" not in doc["parts"][0] and "branch" not in doc["parts"][0]   # S-P3
    assert doc["parts"][0]["lastReceived"] == "2026-10-02" and doc["parts"][0]["equipStockValue"] == 62.5


def test_build_jd_order_applies_the_never_null_rules_it_has_fields_for(tmp_path):
    doc_rows = [jd_order_row(pendingQty=None)]
    build_files.build_jd_order(doc_rows, {}, AS_OF, out_dir=str(tmp_path))
    assert read_gz(tmp_path / "jdorder_1.json.gz")["parts"][0]["pendingQty"] == 0
    with pytest.raises(ValueError, match="phaseInActive"):
        build_files.build_jd_order([jd_order_row(phaseInActive=None)], {}, AS_OF, out_dir=str(tmp_path))
    bad = jd_order_row()
    del bad["lastReceived"]
    with pytest.raises(ValueError, match="lastReceived"):
        build_files.build_jd_order([bad], {}, AS_OF, out_dir=str(tmp_path))


def test_build_jd_order_refuses_a_file_over_the_limit(tmp_path, monkeypatch):
    monkeypatch.setattr(build_files, "JD_FILE_LIMIT", 10)
    with pytest.raises(ValueError, match="upload limit"):
        build_files.build_jd_order([jd_order_row()], {}, AS_OF, out_dir=str(tmp_path))


def test_build_jd_history_files(tmp_path):
    hashes = build_files.build_jd_history(lambda b: [hist_row(b)], ["12"], date(2026, 11, 1), out_dir=str(tmp_path))
    assert set(hashes) == {"jdhistory_12.json.gz"}
    doc = read_gz(tmp_path / "jdhistory_12.json.gz")
    assert len(doc["months"]) == 60 and doc["months"][0] == "2026-11" and doc["branch"] == "12"
    assert doc["parts"][0]["franchise"] == "D" and doc["parts"][0]["sales"][0] == 2


def test_build_jd_history_refuses_a_file_over_the_limit(tmp_path, monkeypatch):
    monkeypatch.setattr(build_files, "JD_FILE_LIMIT", 10)
    with pytest.raises(ValueError, match="upload limit"):
        build_files.build_jd_history(lambda b: [hist_row(b)], ["12"], date(2026, 11, 1), out_dir=str(tmp_path))


def test_build_jd_rules_file(tmp_path):
    hashes = build_files.build_jd_rules(list(reversed(RULES)), AS_OF, out_dir=str(tmp_path))
    assert set(hashes) == {"jd_rules.json.gz"}
    doc = read_gz(tmp_path / "jd_rules.json.gz")
    assert doc["dataAsOf"] == AS_OF and [r["id"] for r in doc["rules"]] == sorted(r["id"] for r in RULES)
    with pytest.raises(ValueError, match="JD_OrderRules"):
        build_files.build_jd_rules([{"id": 1}], AS_OF, out_dir=str(tmp_path))


def test_meta_has_the_jd_order_fields(tmp_path):
    path = build_files.write_meta(AS_OF, AS_OF, "dev", [], {}, out_dir=str(tmp_path), jd_branches=[], jd_idle_branches=[],
                                  jd_order_branches=[{"branch": "12", "name": "Vault", "parts": 2}], jd_order_as_of="x")
    meta = json.load(open(path))
    assert meta["contractVersion"] == 9 and meta["jdOrderAsOf"] == "x" and meta["jdOrderBranches"][0]["branch"] == "12"


def test_non_jd_files_unchanged_by_the_jd_build(out):
    hashes, _ = _build()
    before = {n: (out / n).read_bytes() for n in hashes}
    jd_hashes, jd_branches = build_files.build_jd_order([jd_order_row(), jd_order_row(branch="12")], {}, AS_OF)
    jd_hashes.update(build_files.build_jd_history(lambda b: [hist_row(b)], [b["branch"] for b in jd_branches], MONTH))
    jd_hashes.update(build_files.build_jd_rules(RULES, AS_OF))
    assert not set(jd_hashes) & set(hashes)
    assert {n: (out / n).read_bytes() for n in hashes} == before
    for n, digest in hashes.items():
        assert hashlib.sha256((out / n).read_bytes()).hexdigest() == digest
