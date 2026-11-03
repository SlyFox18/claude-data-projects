"""Service opportunities workbook (Casey): JD's open recommendations per machine (inspections, extended warranty
offers, performance upgrade kits, parts, connectivity) and factory warranty coverage ending soon, with the store,
our customer and JD's owner.

Reads JD's data share and DP_Presentation via OneLake (DuckDB, `az login` credentials). See README.md.

Usage: python build_service_opps.py [--tier prod|dev] [--days 180] [--out FILE.xlsx]
"""
import argparse
import json
from datetime import date

import jdshare as j

ap = argparse.ArgumentParser(description="JD service opportunities and expiring warranty by machine and customer.")
ap.add_argument("--tier", choices=j.DP, default="prod")
ap.add_argument("--days", type=int, default=180, help="warranty ending within this many days (default 180)")
ap.add_argument("--out")
args = ap.parse_args()

TYPE = {"INSPECTION": "Inspection", "WARRANTY": "Extended warranty offer", "PUK": "Performance upgrade kit",
        "PARTS": "Parts", "CONNECTED_MACHINE": "Connectivity upgrade"}


def detail(text):
    """JD's recommendation_dsc is JSON for inspections and warranty offers and plain text otherwise."""
    if not text:
        return None
    try:
        d = json.loads(text)
    except ValueError:
        return text.strip()[:300]
    if not isinstance(d, dict):
        return str(d)[:300]
    if "description" in d:
        return str(d["description"])
    parts = []
    if d.get("eligible_warranty"):
        parts.append(f"{d['eligible_warranty']} warranty")
    if d.get("expected_expiration_date"):
        parts.append(f"current coverage expected to end {d['expected_expiration_date']}")
    if d.get("forecasted_hours"):
        parts.append(f"forecast {float(d['forecasted_hours']):,.0f} hrs")
    if d.get("fluid_test_required") == "true":
        parts.append("fluid test required")
    if d.get("recommended_modem"):
        parts.append(f"recommended modem {d['recommended_modem']}")
    return "; ".join(parts) or text[:300]


con = j.connect()
con.create_function("rec_detail", detail, ["VARCHAR"], "VARCHAR")
j.load_branch_map(con, args.tier)
j.load_machine_bridge(con, args.tier)
loaded = con.execute(f"SELECT max(lake_ingestion_ts) FROM {j.share('warranty_recommendations')}").fetchone()[0]

# A machine with several registered owners repeats per owner; one row per machine x program x recommendation.
con.execute(f"""CREATE TABLE rec AS
    SELECT upper(trim(r.ntv_pin)) serial, r.recommendation_type, r.program_id, r.recommendation_name,
           any_value(rec_detail(r.recommendation_dsc)) detail, any_value(r.acct_id) acct_id,
           string_agg(DISTINCT n.JdOwner, '; ') JdOwner
    FROM {j.share('warranty_recommendations')} r
    LEFT JOIN jd_name n ON n.entity_id = r.ent_id AND n.contact_id = r.cmp_ent_id
    WHERE r.upgraded = 0 GROUP BY 1, 2, 3, 4""")
TYPE_SQL = "CASE r.recommendation_type " + " ".join(f"WHEN '{k}' THEN '{v}'" for k, v in TYPE.items()) + \
           " ELSE r.recommendation_type END"
recs = con.execute(f"""
    SELECT {TYPE_SQL}, r.program_id, r.recommendation_name, r.detail, r.serial, m.Model, a.Store, a.BranchID,
           o.AccountNumber, o.CustomerName, o.City, o.OtherAccounts, r.JdOwner, s.StockNumber
    FROM rec r LEFT JOIN jd_acct a ON a.acct_id = r.acct_id LEFT JOIN model m ON m.k = r.serial
    LEFT JOIN owner o ON o.k = r.serial LEFT JOIN stock s ON s.k = r.serial
    ORDER BY r.recommendation_type, TRY_CAST(a.BranchID AS INT), o.CustomerName NULLS LAST, r.serial""").fetchall()

by_program = con.execute(f"""
    SELECT {TYPE_SQL}, r.program_id, r.recommendation_name, count(*), count(*) FILTER (WHERE o.k IS NOT NULL),
           mode(r.detail)
    FROM rec r LEFT JOIN owner o ON o.k = r.serial GROUP BY 1, 2, 3 ORDER BY 1, 4 DESC""").fetchall()

