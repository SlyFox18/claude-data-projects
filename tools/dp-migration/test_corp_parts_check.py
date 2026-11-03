# tools/dp-migration/test_corp_parts_check.py
"""Tests for the reference Corp demand rule and Fact_CorpParts_JD rows (Plan L: docs/superpowers/plans/2026-11-03-
spi-parts-hub-inventory-reports.md, decisions L-D10..L-D14 and L-D19), the MLPF Gaps filter, the Gold compare and
the workbook comparison. In-memory DuckDB tables only."""
from datetime import datetime, timedelta

import duckdb
import openpyxl
import pytest

import corp_parts_check as chk

NOW = datetime(2026, 11, 3, 9, 41, 0)       # Central wall clock, as Equip stores TransDatetime
RECENT = NOW - timedelta(days=30)           # comfortably inside the invoice window


# ---------------------------------------------------------------------------------------------------------
# fixtures
# ---------------------------------------------------------------------------------------------------------
def _con():
    con = duckdb.connect()
    con.execute("SET TimeZone='UTC'")
    con.execute("""CREATE TABLE parts (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, Description VARCHAR,
                   Cost DECIMAL(12,2), QuantityOnHand DECIMAL(12,2), OnOrder DECIMAL(12,2), PackageQty VARCHAR,
                   Returnable VARCHAR, Source VARCHAR, SLC VARCHAR, SuperTo VARCHAR, CommodityCode VARCHAR,
                   DealerGroupCode VARCHAR, Current12MoSales DECIMAL(27,2), Previous12MoSales DECIMAL(27,2))""")
    con.execute("""CREATE TABLE intrans (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, Type VARCHAR,
                   Qty DECIMAL(8,2), TransDatetime TIMESTAMP, RONumber VARCHAR, OriginalInvoiceNo VARCHAR)""")
    con.execute("""CREATE TABLE rules (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MinimumQty DECIMAL(10,2),
                   MaximumQty DECIMAL(10,2))""")
    con.execute("CREATE TABLE groups (CommodityCode VARCHAR, CommodityGroup VARCHAR)")
    return con


def _part(con, pn, branch="1", franchise="D", oh=0, oo=0, sales12=0, prev12=0, pkg="1.00", ri="R", source="JD",
          slc="10", super_to="", commodity="AB", dgc="X", cost=12.5, desc="Thing"):
    con.execute("INSERT INTO parts VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [branch, franchise, pn, desc, cost, oh, oo, pkg, ri, source, slc, super_to, commodity, dgc,
                 sales12, prev12])


