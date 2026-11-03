"""Sales workbook (Kurt): JD market share by county and machine, competitors' equipment from UCC lien filings,
JD's scored purchase leads, deere.com quote / contact requests, and Deere retail sales by county.

Reads JD's data share and DP_Presentation via OneLake (DuckDB, `az login` credentials). See README.md.

Usage: python build_sales.py [--tier prod|dev] [--ucc-years 3] [--out FILE.xlsx]
"""
import argparse
from datetime import date

import jdshare as j

ap = argparse.ArgumentParser(description="JD market share, competitive equipment and leads.")
ap.add_argument("--tier", choices=j.DP, default="prod")
ap.add_argument("--ucc-years", type=int, default=3, help="UCC filings from the last N years (default 3)")
ap.add_argument("--out")
args = ap.parse_args()

con = j.connect()
j.load_branch_map(con, args.tier)
j.load_machine_bridge(con, args.tier)
loaded = con.execute(f"SELECT max(lake_ingestion_ts) FROM {j.share('dealer_market_share_county')}").fetchone()[0]
SEGMENT = "CASE product_type WHEN 'AG' THEN 'Ag & Turf' WHEN 'C&F' THEN 'Construction & Forestry' ELSE product_type END"

# ---------------------------------------------------------------- market share (last 12 months JD provides)
ms = j.share('dealer_market_share_county')
share_by_machine = con.execute(f"""
    SELECT {SEGMENT}, actv_nm, machine, sum(indtry_sales), sum(dlr_units), sum(oth_dlr_units),
           sum(dlr_units) / nullif(sum(indtry_sales), 0), count(DISTINCT county), min(actv_mo), max(actv_mo)
    FROM {ms} GROUP BY 1, 2, 3 ORDER BY 1, 2, 4 DESC""").fetchall()
share_by_county = con.execute(f"""
    SELECT trim(split_part(county, ',', 1)), trim(split_part(county, ',', 2)), {SEGMENT}, actv_nm, max(in_aor),
           sum(indtry_sales), sum(dlr_units), sum(oth_dlr_units), sum(dlr_units) / nullif(sum(indtry_sales), 0),
           sum(indtry_sales) - sum(dlr_units) - sum(oth_dlr_units)
    FROM {ms} GROUP BY 1, 2, 3, 4 ORDER BY 3, 4, 6 DESC""").fetchall()
share_detail = con.execute(f"""
    SELECT actv_mo, {SEGMENT}, actv_nm, machine, nullif(models, ''), size_lbl, trim(split_part(county, ',', 1)),
           trim(split_part(county, ',', 2)), in_aor, mkt_seg_nm, indtry_sales, dlr_units, oth_dlr_units,
           TRY_CAST(deere_direct_units AS DOUBLE), avg_us_dol_val
    FROM {ms} ORDER BY 1 DESC, 2, 3, 4, 7, 8""").fetchall()

# ---------------------------------------------------------------- UCC lien filings
ucc = j.share('dealer_ucc')
since = f"current_date - INTERVAL {args.ucc_years} YEAR"
BRANDS = ["KUBOTA", "CAT", "BOBCAT", "CASE", "MASSEY", "NEW-HOLLAND", "KIOTI", "MAHINDRA"]
brand_cols = ", ".join(f"count(*) FILTER (WHERE manufacture_name = '{b}')" for b in BRANDS)
ucc_by_county = con.execute(f"""
    SELECT initcap(county_name), state, count(*), count(*) FILTER (WHERE manufacture_name = 'DEERE'),
           count(*) FILTER (WHERE manufacture_name = 'DEERE') / count(*), {brand_cols},
           count(*) FILTER (WHERE manufacture_name NOT IN ('DEERE', {", ".join(f"'{b}'" for b in BRANDS)}))
    FROM {ucc} WHERE filing_date >= {since} AND activity_type IN ('SALE', 'LEASE')
    GROUP BY 1, 2 ORDER BY 3 DESC""").fetchall()
