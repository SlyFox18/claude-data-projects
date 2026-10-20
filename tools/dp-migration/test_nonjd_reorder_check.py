# tools/dp-migration/test_nonjd_reorder_check.py
from datetime import date

import duckdb
import pytest

import nonjd_reorder_check as chk

CUR = date(2026, 10, 1)
TODAY = date(2026, 10, 20)


def _con():
    con = duckdb.connect()
    con.execute("""CREATE TABLE parts (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   QuantityOnHand DECIMAL(12,2), OnOrder DECIMAL(12,2), Cost DECIMAL(12,2))""")
    con.execute("CREATE TABLE rules (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MinimumQty DECIMAL(10,2))")
    con.execute("""CREATE TABLE hist (Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR, MonthStart DATE,
                   SalesQty DECIMAL(12,2), RequestCount INTEGER)""")
    con.execute("""CREATE TABLE matrix (MonthCount INTEGER, DemandL DOUBLE, DemandH DOUBLE, SalesL DOUBLE,
                   SalesH DOUBLE, Modifier DOUBLE, WarehouseMin INTEGER)""")
    con.execute("""CREATE TABLE settings (Id INTEGER, Branch VARCHAR, Franchise VARCHAR, PartNumber VARCHAR,
                   MinOverride DOUBLE, Masked BOOLEAN, MaskExpires DATE, Modified TIMESTAMP)""")
    con.execute("CREATE TABLE transfers (RequestingBranch VARCHAR, PartNumber VARCHAR, OpenQty DOUBLE)")
    return con


def _run(con):
    rows = chk.expected_reorder(con, CUR, TODAY).fetchall()
    cols = ["Branch", "Franchise", "PartNumber", "MonthCount", "StockingTarget", "RecommendedOrderQty",
            "SurplusQty", "InboundTransferQty", "Status"]
    return {r[2]: dict(zip(cols, r)) for r in rows}


def test_scope_excludes_jd_test_franchises_and_zero_cost():
    con = _con()
    con.execute("""INSERT INTO parts VALUES ('1','D','JD1',0,0,5), ('1','TD','T1',0,0,5), ('1','UM','U1',0,0,5),
                   ('1','ZP','Z1',0,0,5), ('1','MC','FREE',0,0,0), ('1','MC','OK1',0,0,5), ('1','DA','DA1',0,0,5)""")
    assert sorted(_run(con)) == ["DA1", "OK1"]


def test_matrix_modifier_and_target():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P1',1,0,10)")
    # 3 active months in the window, 6 requests -> avg demand 2.0; 9 sales -> avg sales 3.0
    con.execute("""INSERT INTO hist VALUES ('1','MC','P1','2026-10-01',3,2), ('1','MC','P1','2026-09-01',3,2),
                   ('1','MC','P1','2026-08-01',3,2), ('1','MC','P1','2025-01-01',99,99)""")
    con.execute("INSERT INTO matrix VALUES (3, 0, 5, 0, 999999, 1.5, 2)")
    r = _run(con)["P1"]
    assert r["MonthCount"] == 3
    assert r["StockingTarget"] == 3          # ceil(max(2, 0, 2.0 * 1.5))
    assert r["RecommendedOrderQty"] == 2     # 3 - 1 on hand - 0 on order
    assert r["Status"] == "Reorder"


def test_no_matrix_match_uses_defaults_and_min_qty():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P2',0,0,10)")
    con.execute("INSERT INTO rules VALUES ('1','MC','P2',4)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P2','2026-10-01',1,1)")
    r = _run(con)["P2"]
    assert r["StockingTarget"] == 4          # max(WarehouseMin 1, MinimumQty 4, 1.0 * 1.0)
    assert r["RecommendedOrderQty"] == 4
    assert r["Status"] == "OutOfStock"


def test_null_on_hand_counts_as_out_of_stock():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P8',NULL,0,10)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P8','2026-10-01',1,1)")
    r = _run(con)["P8"]
    assert r["RecommendedOrderQty"] == 1
    assert r["Status"] == "OutOfStock"


def test_settings_override_latest_row_wins_and_masking():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P3',0,0,10), ('1','MC','P4',0,0,10)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P3','2026-10-01',1,1), ('1','MC','P4','2026-10-01',1,1)")
    con.execute("""INSERT INTO settings VALUES
        (1,'1','MC','P3',2,false,NULL,'2026-10-01 10:00'), (2,'1','MC','P3',7,false,NULL,'2026-10-05 10:00'),
        (3,'1','MC','P4',NULL,true,'2026-12-31','2026-10-01 10:00')""")
    r = _run(con)
    assert r["P3"]["StockingTarget"] == 7
    assert r["P4"]["RecommendedOrderQty"] == 0 and r["P4"]["Status"] == "Masked"


def test_expired_mask_is_ignored():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','P5',0,0,10)")
    con.execute("INSERT INTO hist VALUES ('1','MC','P5','2026-10-01',1,1)")
    con.execute("INSERT INTO settings VALUES (1,'1','MC','P5',NULL,true,'2026-10-19','2026-10-01 10:00')")
    assert _run(con)["P5"]["Status"] == "OutOfStock"


def test_no_activity_is_surplus_and_truncates_quantities():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('92','MC','P6',10.7,0,10), ('92','MC','P7',9.9,0,10)")
    con.execute("INSERT INTO hist VALUES ('92','MC','P7','2026-10-01',1,1)")
    r = _run(con)
    assert r["P6"]["Status"] == "NoRecentActivity"
    assert r["P6"]["StockingTarget"] is None and r["P6"]["SurplusQty"] == 10
    assert r["P7"]["SurplusQty"] == 8         # trunc(9.9)=9 minus target 1


def test_inbound_transfers_match_trimmed_upper_part_number():
    con = _con()
    con.execute("INSERT INTO parts VALUES ('1','MC','ab-1 ',0,0,10)")
    con.execute("INSERT INTO transfers VALUES ('1','AB-1',4), ('1 ','AB-1',2), ('5','AB-1',9)")
    assert _run(con)["ab-1 "]["InboundTransferQty"] == pytest.approx(6.0)


def test_compare_counts_mismatches():
    con = duckdb.connect()
    con.execute("""CREATE TABLE gold AS SELECT * FROM (VALUES ('1','MC','A',1,2,0,0.0,'Reorder'),
                   ('1','MC','B',1,2,0,0.0,'Reorder')) t(Branch,Franchise,PartNumber,MonthCount,
                   RecommendedOrderQty,SurplusQty,InboundTransferQty,Status)""")
    con.execute("""CREATE TABLE expected AS SELECT * FROM (VALUES ('1','MC','A',1,2,0,0.0,'Reorder'),
                   ('1','MC','C',1,2,0,0.0,'Reorder')) t(Branch,Franchise,PartNumber,MonthCount,
                   RecommendedOrderQty,SurplusQty,InboundTransferQty,Status)""")
    con.execute("ALTER TABLE gold ADD COLUMN StockingTarget INTEGER")
    con.execute("ALTER TABLE expected ADD COLUMN StockingTarget INTEGER")
    result = chk.compare(con, "gold", "expected")
    assert result == {"only_gold": 1, "only_expected": 1, "different": 0}
