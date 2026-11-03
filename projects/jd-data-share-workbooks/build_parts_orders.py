"""JD parts orders workbook (Ben): our stock and emergency orders to John Deere, by store and part: back orders,
open lines, JD ship times, emergency-order parts, substitutions, and the customer an emergency order was for.

Reads JD's data share and DP (Prod by default) via OneLake (DuckDB, `az login` credentials). See README.md.

Usage: python build_parts_orders.py [--tier prod|dev] [--since 2026-06-01] [--out FILE.xlsx]
"""
import argparse
from datetime import date

import jdshare as j

ap = argparse.ArgumentParser(description="JD parts orders by store, status and part.")
ap.add_argument("--tier", choices=j.DP, default="prod")
ap.add_argument("--since", default="2026-06-01",
                help="start of the summary period (JD's order history is only complete from June 2026)")
ap.add_argument("--out")
args = ap.parse_args()
P = j.DP[args.tier]
STAGING = {"prod": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"),
           "dev": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101")}[args.tier]

con = j.connect()
j.load_branch_map(con, args.tier)
loaded = con.execute(f"SELECT max(lake_ingestion_ts) FROM {j.share('parts_order')}").fetchone()[0]

# Status groups. JD's own status stays on every row; the group is for filtering and counting.
GROUP = """CASE
    WHEN order_status IN ('Completely Billed', 'Completely Delivered', '0912-D2D Line shipped') THEN 'Shipped'
    WHEN order_status = 'BKORD - Back order item' THEN 'Back order'
    WHEN order_status IN ('Cancelled', '0233I - cancelled by user', '0808I-Warehouse cancel Item', '0110I - obsolete product',
                          '0115I - prod. not effective', '0056A - Prod. not for service') THEN 'Cancelled / rejected'
    WHEN order_status IN ('Open', 'In Process', 'Under Fulfilment', 'Sent To Factory', 'Partially Billed', '0910-Dealer Accepted',
                          '0163A - price required', '3322I/3900I Listings Check') OR order_status LIKE '3899I%' THEN 'Open'
    ELSE 'Other (JD code)' END"""
store = "(SELECT DISTINCT kunnr, BranchID, Store FROM jd_acct WHERE BranchID IS NOT NULL)"
con.execute(f"""CREATE TABLE po AS
    SELECT p.*, {GROUP} status_group, s.BranchID, s.Store,
           timezone('America/Chicago', p.date_time_created_utc) created_local,
           timezone('America/Chicago', p.ship_date) shipped_local,
           date_diff('minute', p.date_time_created_utc, p.ship_date) / 1440.0 days_to_ship
    FROM {j.share('parts_order')} p LEFT JOIN {store} s ON s.kunnr = p.ship_to_party""")

# Part names (JD's English name, our description, Ben's commodity group) and company-wide on-hand from dim_Parts.
con.execute(f"""CREATE TABLE part AS
    WITH jdn AS (SELECT part_number, min(part_name) jd_name FROM {j.share('part_information')}
                 WHERE part_name_language = 'ENGLISH' GROUP BY 1),
         ours AS (SELECT trim(PartNumber) pn, max(Description) descr, sum(QuantityOnHand) on_hand,
                         max(upper(nullif(trim(CommodityCode), ''))) code
                  FROM {j.onelake(P, 'dim_Parts')} WHERE Franchise = 'D' GROUP BY 1),
         -- Ben's rule, as in Fact_CorpParts_JD: codes matched trimmed and upper-case; unmapped or blank = 'Other'.
         grp AS (SELECT upper(trim(CommodityCode)) code, max(CommodityGroup) grp
                 FROM {j.onelake(STAGING, 'CommodityCodeGroups')} WHERE trim(CommodityCode) <> '' GROUP BY 1)
    SELECT coalesce(o.pn, n.part_number) pn, n.jd_name, o.descr, o.on_hand, o.code, coalesce(nullif(g.grp, ''), 'Other') grp
    FROM ours o FULL JOIN jdn n ON n.part_number = o.pn LEFT JOIN grp g ON g.code = o.code""")

# Who placed the order: a JD user ID is a person at our store; JDPoint / JDPrism / SYSTEM are JD's automated ordering.
con.execute(f"""CREATE TABLE who AS
    SELECT user_id, trim(concat_ws(' ', initcap(trim(frst_nm)), initcap(trim(last_nm)))) person
    FROM {j.share('dealer_employee')}""")

# dealer_reference is not our invoice or sales order number: the numbers overlap with 2023 invoices by coincidence
# (checked 2026-11-03), so it is shown as JD reports it and not linked to a customer.

since = f"DATE '{args.since}'"
DETAIL = f"""
    SELECT p.Store, p.BranchID, p.order_type, p.order_number, p.created_local, p.ordered_part_number,
           coalesce(pt.descr, pt.jd_name), pt.grp, p.ordered_quantity, p.status_group, p.order_status,
           p.estimated_ship_date, p.shipped_local, p.days_to_ship,
           CASE WHEN p.status_group IN ('Open', 'Back order') THEN date_diff('day', p.created_local::DATE, current_date) END,
           nullif(p.shipped_part_number, p.ordered_part_number), p.service_level, p.ship_unit, p.dealer_reference,
           coalesce(w.person, p.submitted_by), pt.on_hand, p.delivery_number
    FROM po p LEFT JOIN part pt ON pt.pn = p.ordered_part_number LEFT JOIN who w ON w.user_id = p.submitted_by"""
DETAIL_COLS = [
    ("Store", 14, None), ("Branch", 7, None), ("Order Type", 13, None), ("JD Order #", 12, None),
    ("Ordered", 15, "date"), ("Part #", 12, None), ("Part Description", 30, None), ("Commodity Group", 16, None),
    ("Qty", 6, "int"), ("Status", 15, None), ("JD Status", 24, None), ("Est. Ship Date", 11, "date"),
    ("Shipped", 15, "date"), ("Days to Ship", 8, "num"), ("Days Waiting", 8, "int"), ("Shipped As (substitute)", 12, None),
    ("Service Level", 18, None), ("JD Depot", 7, None), ("Our Reference", 12, None),
    ("Ordered By", 18, None), ("Our On Hand (all stores)", 10, "num"),
    ("JD Delivery #", 12, None)]

open_rows = con.execute(DETAIL + " WHERE p.status_group IN ('Back order', 'Open') "
                        "ORDER BY p.status_group, p.order_type, p.created_local").fetchall()
all_rows = con.execute(DETAIL + " ORDER BY p.created_local DESC, p.order_number, p.ordered_part_number").fetchall()

by_store = con.execute(f"""
    SELECT coalesce(Store, 'Unknown'), BranchID, count(*),
           count(*) FILTER (WHERE order_type = 'Stock Order'), count(*) FILTER (WHERE order_type = 'Emergency Order'),
           count(*) FILTER (WHERE order_type = 'Emergency Order') / count(*),
           count(*) FILTER (WHERE status_group = 'Back order'), count(*) FILTER (WHERE status_group = 'Open'),
           count(*) FILTER (WHERE status_group = 'Cancelled / rejected'),
           median(days_to_ship) FILTER (WHERE order_type = 'Stock Order'),
           median(days_to_ship) FILTER (WHERE order_type = 'Emergency Order'),
           count(*) FILTER (WHERE order_type = 'Emergency Order' AND days_to_ship <= 1) /
               nullif(count(*) FILTER (WHERE order_type = 'Emergency Order' AND days_to_ship IS NOT NULL), 0)
    FROM po WHERE created_local::DATE >= {since}
    GROUP BY 1, 2 ORDER BY TRY_CAST(BranchID AS INT) NULLS LAST""").fetchall()

by_month = con.execute("""
    SELECT strftime(created_local, '%Y-%m'), count(*), count(*) FILTER (WHERE order_type = 'Stock Order'),
           count(*) FILTER (WHERE order_type = 'Emergency Order'),
           count(*) FILTER (WHERE order_type = 'Emergency Order') / count(*),
           median(days_to_ship) FILTER (WHERE order_type = 'Stock Order'),
           median(days_to_ship) FILTER (WHERE order_type = 'Emergency Order'),
           count(*) FILTER (WHERE status_group = 'Back order'), count(*) FILTER (WHERE status_group = 'Cancelled / rejected')
    FROM po GROUP BY 1 ORDER BY 1 DESC""").fetchall()

top_emerg = con.execute(f"""
    SELECT p.ordered_part_number, coalesce(any_value(pt.descr), any_value(pt.jd_name)), any_value(pt.grp), count(*),
           sum(p.ordered_quantity), count(DISTINCT p.BranchID), string_agg(DISTINCT p.Store, ', '),
           count(*) FILTER (WHERE p.status_group = 'Back order'), median(p.days_to_ship), any_value(pt.on_hand),
           count(*) FILTER (WHERE p.created_local::DATE >= current_date - 30)
    FROM po p LEFT JOIN part pt ON pt.pn = p.ordered_part_number
    WHERE p.order_type = 'Emergency Order' AND p.created_local::DATE >= {since}
    GROUP BY 1 ORDER BY 4 DESC, 5 DESC, 1""").fetchall()

subs = con.execute(DETAIL + " WHERE p.shipped_part_number <> p.ordered_part_number ORDER BY p.created_local DESC").fetchall()

wb = j.new_workbook()
sub = f"From John Deere's data share (parts_order, loaded {loaded:%m/%d/%Y}). Our side (descriptions, on hand, " \
      "commodity groups) comes from Equip."
period = f"Orders placed {date.fromisoformat(args.since):%m/%d/%Y} on (JD's order history is complete from June 2026)."
j.data_sheet(wb, "By Store", "JD Parts Orders by Store", f"{sub} {period} Counts are order lines.", [
    ("Store", 14, None), ("Branch", 7, None), ("Lines", 9, "int"), ("Stock Lines", 9, "int"), ("Emergency Lines", 10, "int"),
    ("Emergency %", 9, "pct"), ("Back Order Now", 9, "int"), ("Open Now", 9, "int"), ("Cancelled / Rejected", 10, "int"),
    ("Median Days to Ship - Stock", 11, "num"), ("Median Days to Ship - Emergency", 12, "num"),
    ("Emergency Shipped Within 1 Day", 12, "pct")], by_store)
j.data_sheet(wb, "Back Orders & Open", "Back-Ordered and Open Lines", sub + " Lines JD hasn't shipped, cancelled or "
             "rejected yet. Days Waiting counts from the order date.", DETAIL_COLS, open_rows, freeze_col=4)
j.data_sheet(wb, "Emergency Parts", "Most-Ordered Emergency Parts", f"{sub} {period} Parts that keep coming in on "
             "emergency orders are candidates to stock.", [
    ("Part #", 12, None), ("Part Description", 32, None), ("Commodity Group", 16, None), ("Emergency Lines", 10, "int"),
    ("Qty Ordered", 9, "num"), ("Stores", 7, "int"), ("Which Stores", 40, None), ("Back Ordered", 9, "int"),
    ("Median Days to Ship", 9, "num"), ("Our On Hand (all stores)", 10, "num"), ("Lines Last 30 Days", 9, "int")],
    top_emerg, freeze_col=2)
j.data_sheet(wb, "By Month", "JD Parts Orders by Month", sub + " Before June 2026 JD's history is incomplete "
             "(about 600 lines a month instead of 10-13k).", [
    ("Month", 9, None), ("Lines", 9, "int"), ("Stock Lines", 9, "int"), ("Emergency Lines", 10, "int"),
    ("Emergency %", 9, "pct"), ("Median Days to Ship - Stock", 11, "num"), ("Median Days to Ship - Emergency", 12, "num"),
    ("Back Order Now", 9, "int"), ("Cancelled / Rejected", 10, "int")], by_month)
j.data_sheet(wb, "Substitutions", "Lines Shipped as a Different Part", sub + " JD shipped a different part number "
             "than ordered (supersession or substitute).", DETAIL_COLS, subs, freeze_col=4)
j.data_sheet(wb, "Order Lines", "All JD Order Lines", sub + " Every line JD has, newest first.", DETAIL_COLS, all_rows,
             freeze_col=4)
j.notes_sheet(wb, "JD Parts Orders - Notes", [
    ("Prepared", f"{date.today():%m/%d/%Y} from John Deere's dealer data share (parts_order, loaded {loaded:%m/%d/%Y}) "
                 "and our Equip data in Fabric. A snapshot: JD replaces this data every day."),
    ("What this is", "Our parts orders to John Deere: stock orders and emergency orders, one row per order line as JD "
                     "reports it. A line can appear more than once when JD splits it across deliveries."),
    ("Coverage", "JD's history starts Aug 2024 but is only complete from June 2026 (about 600 lines a month before, "
                 "10-13k after). Summary tabs start at the period in their subtitle."),
    ("Status", "Grouped from JD's status: Shipped (completely billed / delivered), Back order, Open (open, in process, "
               "sent to factory, partially billed, held for review), Cancelled / rejected (cancelled, warehouse or "
               "user cancel, obsolete, not effective, not for service), Other (JD codes we haven't classified, e.g. "
               "'0809I-CRM M2NO'). JD's own status is in the JD Status column."),
    ("Days to Ship", "From the time the order was placed to JD's ship time, in days (0.5 = 12 hours). Times are Central."),
    ("Store", "From the order's ship-to account."),
    ("Our Reference", "The reference our system sent with the order, as JD reports it (likely Equip's order number). "
                      "It isn't linked to a customer yet."),
    ("Ordered By", "The JD user who placed the order (name from JD's employee list). 'JDPoint', 'JDPrism' and "
                   "'SYSTEM' are JD's automated ordering."),
    ("Commodity Group", "From the part's commodity code in Equip and Ben's CommodityCodeGroups list, the same rule as "
                        "Fact_CorpParts_JD: 'Other' when the code is blank or not on the list."),
    ("Our On Hand", "Company-wide quantity on hand in Equip (dim_Parts, franchise D) when the workbook was built."),
    ("JD Depot", "JD's shipping unit code (e.g. DY00)."),
    ("Questions", "Brian Fox. How the data works: fabric-workspace-docs/docs/JD-DATA-SHARE.md."),
])
j.save(wb, "JD_Parts_Orders", args.out, loaded.date())
print(f"lines={len(all_rows)} open/backorder={len(open_rows)} emergency parts={len(top_emerg)} substitutions={len(subs)}")
