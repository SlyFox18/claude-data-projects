"""PIP workbook (Casey): every PIP on every machine JD has assigned to our stores, with the store, our customer
and JD's owner, plus summaries by PIP and by store.

Reads JD's data share and DP_Presentation via OneLake (DuckDB, `az login` credentials). See README.md.

Usage: python build_pips.py [--tier prod|dev] [--out FILE.xlsx]
"""
import argparse
from datetime import date

import jdshare as j

ap = argparse.ArgumentParser(description="JD PIPs by machine, store and customer.")
ap.add_argument("--tier", choices=j.DP, default="prod")
ap.add_argument("--out")
args = ap.parse_args()

con = j.connect()
j.load_branch_map(con, args.tier)
j.load_machine_bridge(con, args.tier)
loaded = con.execute(f"SELECT max(lake_ingestion_ts) FROM {j.share('customer_pips')}").fetchone()[0]

# Rows repeat when JD re-titles a PIP; the titles are combined so there is one row per machine x PIP.
con.execute(f"""CREATE TABLE pip AS
    SELECT upper(trim(serial_no)) serial, pip_id, string_agg(DISTINCT trim(pip_title), ' / ') title,
           any_value(pip_status) pip_status, any_value(pip_type_desc) pip_type, any_value(pin_status) pin_status,
           any_value(credit_memo) credit_memo, any_value(paid_date) paid_date, min(nullif(entity_id, '0')) entity_id,
           any_value(res_dealer) res_dealer, any_value(rel_date) rel_date, any_value(expire_dt) expire_dt
    FROM {j.share('customer_pips')} GROUP BY 1, 2""")

PRIORITY = "CASE p.pip_type WHEN 'Safety PIP' THEN 1 WHEN 'Mandatory' THEN 2 WHEN 'Optional' THEN 3 " \
           "WHEN 'Product Enhancement Program' THEN 4 ELSE 5 END"
MACHINE_STATUS = ("CASE p.pin_status WHEN 'NOT_COMPLETE' THEN 'Not complete' WHEN 'COMPLETE' THEN 'Complete' "
                  "WHEN 'NOT_FAILED' THEN 'Not failed (fix as fail)' WHEN 'EXCLUDED' THEN 'Excluded' "
                  "ELSE initcap(p.pin_status) END")
rows = con.execute(f"""
    SELECT {PRIORITY}, p.pip_type, p.pip_id, p.title, p.pip_status, {MACHINE_STATUS}, p.rel_date, p.expire_dt,
           CASE WHEN p.pip_status = 'OPEN' THEN p.expire_dt - current_date END,
           p.serial, m.Model, a.Store, a.BranchID, p.res_dealer,
           o.AccountNumber, o.CustomerName, o.City, o.OtherAccounts, n.JdOwner, n.JdCity,
           s.StockNumber, s.StockStatus, p.credit_memo, p.paid_date
    FROM pip p LEFT JOIN jd_acct a ON a.acct_id = p.res_dealer LEFT JOIN model m ON m.k = p.serial
    LEFT JOIN owner o ON o.k = p.serial LEFT JOIN stock s ON s.k = p.serial
    LEFT JOIN jd_ent n ON n.entity_id = TRY_CAST(p.entity_id AS BIGINT)
    ORDER BY p.pip_status DESC, p.pin_status = 'NOT_COMPLETE' DESC, 1, p.expire_dt, a.Store, p.serial""").fetchall()

by_pip = con.execute(f"""
    SELECT p.pip_id, any_value(p.title), any_value(p.pip_type), any_value(p.pip_status), min(p.rel_date), max(p.expire_dt),
           count(*), count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE'), count(*) FILTER (WHERE p.pin_status = 'COMPLETE'),
           count(*) FILTER (WHERE p.pin_status = 'NOT_FAILED'),
           count(*) FILTER (WHERE p.pin_status NOT IN ('NOT_COMPLETE', 'COMPLETE', 'NOT_FAILED')),
           count(*) FILTER (WHERE p.pin_status = 'COMPLETE') /
               nullif(count(*) FILTER (WHERE p.pin_status IN ('COMPLETE', 'NOT_COMPLETE')), 0),
           count(*) FILTER (WHERE o.k IS NOT NULL)
    FROM pip p LEFT JOIN owner o ON o.k = p.serial
    GROUP BY 1 ORDER BY min({PRIORITY}), 8 DESC, 1""").fetchall()

