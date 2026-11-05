import duckdb

import superseded_stock_check as s


def _con():
    con = duckdb.connect()
    con.execute("""CREATE TABLE t AS SELECT * FROM (VALUES
        ('1', 'A', 2.0, 'B'), ('1', 'C', 0.0, 'D'), ('7', 'E', 1.0, '  '), ('7', 'F', 3.0, NULL),
        ('11', 'G', 1.0, 'BOLTS'), ('2', 'H', 0.5, 'J')) v(Branch, PartNumber, QuantityOnHand, SuperTo)""")
    return con


def test_rows_on_hand_and_super_to_in_branch_order():
    rows = s.superseded_rows(_con(), "t", "QuantityOnHand")
    assert [(r["Branch"], r["PartNumber"]) for r in rows] == [("1", "A"), ("2", "H"), ("11", "G")]