def _tx(con, pn, typ, qty, when, inv=None, orig=None, branch="1", franchise="D"):
    con.execute("INSERT INTO intrans VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [branch, franchise, pn, typ, qty, when, inv, orig])


def _sale(con, pn, inv, when=RECENT, qty=1, **kw):
    _tx(con, pn, "I", qty, when, inv=inv, **kw)


def _credit(con, pn, orig, when=RECENT, qty=-1, **kw):
    _tx(con, pn, "C", qty, when, inv="CR" + orig, orig=orig, **kw)


def _run(con, now=NOW):
    """Expected rows keyed by (Branch, Franchise, PartNumber)."""
    chk.build_expected(con, now)
    cur = con.execute("SELECT * FROM expected")
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    out = {(r["Branch"], r["Franchise"], r["PartNumber"]): r for r in rows}
    assert len(out) == len(rows), "duplicate keys in the expected output"
    return out


def _demands(con, pn="P1", branch="1", now=NOW):
    rows = _run(con, now)
    row = rows.get((branch, "D", pn))
    return None if row is None else row["CorpDemands"]


# ---------------------------------------------------------------------------------------------------------
# window
# ---------------------------------------------------------------------------------------------------------
def test_add_months_dt_clamps_and_keeps_time():
    assert chk.add_months_dt(datetime(2026, 8, 31, 14, 5, 6), -18) == datetime(2025, 2, 28, 14, 5, 6)
    assert chk.add_months_dt(datetime(2026, 11, 3, 9, 41), -18) == datetime(2025, 5, 3, 9, 41)
    assert chk.add_months_dt(datetime(2024, 3, 31), -1) == datetime(2024, 2, 29)


def test_window_bounds():
    ws, ie, now = chk.window(NOW)
    assert ws == datetime(2025, 5, 3, 9, 41)
    assert ie == datetime(2026, 10, 27, 9, 41)
    assert now == NOW


# ---------------------------------------------------------------------------------------------------------
# Corp demand rule (L-D10, L-D11)
# ---------------------------------------------------------------------------------------------------------
def test_two_lines_on_one_invoice_is_one_demand():
    con = _con()
    _part(con, "P1")
    _sale(con, "P1", "A1", qty=1)
    _sale(con, "P1", "A1", qty=4)
    assert _demands(con) == 1


def test_two_invoices_are_two_demands():
    con = _con()
    _part(con, "P1")
    _sale(con, "P1", "A1")
    _sale(con, "P1", "A2")
    assert _demands(con) == 2


def test_fully_credited_invoice_is_zero():
    con = _con()
    _part(con, "P1", oh=1)          # active through on hand so the row stays
    _sale(con, "P1", "A1", qty=2)
    _credit(con, "P1", "A1", qty=-2)
    assert _demands(con) == 0


def test_partially_credited_invoice_is_one():
    con = _con()
    _part(con, "P1")
    _sale(con, "P1", "A1", qty=3)
    _credit(con, "P1", "A1", qty=-1)
    assert _demands(con) == 1


def test_credit_today_cancels_older_sale():
    """Credits have no 7-day cutoff: one dated just before now still cancels its invoice."""
    con = _con()
    _part(con, "P1", oh=1)
    _sale(con, "P1", "A1")
    _credit(con, "P1", "A1", when=NOW - timedelta(minutes=5))
    assert _demands(con) == 0


def test_credit_after_now_is_ignored():
    con = _con()
    _part(con, "P1")
    _sale(con, "P1", "A1")
    _credit(con, "P1", "A1", when=NOW + timedelta(minutes=5))
    assert _demands(con) == 1


def test_credit_whose_invoice_is_outside_the_window_is_zero():
    con = _con()
    _part(con, "P1", oh=1)
    _sale(con, "P1", "OLD", when=NOW - timedelta(days=800))
    _credit(con, "P1", "OLD")
    _sale(con, "P1", "NEW", when=NOW - timedelta(days=3))      # too recent: no 'I' line in the window
    _credit(con, "P1", "NEW", qty=1)                            # positive credit qty is not a credit line
    assert _demands(con) == 0


def test_invoice_6_days_old_is_zero_and_8_days_old_is_one():
    con = _con()
    _part(con, "P1", oh=1)
    _sale(con, "P1", "A1", when=NOW - timedelta(days=6))
    assert _demands(con) == 0
    _sale(con, "P1", "A2", when=NOW - timedelta(days=8))
    assert _demands(con) == 1


def test_invoice_window_edges_inclusive():
    con = _con()
    _part(con, "P1")
    ws, ie, _ = chk.window(NOW)
    _sale(con, "P1", "A1", when=ws)
    _sale(con, "P1", "A2", when=ie)
    _sale(con, "P1", "A3", when=ws - timedelta(seconds=1))
    _sale(con, "P1", "A4", when=ie + timedelta(seconds=1))
    assert _demands(con) == 2


def test_transfer_is_zero():
    con = _con()
    _part(con, "P1", oh=1)
    _tx(con, "P1", "T", 1, RECENT, inv="T1")
    _tx(con, "P1", "P", 1, RECENT, inv="T2")
    assert _demands(con) == 0


def test_non_d_intrans_is_zero():
    con = _con()
    _part(con, "P1", oh=1)
    _sale(con, "P1", "A1", franchise="MC")
    assert _demands(con) == 0


def test_lower_case_and_padded_franchise_type_branch_count():
    con = _con()
    _part(con, "P1", branch="4b")
    _tx(con, "P1", " i ", 1, RECENT, inv="A1", branch=" 4B ", franchise=" d")
    assert _demands(con, branch="4b") == 1


def test_trailing_space_part_and_invoice_numbers_group_together():
    con = _con()
    _part(con, "P1")
    _part(con, "P1 ")               # the twin: both rows get the trimmed part's demand
    _sale(con, "P1", "A1")
    _sale(con, "P1 ", "A1 ")        # same invoice as above
    _sale(con, "P1 ", "A2")
    _credit(con, "P1", "A2 ")       # cancels A2
    rows = _run(con)
    assert rows[("1", "D", "P1")]["CorpDemands"] == 1
    assert rows[("1", "D", "P1 ")]["CorpDemands"] == 1


def test_other_branch_does_not_count():
    con = _con()
    _part(con, "P1")
    _sale(con, "P1", "A1", branch="2")
    assert _demands(con) is None     # no demand and nothing else: inactive, dropped


# ---------------------------------------------------------------------------------------------------------
# part rows (L-D12..L-D14)
# ---------------------------------------------------------------------------------------------------------
def test_inactive_part_dropped_active_kinds_kept():
    con = _con()
    _part(con, "DEAD")
    _part(con, "NEGOH", oh=-1)
    _part(con, "OO", oo=2)
    _part(con, "NEGOO", oo=-1)       # on order must be > 0
    _part(con, "S12", sales12=1)
    _part(con, "SP12", prev12=3)
    _part(con, "NET0", sales12=2, prev12=-2)
    _part(con, "DEM")
    _sale(con, "DEM", "A1")
    _part(con, "NULLS", oh=None, oo=None, sales12=None, prev12=None)
    keys = {k[2] for k in _run(con)}
    assert keys == {"NEGOH", "OO", "S12", "SP12", "DEM"}


def test_only_franchise_d_parts():
    con = _con()
    _part(con, "P1", franchise="MC", oh=5)
    _part(con, "P2", franchise=" d ", oh=5)
    assert set(_run(con)) == {("1", " d ", "P2")}


def test_unmapped_commodity_is_other():
    con = _con()
    con.execute("INSERT INTO groups VALUES (' ab ', 'Filters'), ('ZZ', NULL)")
    _part(con, "P1", oh=1, commodity="AB")
    _part(con, "P2", oh=1, commodity="QQ")
    _part(con, "P3", oh=1, commodity=None)
    _part(con, "P4", oh=1, commodity="zz")
    rows = _run(con)
    assert rows[("1", "D", "P1")]["CommodityGroup"] == "Filters"
    assert rows[("1", "D", "P2")]["CommodityGroup"] == "Other"
    assert rows[("1", "D", "P3")]["CommodityGroup"] == "Other"
    assert rows[("1", "D", "P4")]["CommodityGroup"] == "Other"


def test_duplicate_commodity_codes_fail():
    con = _con()
    con.execute("INSERT INTO groups VALUES ('AB', 'Filters'), ('ab ', 'Belts')")
    _part(con, "P1", oh=1)
    with pytest.raises(ValueError, match="CommodityCodeGroups"):
        _run(con)


def test_package_qty_cast():
    con = _con()
    _part(con, "P1", oh=1, pkg="1.00")
    _part(con, "P2", oh=1, pkg="abc")
    _part(con, "P3", oh=1, pkg=" 2 ")
    _part(con, "P4", oh=1, pkg=None)
    rows = _run(con)
    assert rows[("1", "D", "P1")]["PackageQty"] == 1
    assert rows[("1", "D", "P2")]["PackageQty"] is None
    assert rows[("1", "D", "P3")]["PackageQty"] == 2
    assert rows[("1", "D", "P4")]["PackageQty"] is None


def test_return_indicator_trimmed_and_columns():
    con = _con()
    _part(con, "P1", oh=3, oo=1, ri=" R ", sales12=4, prev12=5)
    con.execute("INSERT INTO rules VALUES ('1', 'D', 'P1', 2, 6), ('1', 'MC', 'P1', 9, 9)")
    r = _run(con)[("1", "D", "P1")]
    assert r["ReturnIndicator"] == "R"
    assert (r["MinimumQty"], r["MaximumQty"]) == (2, 6)
    assert (r["OnHand"], r["OnOrder"], r["Sales12"], r["SalesPrev12"]) == (3, 1, 4, 5)
    assert r["CorpDemands"] == 0
    assert list(r) == chk.OUTPUT_COLS


def test_no_stocking_rule_is_null():
    con = _con()
    _part(con, "P1", oh=1)
    con.execute("INSERT INTO rules VALUES ('1', 'D', 'P1 ', 2, 6)")     # full key as stored: no match
    r = _run(con)[("1", "D", "P1")]
    assert r["MinimumQty"] is None and r["MaximumQty"] is None


def test_stocking_rule_fan_out_fails():
    con = _con()
    _part(con, "P1", oh=1)
    con.execute("INSERT INTO rules VALUES ('1', 'D', 'P1', 2, 6), ('1', 'D', 'P1', 3, 6)")
    with pytest.raises(ValueError, match="Silver_PartStockingRules"):
        _run(con)


# ---------------------------------------------------------------------------------------------------------
# MLPF Gaps (L-D19)
# ---------------------------------------------------------------------------------------------------------
def _mlpf_fixture(con):
    """One passing part (PASS) and parts that fail exactly one condition each."""
    ok = dict(oh=0, oo=0, pkg="1.00", ri="R", source="JD", slc="10", super_to="")
    fails = {"PASS": {}, "B12": {"branch": "12"}, "OH1": {"oh": 1}, "OO1": {"oo": 1}, "PKG2": {"pkg": "2"},
             "RIN": {"ri": "N"}, "SAN": {"source": " an "}, "SLC21": {"slc": "21A"}, "SLC90": {"slc": " 90"},
             "SLC91": {"slc": "91"}, "SLC99": {"slc": "99Z"}, "SUP": {"super_to": "X9 "}, "D3": {}, "D1": {}}
    for pn, over in fails.items():
        kw = {**ok, **over}
        _part(con, pn, **kw)
        branch = kw.get("branch", "1")
        n = {"D3": 3, "D1": 1}.get(pn, 2)
        for i in range(n):
            _sale(con, pn, f"{pn}-{i}", branch=branch)
    # passes too: blank Source and SLC, padded R and blank-padded SuperTo (app semantics keep blanks)
    _part(con, "BLANKS", source=None, slc=None, ri=" r", super_to="   ", oh=-2)
    _sale(con, "BLANKS", "B-1")
    _sale(con, "BLANKS", "B-2")


def test_mlpf_filter_keeps_only_the_passing_parts():
    con = _con()
    _mlpf_fixture(con)
    chk.build_expected(con, NOW)
    rows = chk.mlpf_rows(con, "expected")
    assert [(r["Branch"], r["PartNumber"]) for r in rows] == [("1", "BLANKS"), ("1", "PASS")]
    assert list(rows[0]) == chk.MLPF_COLUMNS
    assert rows[1]["Demands"] == 2 and rows[1]["Source"] == "JD"


def test_mlpf_sorted_by_part_then_branch_and_trimmed():
    con = _con()
    for b, pn in (("2", "B "), ("10", "A"), ("1", "B")):
        _part(con, pn, branch=b, desc=" Thing ")
        _sale(con, pn, "X1", branch=b)
        _sale(con, pn, "X2", branch=b)
    chk.build_expected(con, NOW)
    rows = chk.mlpf_rows(con, "expected")
    assert [(r["Branch"], r["PartNumber"]) for r in rows] == [("10", "A"), ("1", "B"), ("2", "B")]
    assert rows[0]["Description"] == "Thing"


# ---------------------------------------------------------------------------------------------------------
# Gold compare
# ---------------------------------------------------------------------------------------------------------
def _gold_from_expected(con):
    con.execute("CREATE TABLE gold AS SELECT *, TIMESTAMP '2026-11-03 09:41:00' AS DemandAsOf FROM expected")


def test_compare_identical_passes():
    con = _con()
    _mlpf_fixture(con)
    chk.build_expected(con, NOW)
    _gold_from_expected(con)
    res = chk.compare(con, "gold", "expected")
    assert not any(res.values()), res
    assert chk.differences(con, "gold", "expected") == []


def test_compare_finds_number_text_null_and_missing_rows():
    con = _con()
    _mlpf_fixture(con)
    chk.build_expected(con, NOW)
    _gold_from_expected(con)
    con.execute("UPDATE gold SET Cost = Cost + 0.004 WHERE PartNumber = 'PASS'")     # within tolerance
    con.execute("UPDATE gold SET OnHand = OnHand + 0.01 WHERE PartNumber = 'D1'")
    con.execute("UPDATE gold SET Source = 'JD ' WHERE PartNumber = 'D3'")
    con.execute("UPDATE gold SET MinimumQty = 1 WHERE PartNumber = 'OH1'")           # NULL vs value
    con.execute("DELETE FROM gold WHERE PartNumber = 'RIN'")
    con.execute("INSERT INTO gold SELECT * REPLACE ('EXTRA' AS PartNumber) FROM gold WHERE PartNumber = 'SAN'")
    res = chk.compare(con, "gold", "expected")
    assert res == {"only_gold": 1, "only_expected": 1, "different": 3, "dup_gold": 0, "dup_expected": 0}
    diffs = chk.differences(con, "gold", "expected")
    kinds = sorted((d["Kind"], d["PartNumber"], d["Column"]) for d in diffs)
    assert kinds == [("different", "D1", "OnHand"), ("different", "D3", "Source"),
                     ("different", "OH1", "MinimumQty"), ("only_expected", "RIN", ""),
                     ("only_gold", "EXTRA", "")]


# ---------------------------------------------------------------------------------------------------------
# workbook comparison
# ---------------------------------------------------------------------------------------------------------
def _xlsx(tmp_path, rows, sheet="MLPF Gaps", title_rows=0):
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = sheet
    for _ in range(title_rows):
        ws.append(["Refreshed 2026-11-03"])
    ws.append(chk.MLPF_COLUMNS)
    for r in rows:
        ws.append(r)
    p = tmp_path / "mlpf.xlsx"
    wb.save(p)
    return str(p)


def test_compare_xlsx_matches_on_trimmed_branch_and_part(tmp_path):
    con = _con()
    _mlpf_fixture(con)
    chk.build_expected(con, NOW)
    ours = chk.mlpf_rows(con, "expected")
    by = {r["PartNumber"]: r for r in ours}
    p = by["PASS"]
    xl = [
        # PASS: same values, branch as a number and padded part number
        [1, "PASS ", p["Description"], float(p["Cost"]), "JD", "10", "AB", "Other", "X", 0, 0, 2],
        # a part only in the workbook
        ["3", "ONLYXL", "Thing", 1.0, "JD", "10", "AB", "Other", "X", 0, 0, 2],
    ]
    path = _xlsx(tmp_path, xl, title_rows=1)
    xl_rows = chk.read_xlsx(path, "MLPF Gaps")
    assert len(xl_rows) == 2 and xl_rows[0]["Branch"] == "1"
    res = chk.compare_xlsx(con, xl_rows, ours)
    assert res["excel_rows"] == 2 and res["our_rows"] == 2
    assert [(d["Branch"], d["PartNumber"]) for d in res["only_excel"]] == [("3", "ONLYXL")]
    assert [(d["Branch"], d["PartNumber"]) for d in res["only_ours"]] == [("1", "BLANKS")]
    assert res["values"] == []


def test_compare_xlsx_value_differences(tmp_path):
    con = _con()
    _mlpf_fixture(con)
    chk.build_expected(con, NOW)
    ours = chk.mlpf_rows(con, "expected")
    p = {r["PartNumber"]: r for r in ours}["PASS"]
    xl = [["1", "PASS", p["Description"] + " ", float(p["Cost"]) + 0.004, "JDX", "10", "AB", "Other", None,
           0, 0, 3]]
    res = chk.compare_xlsx(con, chk.read_xlsx(_xlsx(tmp_path, xl), "MLPF Gaps"), ours)
    cols = sorted(d["Column"] for d in res["values"])
    # Description trimmed (equal), Cost within 0.005; DealerGroupCode None vs 'X' differs
    assert cols == ["DealerGroupCode", "Demands", "Source"]


def test_read_xlsx_missing_header_fails(tmp_path):
    wb = openpyxl.Workbook()
    wb.active.title = "MLPF Gaps"
    wb.active.append(["Branch", "Part"])
    p = tmp_path / "bad.xlsx"
    wb.save(p)
    with pytest.raises(ValueError, match="header"):
        chk.read_xlsx(str(p), "MLPF Gaps")


# ---------------------------------------------------------------------------------------------------------
# idle table (Plan M, M1 / M2): franchise D records the active table leaves out
# ---------------------------------------------------------------------------------------------------------
def _idle(con):
    cur = con.execute("SELECT * FROM expected_idle")
    cols = [d[0] for d in cur.description]
    return {(r[0], r[1], r[2]): dict(zip(cols, r)) for r in cur.fetchall()}


def test_idle_is_silver_d_minus_active_with_its_columns():
    con = _con()
    con.execute("INSERT INTO groups VALUES ('AB', 'Filters')")
    con.execute("INSERT INTO rules VALUES ('1', 'D', 'DEAD', 1, 4)")
    _part(con, "DEAD", ri=" R ", pkg=" 1 ")
    _part(con, "NEGOO", oo=-1)                  # on order <= 0: idle
    _part(con, "ACT", oh=1)
    _part(con, "DEM")
    _sale(con, "DEM", "A1")
    _part(con, "OTHER", franchise="MC")          # not franchise D: in neither table
    chk.build_expected(con, NOW)
    idle = _idle(con)
    assert set(idle) == {("1", "D", "DEAD"), ("1", "D", "NEGOO")}
    r = idle[("1", "D", "DEAD")]
    assert list(r) == chk.IDLE_COLS
    assert r["ReturnIndicator"] == "R" and r["PackageQty"] == 1 and r["CommodityGroup"] == "Filters"
    assert (r["MinimumQty"], r["MaximumQty"]) == (1, 4)
    assert set(_run(con)) == {("1", "D", "ACT"), ("1", "D", "DEM")}
    res = chk.idle_checks(con)
    assert res == {"silver_d": 4, "active": 2, "idle": 2, "overlap": 0, "dup_idle": 0}
    assert chk.idle_problems(res) == []


def test_idle_checks_report_overlap_duplicates_and_gaps():
    con = _con()
    _part(con, "DEAD")
    _part(con, "ACT", oh=1)
    chk.build_expected(con, NOW)
    con.execute("INSERT INTO expected_idle SELECT * FROM expected_idle")          # a duplicate idle key
    con.execute("INSERT INTO expected_idle (Branch, Franchise, PartNumber) VALUES ('1', 'D', 'ACT')")
    res = chk.idle_checks(con)
    assert res["overlap"] == 1 and res["dup_idle"] == 1
    probs = chk.idle_problems(res)
    assert any("both" in p for p in probs)
    assert any("duplicate" in p for p in probs)
    assert any("cover" in p for p in probs)


def test_idle_gold_compare():
    con = _con()
    _part(con, "DEAD")
    _part(con, "DEAD2", desc="Other thing")
    chk.build_expected(con, NOW)
    con.execute("CREATE TABLE gold_idle AS SELECT *, TIMESTAMP '2026-11-03 15:00:00' AS BuiltAtUtc FROM expected_idle")
    res = chk.compare(con, "gold_idle", "expected_idle", chk.IDLE_TEXT, chk.IDLE_NUM)
    assert not any(res.values()), res
    con.execute("UPDATE gold_idle SET Description = 'X' WHERE PartNumber = 'DEAD2'")
    res = chk.compare(con, "gold_idle", "expected_idle", chk.IDLE_TEXT, chk.IDLE_NUM)
    assert res["different"] == 1
    diffs = chk.differences(con, "gold_idle", "expected_idle", text_cols=chk.IDLE_TEXT, num_cols=chk.IDLE_NUM)
    assert [(d["PartNumber"], d["Column"]) for d in diffs] == [("DEAD2", "Description")]


# ---------------------------------------------------------------------------------------------------------
# Border Stores and 2 & 4 Cotton (Plan M, the workbook code; M-D8, M-D9)
# ---------------------------------------------------------------------------------------------------------
GOOD = dict(oh=0, oo=0, pkg="1.00", ri="R", source="JD", slc="10", super_to="")


def _jd(con, pn, branch, demands=0, **kw):
    """A franchise D record with `demands` invoices in the window."""
    _part(con, pn, branch=branch, **{**GOOD, **kw})
    for i in range(demands):
        _sale(con, pn, f"{branch}-{pn}-{i}", branch=branch)


def _pool(con, pn, demands, **kw):
    """Other-branch records for `pn`: one per entry of `demands`, at branches 10, 11, 12..."""
    for i, d in enumerate(demands):
        _jd(con, pn, str(10 + i), d, **kw)


def _report(con, name, now=NOW):
    chk.build_expected(con, now)
    rows = chk.report_rows(con, name)
    return {(r["Branch"], r["PartNumber"]): r for r in rows}, rows


def test_border_counts_only_other_passing_rows_outside_2_and_4():
    con = _con()
    _jd(con, "P", "95", demands=1)                  # the candidate
    _pool(con, "P", [2, 2, 2, 2, 2])                # 10 demands at 5 branches
    _jd(con, "P", "2", demands=50)                  # branch 2 is not in the pool
    _jd(con, "P", "4", demands=50)                  # nor 4
    _jd(con, "P", "30", demands=50, pkg="2")        # fails a part filter
    _jd(con, "P", "31", demands=50, super_to="Q")   # superseded
    _jd(con, "P", "32", demands=50, oo=1)           # on order
    _jd(con, "P", "33", demands=50, ri="N")         # not returnable
    _jd(con, "P", "34", demands=0)                  # passes, no demand: adds nothing
    by, rows = _report(con, "border")
    r = by[("95", "P")]
    assert (r["Demands"], r["OtherBranchDemands"], r["OtherLocationCount"]) == (1, 10, 5)
    assert list(r) == chk.REPORT_COLUMNS
    assert len(rows) == 1


def test_border_own_branch_not_counted_and_twins_count_once():
    con = _con()
    _jd(con, "P", "95", demands=1)
    _jd(con, "P ", "95")                            # own branch's twin (shares the trimmed part's 1 demand)
    _pool(con, "P", [2, 2, 2, 2])                   # 8 at 4 branches (10..13)
    _jd(con, "P ", "14")                            # twin at branch 14 ...
    _jd(con, "P", "14", demands=4)                  # ... both rows carry branch 14's 4 demands (trimmed part)
    _, rows = _report(con, "border")
    # both 95 rows are candidates; neither counts the other (same branch); branch 14 counts once: +4 and +1
    assert [(r["Branch"], r["PartNumber"], r["OtherBranchDemands"], r["OtherLocationCount"]) for r in rows] == \
        [("95", "P", 12, 5), ("95", "P", 12, 5)]


def test_border_twin_branch_counts_once_when_only_one_twin_passes():
    con = _con()
    _jd(con, "P", "95", demands=1)
    _pool(con, "P", [2, 2, 2, 2])                   # 8 at 4 branches (10..13)
    _jd(con, "P", "14", demands=4)                  # passes
    _jd(con, "P ", "14", pkg="2")                   # its twin fails a part filter: the branch still counts once
    by, _ = _report(con, "border")
    r = by[("95", "P")]
    assert (r["OtherBranchDemands"], r["OtherLocationCount"]) == (12, 5)


def test_border_thresholds_at_their_edges():
    con = _con()
    _jd(con, "D9", "91", demands=1)
    _pool(con, "D9", [2, 2, 2, 2, 1])               # 9 demands: out
    _jd(con, "D10", "91", demands=1)
    _pool(con, "D10", [2, 2, 2, 2, 2])              # 10: in
    _jd(con, "L4", "96", demands=1)
    _pool(con, "L4", [4, 3, 2, 1])                  # 10 at 4 branches: out
    _jd(con, "L5", "96", demands=1)
    _pool(con, "L5", [3, 3, 2, 1, 1])               # 10 at 5: in
    by, _ = _report(con, "border")
    assert set(by) == {("91", "D10"), ("96", "L5")}


def test_border_candidate_conditions():
    con = _con()
    cases = {"OK": ("95", 1, {}), "B7": ("7", 1, {}), "D0": ("95", 0, {}), "OH1": ("95", 1, {"oh": 1}),
             "OO1": ("95", 1, {"oo": 1}), "PKG": ("95", 1, {"pkg": "2"}), "RIN": ("95", 1, {"ri": "N"}),
             "SAN": ("95", 1, {"source": "AN"}), "SLC": ("95", 1, {"slc": "91B"}),
             "SUP": ("95", 1, {"super_to": "Z"}), "D5": ("95", 5, {})}
    for pn, (b, d, kw) in cases.items():
        _jd(con, pn, b, d, **kw)
        _pool(con, pn, [2, 2, 2, 2, 2])
    _, rows = _report(con, "border")
    assert [(r["Branch"], r["PartNumber"]) for r in rows] == [("95", "D5"), ("95", "OK")]


def test_border_sorted_part_then_branch_and_candidates_count_each_other():
    con = _con()
    for pn in ("B", "A"):
        for b in ("96", "91"):
            _jd(con, pn, b, demands=1)
        _pool(con, pn, [2, 2, 2, 2, 2])
    _, rows = _report(con, "border")
    assert [(r["Branch"], r["PartNumber"]) for r in rows] == [("91", "A"), ("96", "A"), ("91", "B"), ("96", "B")]
    assert rows[0]["OtherBranchDemands"] == 11 and rows[0]["OtherLocationCount"] == 6


def test_cotton_idle_candidate_via_own_dealer_group():
    con = _con()
    _jd(con, "C1", "4", dgc="cotton ")              # idle: nothing on hand, on order, sold or demanded
    _pool(con, "C1", [2, 2, 2, 2, 2], dgc="STRIPPER")
    _jd(con, "C1", "20", demands=9, dgc="COMBINE")  # fails the cotton rule: not in the pool
    by, _ = _report(con, "cotton")
    r = by[("4", "C1")]
    assert (r["Demands"], r["OtherBranchDemands"], r["OtherLocationCount"]) == (0, 10, 5)
    assert con.execute("SELECT count(*) FROM expected_idle WHERE Branch = '4' AND PartNumber = 'C1'").fetchone()[0]


def test_cotton_via_model_code_at_another_branch_and_combine_without_model_code_out():
    con = _con()
    _jd(con, "M1", "2", dgc="")                      # blank here; coded 770 at branch 30 (an idle record)
    _jd(con, "M1 ", "30", dgc="770 ")
    _pool(con, "M1", [2, 2, 2, 2, 2], dgc="COMBINE")  # pool rows pass through the part's model code
    _jd(con, "X1", "2", dgc="COMBINE")               # no model code anywhere: out
    _pool(con, "X1", [2, 2, 2, 2, 2], dgc="COMBINE")
    _jd(con, "N1", "2", dgc="")                      # model code only on a non-D record: out (D records only)
    _part(con, "N1", branch="30", franchise="M", dgc="770")
    _pool(con, "N1", [2, 2, 2, 2, 2], dgc="COTTON")
    by, _ = _report(con, "cotton")
    assert set(by) == {("2", "M1")}
    assert by[("2", "M1")]["DealerGroupCode"] == ""


def test_cotton_candidate_conditions():
    con = _con()
    cases = {"OK": ("2", 0, {}), "B95": ("95", 0, {}), "D1": ("4", 1, {}), "OH1": ("4", 0, {"oh": 1}),
             "SAN": ("2", 0, {"source": "AN"}), "SUP": ("2", 0, {"super_to": "Z"}), "OON": ("2", 0, {"oo": -1})}
    for pn, (b, d, kw) in cases.items():
        _jd(con, pn, b, d, dgc="PICKER", **kw)
        _pool(con, pn, [2, 2, 2, 2, 2], dgc="PICKER")
    _, rows = _report(con, "cotton")
    assert [(r["Branch"], r["PartNumber"]) for r in rows] == [("2", "OK")]


def test_cotton_other_candidate_branch_is_not_in_the_pool():
    con = _con()
    _jd(con, "P", "2", dgc="COTTON")
    _jd(con, "P", "4", dgc="COTTON")
    _pool(con, "P", [2, 2, 2, 2, 2], dgc="COTTON")
    by, _ = _report(con, "cotton")
    assert set(by) == {("2", "P"), ("4", "P")}
    assert (by[("2", "P")]["OtherBranchDemands"], by[("2", "P")]["OtherLocationCount"]) == (10, 5)


def test_report_rows_mlpf_is_the_mlpf_list():
    con = _con()
    _mlpf_fixture(con)
    chk.build_expected(con, NOW)
    assert chk.report_rows(con, "mlpf") == chk.mlpf_rows(con, "expected")


def test_compare_xlsx_with_the_other_branch_columns(tmp_path):
    con = _con()
    _jd(con, "P", "95", demands=1)
    _pool(con, "P", [2, 2, 2, 2, 2])
    _, ours = _report(con, "border")
    base = [ours[0][c] for c in chk.MLPF_COLUMNS]
    base[3] = float(base[3])
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Border Stores"
    ws.append(chk.REPORT_COLUMNS)
    ws.append(base + [11, 5])                        # OtherBranchDemands differs
    p = tmp_path / "border.xlsx"
    wb.save(p)
    xl = chk.read_xlsx(str(p), "Border Stores", chk.REPORT_COLUMNS)
    assert xl[0]["OtherBranchDemands"] == 11
    res = chk.compare_xlsx(con, xl, ours, chk.REPORT_COLUMNS, chk.REPORT_NUM)
    assert [(d["Column"], d["Excel"], d["Ours"]) for d in res["values"]] == [("OtherBranchDemands", 11, 10)]


def test_read_xlsx_report_columns_required(tmp_path):
    wb = openpyxl.Workbook()
    wb.active.title = "Border Stores"
    wb.active.append(chk.MLPF_COLUMNS)
    p = tmp_path / "mlpf_only.xlsx"
    wb.save(p)
    with pytest.raises(ValueError, match="OtherLocationCount"):
        chk.read_xlsx(str(p), "Border Stores", chk.REPORT_COLUMNS)
