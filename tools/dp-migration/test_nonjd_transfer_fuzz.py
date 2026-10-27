# tools/dp-migration/test_nonjd_transfer_fuzz.py
"""Tests for the transfer fuzz generator (Task E3 Step 4, X5): determinism, valid cases, and expected output that
agrees with the reference."""
import json

import pytest

import nonjd_reorder_check as chk
import nonjd_transfer_fuzz as fz


@pytest.fixture(scope="module")
def sample():
    cases = fz.generate(11, 400)
    return cases, fz.expected_for(cases)


def test_same_seed_gives_identical_files(tmp_path):
    a = fz.write(5, 60, str(tmp_path / "a"))
    b = fz.write(5, 60, str(tmp_path / "b"))
    for pa, pb in zip(a, b):
        assert open(pa, "rb").read() == open(pb, "rb").read()


def test_different_seed_gives_different_cases():
    assert fz.dumps(fz.generate(1, 30)) != fz.dumps(fz.generate(2, 30))


def test_cli_writes_both_files(tmp_path, capsys):
    assert fz.main(["--seed", "3", "--groups", "25", "--out", str(tmp_path)]) == 0
    cases = json.load(open(tmp_path / "cases.json", encoding="utf-8"))
    expected = json.load(open(tmp_path / "expected.json", encoding="utf-8"))
    assert (cases["version"], cases["seed"], len(cases["groups"])) == (1, 3, 25)
    assert [g["id"] for g in expected["groups"]] == [g["id"] for g in cases["groups"]]
    assert "conventional" in capsys.readouterr().out


def test_cases_are_valid_groups(sample):
    cases, _ = sample
    kinds = {g["kind"] for g in cases["groups"]}
    assert kinds == {"full", "allocation"}
    rule_ids = []
    for g in cases["groups"]:
        branches = [r["Branch"] for r in g["rows"]]
        assert 2 <= len(branches) <= 19
        assert len({b.strip().upper() for b in branches}) == len(branches)
        assert not {b.strip().upper() for b in branches} & set(chk.EXCLUDED_BRANCHES)
        if g["kind"] == "full":
            assert g["today"] in fz.DATES
            for t in g["transferRules"]:
                rule_ids.append(t["Id"])
                assert t["Franchise"].strip().upper() == g["franchise"]
                assert set(t) == set(chk.TRANSFER_RULE_COLS)
            for r in g["rows"]:
                assert isinstance(r["oh"], int) and isinstance(r["oo"], int)
        else:
            for r in g["rows"]:
                assert not r["RedistEligible"] or r["MonthlyRate"] > 0
    assert len(rule_ids) == len(set(rule_ids))


def test_generator_reaches_every_path(sample):
    cases, expected = sample
    full = [g for g in expected["groups"] if g["kind"] == "full"]
    lines = [l for g in expected["groups"] for l in g["lines"]]
    rows = [r for g in full for r in g["rows"]]
    assert sum(l["Kind"] == "Conventional" for l in lines) > 20
    assert sum(l["Kind"] == "Redistribution" for l in lines) > 20
    assert any(g["invalidTransferRules"] for g in full)
    assert any(r["TransferRuleId"] is not None for r in rows) and any(r["TransferRuleId"] is None for r in rows)
    assert any(r["AppInboundQty"] > 0 for r in rows) and any(r["AppOutboundQty"] > 0 for r in rows)
    assert any(not r["AllowSend"] for r in rows) and any(r["ExcessUnit"] == "Weeks" for r in rows)
    assert any(r["RedistMinValue"] > 0 for r in rows)
    # a group where one receiver is filled from two senders, and allocation cases where a row has free and a need
    assert any(len({l["FromBranch"] for l in g["lines"] if l["Kind"] == "Conventional"}) > 1 for g in full)
    alloc = [g for g in cases["groups"] if g["kind"] == "allocation"]
    assert any(r["FreeExcess"] > 0 and r["ConvNeed"] > 0 for g in alloc for r in g["rows"])