ucc_by_equipment = con.execute(f"""
    SELECT equip_description, count(*), count(*) FILTER (WHERE manufacture_name = 'DEERE'),
           count(*) FILTER (WHERE manufacture_name = 'DEERE') / count(*),
           (SELECT string_agg(m || ' ' || n, ', ' ORDER BY n DESC) FROM (
               SELECT manufacture_name m, count(*) n FROM {ucc} u2 WHERE u2.equip_description = u.equip_description
                 AND u2.filing_date >= {since} AND u2.activity_type IN ('SALE', 'LEASE') AND u2.manufacture_name <> 'DEERE'
               GROUP BY 1 ORDER BY 2 DESC LIMIT 4))
    FROM {ucc} u WHERE filing_date >= {since} AND activity_type IN ('SALE', 'LEASE')
    GROUP BY 1 ORDER BY 2 DESC""").fetchall()
competitive = con.execute(f"""
    SELECT u.filing_date, u.manufacture_name, u.equip_description, u.model, coalesce(u.manufacture_year, u.estimate_mnfr_year),
           CASE u.new_used_ind WHEN 'N' THEN 'New' WHEN 'U' THEN 'Used' END, TRY_CAST(nullif(u.equipment_value, '0') AS DOUBLE),
           u.activity_type, coalesce(nullif(trim(u.company_name), ''),
                                     trim(concat_ws(' ', initcap(u.contact_first_name), initcap(u.contact_last_name)))),
           initcap(u.city), u.state, initcap(u.county_name), u.sic_description, u.lien_holder_name, u.lien_class_descr,
           u.serial_number, o.AccountNumber, o.CustomerName, u.buyer_last_activity
    FROM {ucc} u LEFT JOIN owner o ON o.k = upper(trim(u.serial_number))
    WHERE u.filing_date >= {since} AND u.manufacture_name <> 'DEERE'
    ORDER BY u.filing_date DESC, u.manufacture_name, u.county_name""").fetchall()

# ---------------------------------------------------------------- JD scored leads (Customer Lead Generator)
clg = j.share('leads_customer_lead_generator')
leads = con.execute(f"""
    SELECT CASE l.purchs_prbly_ctgry WHEN 'Very_High' THEN 'Very high' ELSE l.purchs_prbly_ctgry END, l.purchs_prbly,
           l.prob_qrtr_1, l.prob_qrtr_2, l.prob_qrtr_3, l.prob_qrtr_4, l.cmptv_product_category, l.lvl2_prod_typ,
           l.product_type, n.JdOwner, n.JdCity, n.JdState, o.AccountNumber, o.CustomerName,
           CASE l.fleet_brnd_prfnc WHEN 'DEERE' THEN 'Deere' WHEN 'COMPETITIVE' THEN 'Competitive' ELSE 'Mixed' END,
           l.jd_pctg_category, l.used_pctg_category, l.last_purchs_dt, l.model_num_rec, nullif(l.last_price, 0),
           l.ntv_pin, l.top_five_model_rec, l.prob_finance, l.prob_finance_deere,
           CASE WHEN l.prcsn_upgrd = 'Y' THEN 'Yes' END, l.scored_date_by_cog_buyer_prbly_to_purch,
           CASE l.cog_acct_id WHEN '054386' THEN 'CWP' ELSE 'Ag & Turf' END, l.entity_id
    FROM {clg} l LEFT JOIN jd_name n ON n.entity_id = l.entity_id AND n.contact_id = l.contact_id
    LEFT JOIN owner o ON o.k = upper(trim(l.ntv_pin))
    ORDER BY l.purchs_prbly DESC, l.entity_id, l.cmptv_product_category""").fetchall()
