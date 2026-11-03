# JD Data Share Workbooks

On-demand Excel workbooks built from **John Deere's dealer data share** (`JD_Dealer_DataExchange` / `Data_Sharing`), so the department managers can explore the data before we decide which reports to build. First built 2026-11-03.

- **What the share is**, its tables, keys and quirks: `fabric-workspace-docs/docs/JD-DATA-SHARE.md`.
- **Who gets what:**
  - Casey (Aftermarket Sales & Service: training, inspections, warranty, PIPs) gets these three workbooks;
  - Ben (Corporate Parts) gets anything from `parts_order`;
  - Kurt (Corporate Sales) gets market share, UCC and leads.

## Run it

```
cd projects/jd-data-share-workbooks
az login                        # if not already signed in; DuckDB reads OneLake with your az credentials
python build_pips.py            # output/JD_PIPs_<load date>.xlsx
python build_training.py        # output/JD_University_Training_<load date>.xlsx
python build_service_opps.py    # output/JD_Service_Opportunities_<load date>.xlsx  (--days 180 = warranty window)
```

- **Options and timing:** `--tier dev` reads DP - Presentation - Dev for our side of the matching; `--out <file.xlsx>` picks the output path. Each script takes 2–3 minutes.
- **Keep the output private.** `output/` is git-ignored: the workbooks hold customer and employee names. Share them through a restricted SharePoint/OneDrive link, not email attachments.
- **Each file is a snapshot.** JD overwrites the share daily, and the file name and Notes tab carry the load date.

## Workbooks

| Workbook | Tabs | Source tables |
|---|---|---|
| **PIPs** | By Store, By PIP, Machines (one row per machine × PIP), Notes | `customer_pips` |
| **JD University Training** | By Store, Employees, Learning Paths (employee × path), Training History (every enrollment / completion), Notes | `dealer_employee`, `dealer_john_deere_university_*` |
| **Service Opportunities** | By Store, By Program, Recommendations (open, machine × recommendation), Warranty Ending (coverage ending in `--days`), Notes | `warranty_recommendations`, `customer_warranty` |

## How the matching works (`jdshare.py`)

- **Store:**
  - JD account → our branch by city (`dealer_profile` × `dim_BranchLocation`). All 68 JD accounts map, including closed stores (Deming, Colorado City, O'Donnell) and the pre-2005 predecessors.
  - Division comes from `spart`: 11 Ag, 12 Turf, 13 CWP.
- **Machine → our customer:**
  - Serial matched against `Silver_WkVehFl.VIN`, in either PIN form (13 or 17 characters; JD's `product_information` supplies the other form).
  - `AccountNumber` → `dim_CustomerList`.
  - When a serial has several accounts (earlier owners), the most recently modified record is shown and the rest are listed in "Earlier Accounts on Serial".
- **In Our Stock:** the serial is an unsold unit in `Silver_VhStock` (no `SaleDate`).
- **JD Registered Owner:** JD's own name for the owner (`customer_profile` on `entity_id` + `contact_id`). It's shown next to ours because about 17% of machines have no match on our side.
- **Model:** `product_information.decal_mdl_id` → `eph.decal_model_nm`.

## First run (2026-11-03 load)

- **PIPs:** 5,749 machine × PIP rows (JD's 5,926 minus 177 re-titled duplicates).
  - 1,017 not complete, 39 of them Safety.
  - 4,835 matched to our customer; 89 on unsold stock units (17 not complete).
- **Training:** 1,049 JD users (372 active, all mapped to a store), 37,230 history rows, 1,062 employee × path rows.
- **Service opportunities:** 91,687 open recommendations (69,200 matched to our customer), 103 programs, 2,031 warranty coverages ending within 180 days.