con.execute(f"""CREATE TABLE wty AS
    SELECT upper(trim(w.ntv_pin)) serial, w.product_warranties_wrnty_end_dt ends, w.product_warranties_wrnty_start_dt starts,
           w.product_warranties_mstr_wrnty_typ_nm cov_type, w.product_warranties_mstr_wrnty_dsc cov_desc,
           w.product_warranties_wrnty_mo cov_months, w.product_warranties_wrnty_hours cov_hours,
           CASE w.new_used_ind WHEN 'N' THEN 'New' WHEN 'U' THEN 'Used' END new_used, w.serv_dlr_num, w.sold_by_dlr_num,
           w.end_use_of_prod_nm end_use, {j.jd_date('w.dlvr_rcpt_dt')} delivered, n.JdOwner, n.JdCity
    FROM {j.share('customer_warranty')} w
    LEFT JOIN jd_name n ON n.entity_id = w.ent_id AND n.contact_id = w.cmp_ent_id
    WHERE w.product_warranties_wrnty_end_dt BETWEEN current_date AND current_date + {args.days}""")
wty = con.execute("""
    SELECT w.ends, w.ends - current_date, nullif(w.cov_type, ''), w.cov_desc, w.cov_months, nullif(w.cov_hours, 0), w.starts,
           w.serial, m.Model, w.new_used, w.delivered, coalesce(sv.Store, 'Other dealer ' || w.serv_dlr_num), sv.BranchID,
           coalesce(sd.Store, nullif('Other dealer ' || w.sold_by_dlr_num, 'Other dealer ')),
           o.AccountNumber, o.CustomerName, o.City, o.OtherAccounts, w.JdOwner, w.JdCity, w.end_use, s.StockNumber
    FROM wty w LEFT JOIN jd_acct sv ON sv.acct_id = w.serv_dlr_num LEFT JOIN jd_acct sd ON sd.acct_id = w.sold_by_dlr_num
    LEFT JOIN model m ON m.k = w.serial LEFT JOIN owner o ON o.k = w.serial LEFT JOIN stock s ON s.k = w.serial
    ORDER BY w.ends, TRY_CAST(sv.BranchID AS INT), w.serial""").fetchall()

by_store = con.execute(f"""
    WITH r AS (SELECT a.Store, a.BranchID, r.recommendation_type t, r.serial FROM rec r LEFT JOIN jd_acct a ON a.acct_id = r.acct_id),
         w AS (SELECT a.Store, a.BranchID, w.serial FROM wty w LEFT JOIN jd_acct a ON a.acct_id = w.serv_dlr_num),
         stores AS (SELECT Store, BranchID FROM r UNION SELECT Store, BranchID FROM w)
    SELECT coalesce(s.Store, 'Other / unknown'), s.BranchID,
           (SELECT count(DISTINCT serial) FROM r WHERE r.Store IS NOT DISTINCT FROM s.Store AND t = 'INSPECTION'),
           (SELECT count(DISTINCT serial) FROM r WHERE r.Store IS NOT DISTINCT FROM s.Store AND t = 'WARRANTY'),
           (SELECT count(DISTINCT serial) FROM r WHERE r.Store IS NOT DISTINCT FROM s.Store AND t = 'PUK'),
           (SELECT count(DISTINCT serial) FROM r WHERE r.Store IS NOT DISTINCT FROM s.Store AND t IN ('PARTS', 'CONNECTED_MACHINE')),
           (SELECT count(DISTINCT serial) FROM w WHERE w.Store IS NOT DISTINCT FROM s.Store)
    FROM stores s ORDER BY TRY_CAST(s.BranchID AS INT) NULLS LAST""").fetchall()

wb = j.new_workbook()
sub = f"From John Deere's data share, loaded {loaded:%m/%d/%Y}. Our customer and stock # come from Equip."
j.data_sheet(wb, "By Store", "Service Opportunities by Store", sub + " Counts are machines.", [
    ("Store", 16, None), ("Branch", 8, None), ("Inspection", 11, "int"), ("Extended Warranty Offer", 11, "int"),
    ("Performance Upgrade Kit", 11, "int"), ("Parts / Connectivity", 11, "int"),
    (f"Factory Warranty Ending ({args.days} days)", 13, "int")], by_store)
