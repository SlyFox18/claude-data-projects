# EquipRDB64 Source System — Table Reference

Source system: **EQUIP DMS** (Dealer Management System)
ODBC connection: `dsn=EquipRDB64`
Generated: 2026-03-03 via `SELECT table_name, table_type, remarks FROM sys.systable`

---

## Key Discovery: Parts Transfer Architecture (2026-03-03)

`Parts_InterbranchTransfers` is a **VIEW** (not a base table), built from `InSalOrd` WHERE type = 'T'.
It has **no PartNumber column** — it is a ticket-level summary only.

To get part-line detail for transfers:
- **`InSalPar`** (Parts Sales Order Details) → `FILE_NO = PartTicket`
- One row per part line per transfer order
- `SHIPPED_QTY - SUPPLIED_QTY` = per-line outstanding quantity
- `SHIPPED_QTY > SUPPLIED_QTY` = outstanding line filter

See `projects/transfers - report/queries/fact-tables/Fact_OutstandingTransfers.pq` for the validated join pattern.

---

## Parts Module Tables (`-Parts-`)

| Table | Type | Description |
|-------|------|-------------|
| `Bin_Location` | BASE | Bin Location |
| `InHist` | BASE | History Monthly Summary |
| `InHist_Fill` | BASE | Fill information |
| `InManuf` | BASE | Manufacturer Master |
| `InMaster` | BASE | Dealer Master (parts inventory) |
| `INPUROHD` | BASE | Purchase Order Header |
| `InPurOrd` | BASE | Purchase Order Details |
| `InSalOrd` | BASE | **Sales Order Header** — transfer orders are Type='T' here |
| `InSalPar` | BASE | **Sales Order Details/Lines** — FILE_NO = order header ID |
| `INSPRICE` | BASE | Special Pricing |
| `INSUGOR` | BASE | Suggested Reorder |
| `INSUPER` | BASE | Supersession |
| `InTrans` | BASE | Transactions (parts movements, invoices, adjustments) |
| `InTrans_Old` | BASE | Transactions for DELETED Parts |
| `INTRANS_CON` | VIEW | Consolidated transactions (InTrans + InTrans_Old) |
| `INTRANS_CONTACT` | VIEW | Parts Transactions & Customer information |
| `jdis_Part_Information` | VIEW | JDIS Part Information |
| `Parcel_Tracking` | BASE | Parcel Tracking |
| `Parts_BinInformation` | VIEW | Parts bin information (On-hand - WIP - Backorder - In-transit > 0) |
| `Parts_InterbranchTransfers` | VIEW | **Interbranch transfer info — Type='T' records from InSalOrd only. NO PartNumber.** |
| `Parts_NegativePartsOnHand` | VIEW | InMaster records with On-Hand < 0 |
| `Parts_PartsWithNoBin` | VIEW | Parts BIN Information |
| `Parts_PartTicketDeleted` | VIEW | Parts tickets deleted since beginning of prior year (from UAUDIT) |
| `Parts_Receipt_Staging` | BASE | Receipt Staging |
| `STOCKTAKE` | BASE | Stocktake (Physical Inventory) details |

---

## Financial Module Tables (`-Financial-`)

| Table | Type | Description |
|-------|------|-------------|
| `ApCheque` | BASE | Checks Issued - History |
| `APMASTER` | BASE | Vendor (Creditors)/Suppliers Master |
| `ApTrans` | BASE | Vendor Outstanding Invoices & Credit notes |
| `ArMaster` | BASE | Customers (Debtors) Master |
| `ArMaster_Customer` | BASE | Customers (Debtors) Business Rules |
| `ArTrans` | BASE | Customers (Debtors) Outstanding Transactions |
| `Branch_Name` | BASE | Location (Branch) name and details |
| `Financial_Calendar` | BASE | System Financial Calendar |
| `Financial_PeriodData_new` | BASE | GL, DFA & GL-Option3 financial summaries by fiscal year/period |
| `GLMASTER` | BASE | GL Master |
| `GlTrans` | BASE | GL Transactions |
| `GlValue` | BASE | GL Period Values |
| `Invoice` | BASE | Invoice details |
| `Inv_Line` | BASE | Invoice line item details |
| `InvoiceInformationDetail` | VIEW | General information for invoices (sales, cost values) |
| `InvoiceHistoryDetail` | VIEW | Workshop invoice sales, cost, gross margin |
| `OldTrans` | BASE | Customers and Vendors transaction History |