leads_summary = con.execute(f"""
    SELECT cmptv_product_category, CASE cog_acct_id WHEN '054386' THEN 'CWP' ELSE 'Ag & Turf' END, count(*),
           count(*) FILTER (WHERE purchs_prbly_ctgry = 'Very_High'), count(*) FILTER (WHERE purchs_prbly_ctgry = 'High'),
           count(*) FILTER (WHERE purchs_prbly_ctgry = 'Medium'),
           count(*) FILTER (WHERE fleet_brnd_prfnc = 'COMPETITIVE' AND purchs_prbly_ctgry IN ('High', 'Very_High')),
           avg(purchs_prbly)
    FROM {clg} GROUP BY 1, 2 ORDER BY 4 + 5 DESC, 3 DESC""").fetchall()

# ---------------------------------------------------------------- deere.com requests (they asked to be contacted)
web = con.execute(f"""
    WITH w AS (
      SELECT timezone('America/Chicago', date_submitted) submitted, 'Build Your Own quote' kind, qdata_product_name interest,
             trim(concat_ws(' ', initcap(first_name), initcap(last_name))) who, lower(email) email, phone,
             initcap(city) city, state, qdata_dealer_location_id loc, nullif(qdata_time, '') best_time,
             nullif(qdata_trade_in, '') trade_in, nullif(qdata_financing, '') financing, nullif(qdata_comments_value, '') cmt,
             qdata_saved_quote_url quote_url
      FROM {j.share('leads_customer_build_your_own')}
      UNION ALL
      SELECT timezone('America/Chicago', date_submitted), 'Dealer locator: contact me',
             concat_ws(' / ', nullif(qdata_industry_name, ''), nullif(qdata_help_me_with_sales, ''),
                       nullif(qdata_help_me_with_services, ''), nullif(qdata_help_me_with_parts, '')),
             qdata_name, lower(email), nullif(qdata_phone_value, ''), NULL, NULL, qdata_dealer_location_id, NULL, NULL, NULL,
             nullif(qdata_additional_comments, ''), NULL
      FROM {j.share('leads_global_dealer_locator')})
    SELECT w.submitted, w.kind, w.interest, a.Store, w.who, w.email, w.phone, w.city, w.state, w.best_time, w.trade_in,
           w.financing, w.cmt, w.quote_url
    FROM w LEFT JOIN jd_acct a ON a.acct_id = regexp_replace(w.loc, '^L', '')
    ORDER BY w.submitted DESC""").fetchall()

# ---------------------------------------------------------------- Deere retail sales in our area
rs = j.share('dealer_market_share_sales')
years = [r[0] for r in con.execute(f"SELECT DISTINCT year(retail_sold_date) y FROM {rs} ORDER BY y DESC LIMIT 5").fetchall()]
year_cols = ", ".join(f"count(*) FILTER (WHERE year(retail_sold_date) = {y})" for y in years)
retail_by_county = con.execute(f"""
    SELECT initcap(market_share_county_name), market_share_state,
           CASE mktg_area_id WHEN '054386' THEN 'CWP' ELSE 'Ag & Turf' END, {year_cols}, count(*)
    FROM {rs} GROUP BY 1, 2, 3 ORDER BY {len(years) + 4} DESC""").fetchall()

wb = j.new_workbook()
sub = f"From John Deere's data share, loaded {loaded:%m/%d/%Y}."
j.data_sheet(wb, "Share by Machine", "Market Share by Machine", sub + " Last 12 months JD provides; units. "
             "Ag & Turf is settlements, Construction & Forestry is new retails.", [
    ("Segment", 20, None), ("Activity", 16, None), ("Machine", 34, None), ("Industry Units", 10, "num"),
    ("Our Units", 9, "num"), ("Other Deere Dealer Units", 11, "num"), ("Our Share", 9, "pct"), ("Counties", 8, "int"),
    ("From", 11, "date"), ("To", 11, "date")], share_by_machine, freeze_col=3)
j.data_sheet(wb, "Share by County", "Market Share by County", sub + " Last 12 months; units. Competitor Units = "
             "industry minus all Deere dealers.", [
    ("State", 6, None), ("County", 16, None), ("Segment", 20, None), ("Activity", 16, None), ("In Our Area", 8, None),
    ("Industry Units", 10, "num"), ("Our Units", 9, "num"), ("Other Deere Dealer Units", 11, "num"),
    ("Our Share", 9, "pct"), ("Competitor Units", 10, "num")], share_by_county, freeze_col=2)