def test_expected_lines_are_consistent(sample):
    _, expected = sample
    for g in expected["groups"]:
        lines = g["lines"]
        assert [l["Seq"] for l in lines] == list(range(1, len(lines) + 1))
        keys = [(l["Kind"], l["FromBranch"], l["ToBranch"]) for l in lines]
        assert len(keys) == len(set(keys))
        assert all(l["FromBranch"] != l["ToBranch"] and l["Qty"] > 0 for l in lines)
        kinds = [l["Kind"] for l in lines]
        assert kinds == sorted(kinds)                         # conventional first
        for l in lines:
            assert l["Value"] == round(l["Qty"] * l["ToCost"], 2)
        out = {}
        for l in lines:
            out[l["FromBranch"]] = out.get(l["FromBranch"], 0) + l["Qty"]
        for l in lines:
            assert out[l["FromBranch"]] <= l["FromFreeExcess"]
        if g["kind"] == "full":
            by_branch = {r["Branch"]: r for r in g["rows"]}
            for b, r in by_branch.items():
                assert r["SuggestedOutQty"] == out.get(b, 0)
                assert r["SuggestedInQty"] == sum(l["Qty"] for l in lines if l["ToBranch"] == b)
                assert r["SuggestedConvInQty"] == sum(l["Qty"] for l in lines
                                                      if l["ToBranch"] == b and l["Kind"] == "Conventional")
                assert r["SuggestedConvInQty"] <= r["ConvNeed"]
            assert [r["Branch"] for r in g["rows"]] == sorted(by_branch, key=chk.branch_order_key)


def _case(rows, rules=(), committed=(), today="2026-10-20"):
    base = {"oh": 0, "oo": 0, "PendingQty": None, "MonthlyRate": 0.0, "StockingTarget": 0, "ManualOrder": False,
            "IsMasked": False, "MinimumNoDemand": False, "Cost": 10.0, "DealerGroupCode": None, "SLC": None,
            "Source": None, "VendorCode": 0, "ProductGroup": None, "CommodityCode": None}
    return {"id": 1, "kind": "full", "today": today, "franchise": "F1", "partNumber": "P1",
            "rows": [{**base, **r} for r in rows], "transferRules": list(rules), "committed": list(committed)}


def _expected(case):
    return fz.expected_for({"version": 1, "seed": 0, "groups": [case]})["groups"][0]


def test_hand_case_through_the_fuzz_path():
    case = _case([{"Branch": "9", "oh": 10, "PendingQty": 1.5},
                  {"Branch": "1", "MonthlyRate": 0.5, "StockingTarget": 6}],
                 committed=[{"TransferId": 1, "LineId": 1, "Status": "Draft", "PlacedAt": None, "FromBranch": "5X",
                             "ToBranch": " 1 ", "Franchise": "F1", "PartNumber": "P1", "Qty": 2}])
    g = _expected(case)
    rows = {r["Branch"]: r for r in g["rows"]}
    assert (rows["9"]["FreeExcess"], rows["9"]["TransferRuleName"], rows["9"]["SuggestedOutQty"]) == \
        (9, "Built-in default", 4)
    assert (rows["1"]["AppInboundQty"], rows["1"]["BaseQty"], rows["1"]["ConvNeed"], rows["1"]["RedistCap"]) == \
        (2, 4, 4, 3)
    assert [(l["Kind"], l["FromBranch"], l["ToBranch"], l["Qty"]) for l in g["lines"]] == \
        [("Conventional", "9", "1", 4)]


def test_hand_case_rules_and_placed_dates():
    rule = {c: None for c in chk.TRANSFER_RULE_COLS}
    rule.update(Id=10, RuleName="No send", Priority=1, Active=True, Franchise=" f1 ", Branch="9", ExcessSupply=12,
                AllowSend=False)
    bad = {**rule, "Id": 11, "RuleName": "Bad", "Branch": None, "ExcessSupply": 61}
    placed = [{"TransferId": 1, "LineId": i, "Status": "Placed", "PlacedAt": at, "FromBranch": "9", "ToBranch": "1",
               "Franchise": "F1", "PartNumber": "P1", "Qty": 1}
              for i, at in enumerate(["2026-10-20T05:00:00Z", "2026-10-20T04:59:00Z", None], start=1)]
    g = _expected(_case([{"Branch": "9", "oh": 10}, {"Branch": "1", "MonthlyRate": 0.5, "StockingTarget": 6}],
                        rules=[rule, bad], committed=placed))
    rows = {r["Branch"]: r for r in g["rows"]}
    assert g["invalidTransferRules"] == [[11, "Bad", "ExcessSupply must be 0-60 months"]]
    assert (rows["9"]["TransferRuleId"], rows["9"]["AllowSend"], rows["9"]["FreeExcess"]) == (10, False, 0)
    assert (rows["1"]["AppInboundQty"], rows["9"]["AppOutboundQty"]) == (1, 1)    # only 00:00 CDT on the 20th
    assert g["lines"] == []


def test_allocation_case_matches_allocate_group(sample):
    cases, expected = sample
    g = next(c for c in cases["groups"] if c["kind"] == "allocation")
    rows = [{**r, "Franchise": g["franchise"], "PartNumber": g["partNumber"], "cost": r["Cost"]} for r in g["rows"]]
    want = next(e for e in expected["groups"] if e["id"] == g["id"])["lines"]
    assert chk.allocate_group(list(reversed(rows)), chk.branch_order_key) == want
