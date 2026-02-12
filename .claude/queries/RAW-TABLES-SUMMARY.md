# Raw Tables Quick Reference Guide

**Purpose**: Fast lookups for raw table information, relationships, and field locations.

**Last Updated**: 2026-01-14

**🔍 Database Schema Discovery**: See [metadata-queries](../../.claude/metadata-queries/) for SQL queries to explore the source database schema

---

## Table of Contents
1. [Tables by Business Domain](#tables-by-business-domain)
2. [Key Field Index](#key-field-index)
3. [Table Relationships Map](#table-relationships-map)
4. [Incremental Refresh Reference](#incremental-refresh-reference)
5. [Performance Characteristics](#performance-characteristics)
6. [Quick Stats Summary](#quick-stats-summary)

---

## Tables by Business Domain

### 👥 Customer & Accounts Receivable
- **armaster** (53K rows) - Customer master data with account details
- **ArMaster_Contact** (53K rows) - Customer contact information
- **ArMaster_Customer** (53K rows) - Customer business details
- **contact** (82K rows) - Complete contact records

**Common Fields**: AccountNumber, ContactCode, CustomerName, AccountClass

---

### 🔧 Work Orders & Service
- **WKROFILE** (112K rows) - Work order master/header data
- **RepairOrderDetail** (2K rows) - Work order detail/line items
- **wkrodesc** (904K rows) - Primary job codes per work order (LINE_NO=1)
- **WkInvReg** (41K rows) - Invoice registration for work orders

**Common Fields**: Branch, WorkOrder (RO_NUMBER), Registration, JobCode

---

### 👨‍🔧 Labor & Technician
- **Technician** (1.4K rows) - Technician master data
- **wkmechwk** (308K rows) - Labor entries per technician per job
- **TechnicianInvoiceDetail** (330K rows) - Technician billing details
- **TechnicianPunchedDetail** (319K rows) - Technician time punches

**Common Fields**: TechCode, WorkOrder, JobCode, Branch

---

### 🔩 Parts & Inventory
- **InMaster** (1.08M rows) - Parts inventory master (NOT SCHEDULED - BASELINE)
- **jdis_Part_Information** (1.08M rows) - John Deere parts data (3x daily refresh)
- **InHist_PmManage** (721K rows) - Parts history/movements

**Common Fields**: PartNumber, Description, Category, Franchise

---

### 🚜 Equipment & Vehicles
- **vhstock** (24K rows) - Equipment sales transactions
- **VhStockAccess** (683K rows) - Equipment accessories/add-ons (NOT SCHEDULED - BASELINE)
- **WKVEHFL** (48K rows) - Vehicle fleet master data

**Common Fields**: Registration, StockNumber, VIN, Make, Model, Franchise

---

### 💰 Financial & Job Details
- **wkothsub** (350K rows) - Job-level financial breakdown (Est/Act/Inv cycle)
- **Invoice** (1.4M rows) - Invoice master records
- **GlTrans** (209K rows) - General ledger transactions

**Common Fields**: InvoiceNumber, WorkOrder, Branch, AccountNumber

---

### 🏢 Branch & Location
- **Branch_Name** (99 rows) - Branch master data (ON-DEMAND - OPTIMAL)
- **BranchOperational** (99 rows) - Branch operational details (ON-DEMAND - OPTIMAL)

**Common Fields**: Branch, LocationID, BranchName

---

### 🛠️ Sales Orders & Parts Management
- **insalord** (8.6K rows) - Internal sales orders
- **insalpar** (13K rows) - Internal sales parts detail

**Common Fields**: OrderNumber, PartNumber, Branch

---

### 🔧 Warranty & Claims
- **WarClaim** (11K rows) - Warranty claims master (NOT SCHEDULED - BASELINE)
- **WarsubCl_Labour** (66K rows) - Warranty labor detail (NOT SCHEDULED - BASELINE)

**Common Fields**: ClaimNumber, InvoiceNumber, WorkOrder

---

## Key Field Index

**"Where do I find...?"** - Quick field location reference

### Core Identifiers
- **Branch/Location**: ALL work order and transaction tables (WKROFILE, wkmechwk, wkothsub, etc.)
- **WorkOrder (RO_NUMBER)**: WKROFILE, wkmechwk, wkothsub, wkrodesc, RepairOrderDetail, WkInvReg
- **AccountNumber**: armaster, ArMaster_Customer, contact, WKROFILE, WKVEHFL
- **ContactCode**: contact, ArMaster_Contact
- **InvoiceNumber**: Invoice, WkInvReg, wkothsub, WarClaim

### Equipment/Vehicle
- **Registration (REG)**: WKROFILE, WKVEHFL
- **VIN**: vhstock, WKVEHFL
- **StockNumber**: vhstock, VhStockAccess, WKROFILE
- **Franchise**: armaster, InMaster, WKROFILE, WKVEHFL, vhstock

### Parts
- **PartNumber**: InMaster, jdis_Part_Information, InHist_PmManage, insalpar
- **PartDescription**: InMaster, jdis_Part_Information
- **Category**: InMaster, jdis_Part_Information

### Labor/Technician
- **TechCode**: Technician, wkmechwk, TechnicianInvoiceDetail, TechnicianPunchedDetail
- **JobCode**: wkmechwk, wkothsub, wkrodesc
- **HoursWorked**: wkmechwk
- **LaborCost/LaborSale**: wkmechwk, wkothsub

### Financial
- **EstLabor/ActLabor/InvLabor**: wkothsub (complete Est/Act/Inv cycle)
- **EstParts/ActParts/InvParts**: wkothsub (complete Est/Act/Inv cycle)
- **InvoiceTotal**: Invoice, WkInvReg
- **SalesValue**: vhstock

### Timeline/Dates
- **ModifiedDate**: armaster, contact, InMaster, TechnicianInvoiceDetail, WkInvReg, wkmechwk, wkothsub, WKROFILE, WKVEHFL
- **CreatedOn/CreationDate**: RepairOrderDetail, TechnicianPunchedDetail, WKROFILE, WkInvReg
- **InvoiceDate**: Invoice, wkothsub
- **SaleDate**: vhstock
- **RepairDate**: WarClaim

---

## Table Relationships Map

### Primary Relationship Chains

#### Work Order → Labor → Financial
```
WKROFILE (Work Order Master)
    ↓ Branch + WorkOrder
wkmechwk (Labor Entries) ← TechCode → Technician (Tech Master)
    ↓ Branch + WorkOrder + JobCode
wkothsub (Job Financial Detail)
    ↓ Branch + WorkOrder
WkInvReg (Invoice Registration)
    ↓ InvoiceNumber
Invoice (Invoice Master)
```

#### Customer → Work Order → Equipment
```
armaster/ArMaster_Customer (Customer Master)
    ↓ AccountNumber
WKROFILE (Work Order Master)
    ↓ Registration
WKVEHFL (Vehicle Fleet Master)
```

#### Equipment Sales Chain
```
vhstock (Equipment Sales Transaction)
    ↓ StockNumber
VhStockAccess (Equipment Accessories)
```

#### Parts Chain
```
InMaster (Parts Inventory Master)
    ↓ PartNumber
InHist_PmManage (Parts History/Movements)
    ↓ PartNumber
insalpar (Internal Sales Parts Detail)
```

#### Warranty Chain
```
WarClaim (Warranty Claims Master)
    ↓ ClaimNumber
WarsubCl_Labour (Warranty Labor Detail)
```

### Common Join Keys by Table

| Table | Primary Join Keys | Links To |
|-------|------------------|----------|
| WKROFILE | Branch + WorkOrder | wkmechwk, wkothsub, WkInvReg, RepairOrderDetail |
| wkmechwk | Branch + WorkOrder, TechCode | WKROFILE, Technician, wkothsub |
| wkothsub | Branch + WorkOrder, InvoiceNumber | WKROFILE, Invoice, wkmechwk |
| Invoice | InvoiceNumber | wkothsub, WkInvReg, WarClaim |
| armaster | AccountNumber | WKROFILE, contact |
| WKVEHFL | Registration | WKROFILE |
| InMaster | PartNumber | InHist_PmManage, insalpar |
| Technician | TechCode | wkmechwk, TechnicianInvoiceDetail, TechnicianPunchedDetail |

---

## Incremental Refresh Reference

### Tables WITH Incremental Refresh (9 tables)

| Table | Date Field | Scope | Notes |
|-------|------------|-------|-------|
| TechnicianInvoiceDetail | ModifiedDate | 2023+ | Labor billing data |
| TechnicianPunchedDetail | CreationDate | 2023+ | Time punch data |
| Invoice | InvoiceDate | (varies) | Invoice master |
| vhstock | SaleDate | 2022+ | 3-year sales window |
| WkInvReg | ModifiedDate | 2023+ | Invoice registration |
| wkmechwk | ModifiedDate | 2023+ | Labor entries |
| wkothsub | ModifiedDate | 2023+ | Job financial detail |
| WKROFILE | ModifiedDate | 2023+ | Work order master |
| WKVEHFL | ModifiedDate | 2023+ | Vehicle fleet |
| WarClaim | RepairDate | 2022+ | 3-year warranty window (NOT SCHEDULED) |

### Tables WITHOUT Incremental Refresh (11 tables)

| Table | Strategy | Reason |
|-------|----------|--------|
| ArMaster_Contact | Full refresh | (Could add ModifiedDate) |
| ArMaster_Customer | Full refresh | (Could add ModifiedDate) |
| armaster | Full refresh | (Has ModifiedDate - could add incremental) |
| contact | Full refresh | (Has ModifiedDate - could add incremental) |
| GlTrans | Full refresh | (Check for date field) |
| InHist_PmManage | Full refresh | (Has PeriodDate - could add incremental) |
| insalord | Full refresh | Small dataset (8.6K rows) |
| insalpar | Full refresh | Small dataset (13K rows) |
| RepairOrderDetail | Full refresh | (Has CreationDate - could add incremental) |
| Technician | Full refresh | Small master table (1.4K rows) |
| wkrodesc | Full refresh with filter | LINE_NO=1 filter (no ModifiedDate available) |

### Baseline Tables (NOT Scheduled - Optimal Performance)

| Table | Rows | Refresh Time | Notes |
|-------|------|--------------|-------|
| InMaster | 1.08M | 4-5 min | Large parts inventory - PROOF timing is issue |
| VhStockAccess | 683K | 2 min | Large accessories - PROOF timing is issue |
| WarsubCl_Labour | 66K | 1:30 | Medium warranty labor - PROOF timing is issue |
| WarClaim | 11K | 1:10 | Small warranty claims - PROOF timing is issue |

---

## Performance Characteristics

### 🚨 7:30 AM Master Orchestrator Pipeline (20 AFFECTED TABLES)

**Total Impact**: 490-605 minutes/week wasted = **8-10 HOURS/WEEK**

#### Affected Tables by Degradation Level

**CRITICAL (400-700% degradation):**
- insalord: 1 min → 6-7 min (600% - SMOKING GUN: tiny table)
- vhstock: 1-1:30 min → 6-7 min (400-600%)
- WkInvReg: 1-2 min → 8-9 min (400-700%)
- Technician: 1-1:30 min → 6-7 min (400-600% - ABSURD: 1.4K rows, 3 cols)
- RepairOrderDetail: 1-1:30 min → 6-7 min (400-600% - SMOKING GUN: 2K rows)
- insalpar: 1-1:30 min → 6-7 min (400-600%)
- WKROFILE: 1-2 min → 7-8 min (400-700%)
- WKVEHFL: 1-2 min → 7-8 min (400-700%)

**SEVERE (300-400% degradation):**
- wkmechwk: 1-2 min → 6-8 min (300-400%)
- TechnicianInvoiceDetail: 1:30-2 min → 6-7 min (300-400%)
- wkothsub: 2 min → 6-7 min (300-350%)

**SIGNIFICANT (200-400% degradation):**
- ArMaster_Contact: 1-2 min → 6-8 min
- ArMaster_Customer: 1-2 min → 6-8 min
- armaster: 1-2 min → 6-7 min
- contact: 1:30-2 min → 6-8 min
- GlTrans: 2-3 min → 6-8 min
- InHist_PmManage: 3 min → 8-9 min (200%+)
- Invoice: 4-5 min → 10-12 min (200-250%)
- TechnicianPunchedDetail: 1:30-3 min → 7-8 min (200-400%)
- wkrodesc: 1:30-3 min → 6-8 min (200-400%)

### ✅ Optimal Performance (NOT at 7:30 AM)

| Table | Rows | Time | Schedule | Evidence |
|-------|------|------|----------|----------|
| Branch_Name | 99 | 1:12 | On-demand | Optimal - reference data |
| BranchOperational | 99 | 1:20 | On-demand | Optimal - reference data |
| InMaster | 1.08M | 4-5 min | NOT SCHEDULED | **BASELINE - proves 7:30 AM is issue** |
| VhStockAccess | 683K | 2 min | NOT SCHEDULED | **BASELINE - proves 7:30 AM is issue** |
| WarClaim | 11K | 1:10 | NOT SCHEDULED | **BASELINE - same size as insalord, 5-6x faster** |
| WarsubCl_Labour | 66K | 1:30 | NOT SCHEDULED | **BASELINE - same size as ArMaster, 4-5x faster** |
| jdis_Part_Information | 1.08M | 8 min | 7:30am, 9:30am, 4pm | Multiple refreshes, consistent performance |

---

## Quick Stats Summary

### By Row Count Category

**Tiny (< 10K rows):**
- Technician: 1.4K
- RepairOrderDetail: 2K
- insalord: 8.6K
- WarClaim: 11K (baseline)

**Small (10K-50K rows):**
- insalpar: 13K
- vhstock: 24K
- WkInvReg: 41K
- WKVEHFL: 48K

**Medium (50K-200K rows):**
- ArMaster_Contact: 53K
- ArMaster_Customer: 53K
- armaster: 53K
- WarsubCl_Labour: 66K (baseline)
- contact: 82K
- Branch_Name: 99 (reference)
- BranchOperational: 99 (reference)
- WKROFILE: 112K

**Large (200K-1M rows):**
- GlTrans: 209K
- wkmechwk: 308K
- TechnicianPunchedDetail: 319K
- TechnicianInvoiceDetail: 330K
- wkothsub: 350K
- VhStockAccess: 683K (baseline)
- InHist_PmManage: 721K
- wkrodesc: 904K

**Very Large (1M+ rows):**
- InMaster: 1.08M (baseline)
- jdis_Part_Information: 1.08M
- Invoice: 1.4M

### By Column Count

**Simple (< 10 columns):**
- Technician: 3 cols
- wkrodesc: 6 cols (SIMPLEST - proves complexity NOT issue)
- WarsubCl_Labour: 9 cols

**Medium (10-20 columns):**
- WKVEHFL: 16 cols
- wkmechwk: 19 cols
- WarClaim: 19 cols
- WKROFILE: 20 cols
- wkothsub: 21 cols (performance optimized)

**Complex (20+ columns):**
- vhstock: 27 cols (most complex)

### Source System

**All Tables**: SQL Anywhere Database via ODBC (dsn=EquipRDB64)

---

## Usage Guidelines

### When Adding New Raw Tables:
1. ✅ Check if incremental refresh possible (look for date fields)
2. ✅ Document in appropriate business domain section
3. ✅ **AVOID scheduling at 7:30 AM weekdays** (proven systemic issue)
4. ✅ Add to REFRESH-TIMES.md with baseline performance
5. ✅ Create .pq file with complete documentation
6. ✅ Test refresh time and document

### When Optimizing Existing Tables:
1. ✅ Check baseline tables for comparison (InMaster, VhStockAccess, WarClaim, WarsubCl_Labour)
2. ✅ Consider incremental refresh if ModifiedDate/CreationDate available
3. ✅ Test column count thresholds (20-21 cols seems optimal)
4. ✅ **Primary solution: Fix 7:30 AM timing OR reschedule outside window**

### For Quick Lookups:
1. 🔍 Use **Key Field Index** to find which table has a specific field
2. 🔗 Use **Table Relationships Map** to understand how tables connect
3. ⚡ Use **Performance Characteristics** to understand expected refresh times
4. 📊 Use **Quick Stats Summary** for size/complexity comparisons

---

**Next Steps**:
- [ ] Create 7:30AM-PIPELINE-ISSUE.md for detailed root cause analysis
- [ ] Document dimension tables
- [ ] Document fact tables
- [ ] Create optimization roadmap for 7:30 AM issue

---

*This document is a living reference - update as new tables are added or patterns change.*