---

## Service Module Tables (`-Service-`)

| Table | Type | Description |
|-------|------|-------------|
| `RepairOrderDetail` | BASE | Work order dates and sales totals |
| `RepairOrderAging` | VIEW | WIP dollars per work order in aging buckets |
| `TechnicianAttendanceDetail` | BASE | Technician attendance hours by date/time |
| `TechnicianInvoiceDetail` | BASE | Invoice hour totals by technician/branch/date |
| `TechnicianPunchedDetail` | BASE | Technician hour totals by RO/technician/branch/date |
| `WarClaim` | BASE | Warranty claims |
| `WarSubCl` | BASE | Warranty subclaims |
| `WarSubCl_Labour` | BASE | Warranty Subclaim Labor |
| `JD_CONTRACT_WARINFO` | BASE | Warranty info and maintenance contract detail |

---

## Sales Module Tables (`-Sales-`)

| Table | Type | Description |
|-------|------|-------------|
| `VhStock` | BASE | Stock Unit records |
| `VhTrans` | BASE | Stock Unit Equipment Transactions |
| `VhSalman` | BASE | Stock Unit Sales Person information |
| `VhQuote` | BASE | Outstanding Stock Unit Quotations |
| `Rental_Contract` | BASE | Rental Contract |
| `Rental_History` | BASE | Rental History |

---

## System / Cross-Module Tables

| Table | Type | Description |
|-------|------|-------------|
| `ArMaster_Customer` | BASE | Customer Business Rules (has TradeType) |
| `Branch_Name` | BASE | Location (Branch) name and details |
| `contact` | BASE | General info about contacts (customers, technicians) |
| `SYSEMP` | BASE | EQUIP system users |
| `codtyp` | BASE | All Franchises and Descriptions |
| `UAUDIT` | BASE | User Activity Audit |

---

## InTrans Column Notes

InTrans stores ALL parts transaction types. Key columns:
- `Type` — transaction type: `T`=Transfer, `I`=Invoice/Issue, `A`=Adjustment, `P`=Purchase, `R`=Return, `C`=Credit
- `REF_NO` — reference number (invoice #, transfer ticket #, RO #) — NOT a reliable join to PartTicket for most records
- `Trans_Id` — row-level sequential ID in the **13M+ range** — does NOT correspond to PartTicket numbers (1M–2M range). Numeric overlap with PartTickets is coincidental.
- `Transfer_Branch` — destination branch for transfer transactions
- For Type='T' rows: `REF_NO` = PartTicket. But InTrans is only populated AFTER parts ship — pre-shipment transfers have no InTrans row.

## InSalPar Column Notes

Key columns for transfer orders:
- `FILE_NO` — transfer ticket number (= `Parts_InterbranchTransfers.PartTicket`) ✓ VALIDATED JOIN KEY
- `Line_No` — line number within the order (1-based)
- `PART_NO` — part number being transferred
- `FRANCHISE` — franchise/manufacturer code (often blank for transfers)
- `ORDER_QTY` — quantity originally ordered
- `SHIPPED_QTY` — quantity dispatched from supplying branch
- `SUPPLIED_QTY` — quantity confirmed received at requesting branch
- `SO_RO_Ref` — Sales Order / Repair Order reference (used for TransferSubType classification)
- `SALESMAN` — salesman code (often blank for transfers)
- `Creation_Datetime` — when the transfer line was created
- `By_Program` — `'Parts Transfer'` for transfer lines
- `PURORDER_TYPE` — `'D'` for transfer dispatch lines
- `TRANSFER_STATUS`, `RECEIVING_TRANSFER_STATUS` — transfer workflow status fields