j.data_sheet(wb, "Share Detail", "Market Share Detail", sub + " One row per month x machine x size x county x "
             "market segment, as JD reports it.", [
    ("Month", 11, "date"), ("Segment", 20, None), ("Activity", 16, None), ("Machine", 30, None), ("Models", 18, None),
    ("Size", 14, None), ("State", 6, None), ("County", 14, None), ("In Our Area", 8, None), ("Market Segment", 26, None),
    ("Industry Units", 9, "num"), ("Our Units", 8, "num"), ("Other Deere Dealer Units", 10, "num"),
    ("Deere Direct Units", 9, "num"), ("Avg Unit Value ($)", 11, "money")], share_detail, freeze_col=4)
ucc_sub = f"{sub} UCC-1 lien filings in TX and NM (financed equipment, any brand), last {args.ucc_years} years."
j.data_sheet(wb, "Competition by County", "Financed Equipment by County and Brand", ucc_sub + " Sales and leases; "
             "counts are filings.", [
    ("County", 16, None), ("State", 6, None), ("Filings", 9, "int"), ("Deere", 8, "int"), ("Deere %", 8, "pct")] +
    [(b.title(), 9, "int") for b in BRANDS] + [("All Other Brands", 9, "int")], ucc_by_county, freeze_col=2)
j.data_sheet(wb, "Competition by Type", "Financed Equipment by Type", ucc_sub + " Sales and leases.", [
    ("Equipment Type", 28, None), ("Filings", 9, "int"), ("Deere", 8, "int"), ("Deere %", 8, "pct"),
    ("Top Competitors (filings)", 60, None)], ucc_by_equipment, freeze_col=1)
j.data_sheet(wb, "Competitive Equipment", "Competitors' Equipment in Our Area", ucc_sub + " Non-Deere filings only, "
             "newest first. Our Customer = the serial is in our records.", [
    ("Filing Date", 11, "date"), ("Brand", 14, None), ("Equipment Type", 22, None), ("Model", 14, None),
    ("Year", 6, None), ("New / Used", 7, None), ("Value ($)", 10, "money"), ("Activity", 9, None), ("Buyer", 30, None),
    ("City", 14, None), ("State", 5, None), ("County", 13, None), ("Buyer Industry (SIC)", 26, None),
    ("Lender", 26, None), ("Lender Type", 18, None), ("Serial", 18, None), ("Our Account #", 10, None),
    ("Our Customer", 28, None), ("Buyer Last Activity", 11, "date")], competitive, freeze_col=3)
j.data_sheet(wb, "Lead Summary", "JD Scored Leads by Product", sub + " JD's Customer Lead Generator: likelihood a "
             "customer buys in a product category.", [
    ("Product Category", 30, None), ("Group", 10, None), ("Leads", 9, "int"), ("Very High", 9, "int"), ("High", 9, "int"),
    ("Medium", 9, "int"), ("High+ With Competitive Fleet", 12, "int"), ("Avg Probability", 9, "pct")],
    leads_summary, freeze_col=1)
j.data_sheet(wb, "Scored Leads", "JD Scored Leads", sub + " One row per customer x product category, highest "
             "probability first. Filter Likelihood = Very high / High to start.", [
    ("Likelihood", 10, None), ("Purchase Probability", 10, "pct"), ("Prob. Q1", 8, "pct"), ("Prob. Q2", 8, "pct"),
    ("Prob. Q3", 8, "pct"), ("Prob. Q4", 8, "pct"), ("Product Category", 28, None), ("Product Type", 18, None),
    ("JD Segment", 10, None), ("Customer (JD)", 30, None), ("City", 14, None), ("State", 5, None),
    ("Our Account #", 10, None), ("Our Customer", 28, None), ("Fleet", 11, None), ("Deere Share of Fleet", 9, "pct"),
    ("Used Share of Fleet", 9, "pct"), ("Last Purchase", 11, "date"), ("Last Model", 12, None),
    ("Last Price ($)", 11, "money"), ("Last Machine Serial", 18, None), ("JD's Top 5 Models", 36, None),
    ("Prob. to Finance", 9, "pct"), ("Prob. to Finance with Deere", 10, "pct"), ("Precision Upgrade", 8, None),
    ("Scored On", 11, "date"), ("Group", 10, None), ("JD Entity ID", 11, None)], leads, freeze_col=1)