by_store = con.execute(f"""
    SELECT coalesce(a.Store, 'Unknown (' || p.res_dealer || ')'), a.BranchID,
           count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE' AND p.pip_type = 'Safety PIP'),
           count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE' AND p.pip_type = 'Mandatory'),
           count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE' AND p.pip_type = 'Optional'),
           count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE' AND p.pip_type = 'Product Enhancement Program'),
           count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE' AND p.pip_type = 'Fix As Fail'),
           count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE'),
           count(*) FILTER (WHERE p.pin_status = 'NOT_FAILED'),
           count(*) FILTER (WHERE p.pin_status = 'COMPLETE'),
           count(*) FILTER (WHERE p.pin_status = 'COMPLETE' AND p.paid_date >= current_date - 365),
           count(*) FILTER (WHERE p.pin_status = 'NOT_COMPLETE' AND p.expire_dt < current_date + 90)
    FROM pip p LEFT JOIN jd_acct a ON a.acct_id = p.res_dealer
    GROUP BY 1, 2 ORDER BY TRY_CAST(a.BranchID AS INT) NULLS LAST""").fetchall()

wb = j.new_workbook()
sub = f"From John Deere's data share, loaded {loaded:%m/%d/%Y}. Our customer and stock # come from Equip."
j.data_sheet(wb, "By Store", "PIPs by Store", sub + " Counts are machines.", [
    ("Store", 16, None), ("Branch", 8, None), ("Safety - not complete", 11, "int"),
    ("Mandatory - not complete", 11, "int"), ("Optional - not complete", 11, "int"),
    ("Product Enh. - not complete", 11, "int"), ("Fix as Fail - not complete", 11, "int"),
    ("All not complete", 11, "int"), ("Fix as Fail - not failed yet", 12, "int"), ("Completed (all time)", 11, "int"),
    ("Completed (last 12 mo)", 11, "int"), ("Not complete, expires < 90 days", 13, "int")], by_store)
j.data_sheet(wb, "By PIP", "PIPs by Program", sub, [
    ("PIP ID", 11, None), ("Title", 60, None), ("Type", 16, None), ("PIP Status", 9, None), ("Released", 11, "date"),
    ("Expires", 11, "date"), ("Machines", 9, "int"), ("Not complete", 9, "int"), ("Complete", 9, "int"),
    ("Not failed (FaF)", 9, "int"), ("Excluded / won't respond", 11, "int"), ("% complete", 9, "pct"),
    ("Machines matched to our customer", 12, "int")], by_pip, freeze_col=2)
j.data_sheet(wb, "Machines", "PIPs by Machine", sub + " One row per machine x PIP; filter Machine Status = 'Not complete' "
             "for work still due.", [
    ("Priority", 8, "int"), ("PIP Type", 16, None), ("PIP ID", 11, None), ("PIP Title", 50, None), ("PIP Status", 9, None),
    ("Machine Status", 18, None), ("Released", 11, "date"), ("Expires", 11, "date"), ("Days to Expire", 9, "int"),
    ("Serial (PIN)", 20, None), ("Model", 16, None), ("Responsible Store", 15, None), ("Branch", 7, None),
    ("JD Account", 9, None), ("Our Account #", 10, None), ("Our Customer", 30, None), ("Customer City", 14, None),
    ("Earlier Accounts on Serial", 14, None), ("JD Registered Owner", 30, None), ("JD Owner City", 14, None),
    ("In Our Stock (Stock #)", 11, None), ("Stock Status", 8, None), ("Credit Memo", 12, None), ("Paid Date", 11, "date")],
    rows, freeze_col=4)
j.notes_sheet(wb, "PIPs - Notes", [
    ("Prepared", f"{date.today():%m/%d/%Y} from John Deere's dealer data share (table customer_pips, loaded "
                 f"{loaded:%m/%d/%Y}) and our Equip data in Fabric. A snapshot: JD replaces this data every day."),
    ("What a PIP is", "A Product Improvement Program: JD's campaign to repair or update a set of machines by serial. "
                      "JD pays for the work through a warranty credit memo."),
    ("PIP Type / Priority", "1 Safety PIP, 2 Mandatory, 3 Optional, 4 Product Enhancement Program, 5 Fix As Fail."),
    ("Machine Status", "Not complete = work is still due on that machine. Not failed (fix as fail) = nothing to do "
                       "unless the part fails. Complete = done (credit memo / paid date filled in). Excluded and "
                       "'Customer will not respond' as JD reports them."),
    ("Responsible Store", "The JD account JD holds responsible for the machine, shown as our store."),
    ("Our Customer", "Matched on the serial number (either PIN form) to Equip's registered vehicles. When a serial has "
                     "several accounts (earlier owners), the most recently updated one is shown and the others are "
                     "listed under 'Earlier Accounts on Serial'. Blank = we have no record of the machine."),
    ("JD Registered Owner", "The owner JD has on file. Useful when we have no match, or to spot an ownership change."),
    ("In Our Stock", "Our stock number when the machine is one of our unsold stock units (Equip stock with no sale "
                     "date). A PIP that isn't complete on a stock unit should be done before the unit is sold."),
    ("Questions", "Brian Fox. How the data works: fabric-workspace-docs/docs/JD-DATA-SHARE.md."),
])
j.save(wb, "JD_PIPs", args.out, loaded.date())
print(f"machines x PIPs={len(rows)} PIPs={len(by_pip)} stores={len(by_store)}")