j.data_sheet(wb, "By Program", "Open Recommendations by Program", sub, [
    ("Type", 22, None), ("Program", 24, None), ("Recommendation", 40, None), ("Machines", 9, "int"),
    ("Matched to Our Customer", 11, "int"), ("Typical Detail", 70, None)], by_program, freeze_col=3)
j.data_sheet(wb, "Recommendations", "Open Recommendations by Machine", sub + " Only recommendations JD shows as not "
             "yet done. One row per machine x recommendation.", [
    ("Type", 22, None), ("Program", 22, None), ("Recommendation", 34, None), ("Detail", 50, None),
    ("Serial (PIN)", 20, None), ("Model", 16, None), ("Store", 14, None), ("Branch", 7, None), ("Our Account #", 10, None),
    ("Our Customer", 30, None), ("Customer City", 14, None), ("Earlier Accounts on Serial", 14, None),
    ("JD Registered Owner", 30, None), ("In Our Stock (Stock #)", 11, None)], recs, freeze_col=3)
j.data_sheet(wb, "Warranty Ending", f"Factory Warranty Ending in the Next {args.days} Days", sub + " One row per "
             "machine x warranty coverage.", [
    ("Coverage Ends", 11, "date"), ("Days Left", 8, "int"), ("Coverage Type", 24, None), ("Coverage", 26, None),
    ("Months", 7, "int"), ("Hours Limit", 8, "int"), ("Coverage Start", 11, "date"), ("Serial (PIN)", 20, None),
    ("Model", 16, None), ("New / Used", 8, None), ("Delivered", 11, "date"), ("Servicing Store", 15, None),
    ("Branch", 7, None), ("Selling Store", 15, None), ("Our Account #", 10, None), ("Our Customer", 30, None),
    ("Customer City", 14, None), ("Earlier Accounts on Serial", 14, None), ("JD Registered Owner", 30, None),
    ("JD Owner City", 14, None), ("End Use", 20, None), ("In Our Stock (Stock #)", 11, None)], wty, freeze_col=2)
j.notes_sheet(wb, "Service Opportunities - Notes", [
    ("Prepared", f"{date.today():%m/%d/%Y} from John Deere's dealer data share (warranty_recommendations and "
                 f"customer_warranty, loaded {loaded:%m/%d/%Y}). A snapshot: JD replaces this data every day."),
    ("Recommendations", "JD's suggested work per machine that JD shows as not yet done (upgraded = 0). "
                        "Inspection: JD inspection programs such as Fill the Shop, BBADF, ReLife and JDProtect. "
                        "Extended warranty offer: the machine is eligible for an extended / PowerGard plan. "
                        "Performance upgrade kit: precision upgrades the machine doesn't have yet (listed in Detail). "
                        "Parts: Combine Advisor. Connectivity: modem upgrade."),
    ("Detail", "JD's own description, put into words. For warranty offers it shows when current coverage is expected "
               "to end and JD's forecast hours. 'Ineligible, serviced at other dealer' means JD sees the machine being "
               "serviced elsewhere."),
    ("Store", "The JD account the recommendation is assigned to, shown as our store."),
    ("Warranty Ending", f"Factory warranty coverage (basic, emissions, extended, ...) with an end date in the next "
                        f"{args.days} days. A machine can have several coverages, one row each. Servicing / Selling "
                        "Store: our store, or 'Other dealer <JD account>'."),
    ("Our Customer", "Matched on the serial number (either PIN form) to Equip's registered vehicles. When a serial has "
                     "several accounts (earlier owners), the most recently updated one is shown and the others are "
                     "listed under 'Earlier Accounts on Serial'. Blank = we have no record of the machine."),
    ("JD Registered Owner", "The owner JD has on file (all of them, when JD lists more than one)."),
    ("In Our Stock", "Our stock number when the machine is one of our unsold stock units."),
    ("Questions", "Brian Fox. How the data works: fabric-workspace-docs/docs/JD-DATA-SHARE.md."),
])
j.save(wb, "JD_Service_Opportunities", args.out, loaded.date())
print(f"recommendations={len(recs)} programs={len(by_program)} warranty_ending={len(wty)} stores={len(by_store)}")