j.data_sheet(wb, "Web Requests", "Quote and Contact Requests from deere.com", sub + " People who asked a store to "
             "contact them (Build Your Own quotes and Dealer Locator).", [
    ("Submitted", 15, "date"), ("Request", 22, None), ("Interested In", 34, None), ("Store", 13, None), ("Name", 22, None),
    ("Email", 28, None), ("Phone", 13, None), ("City", 13, None), ("State", 9, None), ("Best Time", 14, None),
    ("Trade-In", 8, None), ("Financing", 8, None), ("Comments", 40, None), ("Saved Quote Link", 40, None)], web)
j.data_sheet(wb, "Retail by County", "Deere Retail Sales by County", sub + " Retail sales JD records in our "
             "marketing areas, by sold year. Counts are units.", [
    ("County", 16, None), ("State", 6, None), ("Group", 10, None)] + [(str(y), 8, "int") for y in years] +
    [("All Years (since 2016)", 10, "int")], retail_by_county, freeze_col=2)
j.notes_sheet(wb, "Sales - Notes", [
    ("Prepared", f"{date.today():%m/%d/%Y} from John Deere's dealer data share (loaded {loaded:%m/%d/%Y}) and our "
                 "Equip data in Fabric. A snapshot: JD replaces this data every day."),
    ("Market share", "JD's county market share for the last 12 months JD provides. Ag & Turf is reported as "
                     "settlements, Construction & Forestry as new retails (and rental conversions). Industry Units = "
                     "all brands; Our Units = our stores; Other Deere Dealer Units = other Deere dealers selling into "
                     "the county. Our Share = Our Units / Industry Units. In Our Area = JD's area of responsibility. "
                     "Units can be fractional where JD splits a sale."),
    ("UCC filings", f"UCC-1 lien filings (equipment financed or leased) in TX and NM, any brand, last {args.ucc_years} "
                    "years. They show what competitors are selling and who is buying. A filing is one financed piece "
                    "of equipment; cash purchases don't appear. Our Customer = the serial number is in our records."),
    ("Scored leads", "JD's Customer Lead Generator: for each customer and product category, JD's probability they "
                     "buy (overall and by quarter), whether their fleet is Deere or competitive, their last purchase "
                     "and JD's recommended models. Customer (JD) is JD's name for them. Our Customer is matched "
                     "through the serial of their last machine. Group: Ag & Turf or CWP."),
    ("Web requests", "Requests submitted on deere.com (Build Your Own quote, Dealer Locator 'contact me') for one of "
                     "our stores. Contact details are included because the customer asked to be contacted."),
    ("Retail by County", "Deere retail sales JD records in our two marketing areas (Ag & Turf, CWP), by county and "
                         "year. JD's description is 'dealer market share sales'; whether it includes other Deere "
                         "dealers' sales into our area is still to confirm with JD."),
    ("Personal data", "Buyer and customer names are included for follow-up. Keep this workbook internal."),
    ("Questions", "Brian Fox. How the data works: fabric-workspace-docs/docs/JD-DATA-SHARE.md."),
])
j.save(wb, "JD_Sales_Market", args.out, loaded.date())
print(f"share rows={len(share_detail)} counties={len(share_by_county)} ucc competitive={len(competitive)} "
      f"leads={len(leads)} (our customer {sum(1 for r in leads if r[13])}) web={len(web)} retail counties={len(retail_by_county)}")
