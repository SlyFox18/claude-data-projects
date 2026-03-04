# Transfers Report — Page Reference

**Last Updated:** 03/04/2026
**Audience:** Stakeholders, new developers, report administrators

---

## Overview

The Transfers report has three user-facing pages plus two hidden tooltip pages. All pages share the same date slicer and branch slicer (synced across pages). The report uses a collapsible left navigation panel for page-to-page navigation.

| Page | Name | Fact Table | Primary Question |
|------|------|------------|-----------------|
| 1 | **Transfers** | `Fact_Transfers` | What is the transfer activity by branch and sub-type? |
| 2 | **Inventory View** | `Fact_Transfers` + `Inv_Snapshot` | How does transfer volume compare to on-hand inventory? |
| 3 | **Outstanding Transfers** | `Fact_OutstandingTransfers` | What transfers are currently open and how old are they? |
| — | ToolTip 1 | — | Hidden tooltip (Page 1 visuals) |
| — | ToolTip 2 | — | Hidden tooltip (Page 2 visuals) |

---

## Page 1 — Transfers

**Purpose:** High-level transfer activity summary. Shows how many parts are moving between branches, what is driving those transfers, and which branches are the heaviest senders and receivers.

### Key Visuals

**Hero Card (HTML Visual)**
The top-of-page summary card displays the three transfer sub-types side by side — Work Order, Counter, and Stock — each showing the core metrics (quantity, lines, cost) for the selected period. When a sub-type is selected via the TransferSubType slicer, the non-selected sections dim to 35% opacity, drawing focus to the selected category. When no selection is made, all three sections display at full opacity.

**Balance Chart (Bar Chart)**
Compares Transfers In vs. Transfers Out for each branch side-by-side. Sorted by Transfer Out % descending by default. The chart title updates dynamically based on the selected TransferSubType. Tooltip shows the Transfer Out % for each branch.

**Branch Slicer**
Dropdown slicer on `dim_BranchLocation[Branch]`. Synced across all pages — selecting a branch here also filters Pages 2 and 3.

### Slicers & Filters

| Slicer | Field | Type | Synced |
|--------|-------|------|--------|
| Date | `dim_DateTable[Date]` | Date range | Yes — all pages |
| Branch | `dim_BranchLocation[Branch]` | Dropdown | Yes — all pages |
| TransferSubType | `Fact_Transfers[TransferSubType]` | List | Page 1 only |

### Business Questions Answered
- Which branches are transferring the most parts out? Into?
- Is transfer activity driven primarily by service (Work Order), customer orders (Counter), or replenishment (Stock)?
- Which branch has the highest transfer-out percentage relative to total transfers?

---

## Page 2 — Inventory View

**Purpose:** Contextualizes transfer activity against on-hand inventory. Answers the question "how much of what's being transferred represents a meaningful portion of what a branch actually carries?"

### Key Visuals

**Page 2 Hero Card (HTML Visual)**
Header card showing the selected date range and user greeting. Includes the date range subtitle derived from `MIN`/`MAX` of `dim_DateTable[Date]`, updating dynamically as the date slicer changes.

**Comparison Selector**
An interactive metric selector that lets the user choose which measure they want to compare — Qty, Cost, or Lines. The selected metric's panel displays at full opacity; non-selected panels dim to 35%. This drives which measure is shown in the comparison visuals below.

**Inventory vs. Transfer Comparisons**
Charts and visuals comparing the selected metric (Qty/Cost/Lines) from `Fact_Transfers` against the corresponding inventory figure from `Inv_Snapshot`, broken down by branch and/or part number.

### Slicers & Filters

| Slicer | Field | Type | Synced |
|--------|-------|------|--------|
| Date | `dim_DateTable[Date]` | Date range | Yes — all pages |
| Branch | `dim_BranchLocation[Branch]` | Dropdown | Yes — all pages |
| Metric Selector | `MetricSelector` | Button/toggle | Page 2 only |

### Business Questions Answered
- Are transfers a large or small fraction of a branch's total on-hand inventory?
- Which branches are transferring parts that represent a high % of their inventory value?
- Should certain branches be ordering more from the supplier instead of pulling from other branches?

### Notes
- `Inv_Snapshot` is a point-in-time daily snapshot — it reflects current on-hand, not historical inventory levels for the selected date range
- The inactive `TransferBranch` → `dim_BranchLocation` relationship is used in DAX measures on this page via `USERELATIONSHIP` where destination-branch filtering is needed

---

## Page 3 — Outstanding Transfers

**Purpose:** Operational visibility into transfer orders that are currently open — parts that have been requested from another branch but have not yet been fully received. Intended for daily review by operations staff.

### Key Visuals

**Outstanding Transfers Header (HTML Visual)**
Branded header showing "Outstanding Transfers" as the page title. Includes the selected date range subtitle so users know what period's open orders they are viewing.

**Outstanding Transfers Table**
The main data table showing one row per outstanding part line. Contains 11 columns:

| Column | Source | Notes |
|--------|--------|-------|
| Requesting Branch | `Fact_OutstandingTransfers[RequestingBranch]` | Branch waiting for the part |
| Supplying Branch | `Fact_OutstandingTransfers[SupplyingBranch]` | Branch sending the part |
| Part Ticket | `Fact_OutstandingTransfers[PartTicket]` | Transfer order number |
| Date | `Fact_OutstandingTransfers[Date]` | Transfer order creation date |
| Part Number | `Fact_OutstandingTransfers[PartNumber]` | Part being transferred |
| Description | `dim_Parts[Description]` | Part description via dim_Parts join |
| Transfer Sub-Type | `Fact_OutstandingTransfers[TransferSubType]` | Work Order / Counter / Stock |
| Order Qty | `Fact_OutstandingTransfers[OrderQty]` | Total quantity ordered |
| Shipped Qty | `Fact_OutstandingTransfers[ShippedQty]` | Quantity dispatched from supply branch |
| Order Age | `Fact_OutstandingTransfers[OrderAge]` | Days since transfer was placed (source system calculated) |
| Fulfillment Status | `Fact_OutstandingTransfers[FulfillmentStatus]` | Pending / Partial / Shipped |

**Table default sort:** FulfillmentStatus ascending (Partial → Pending → Shipped)

### Conditional Formatting

**Order Age — Color by Aging Bucket:**

| Color | Meaning | Rule |
|-------|---------|------|
| 🟢 Green | Fresh — 0–7 days | Age Band = 1 |
| 🟡 Yellow | Moderate — 8–30 days | Age Band = 2 |
| 🟠 Orange | Aging — 31–60 days | Age Band = 3 |
| 🔴 Red | Critical — 61+ days | Age Band = 4 |

Driven by the `FulfillmentStatus Color Key` DAX measure which maps bucket numbers to colors.

**Fulfillment Status — Color by Status:**

| Color | Status | Meaning |
|-------|--------|---------|
| 🟢 Green | Shipped | Fully dispatched — in transit, awaiting receipt |
| 🟡 Yellow | Pending | Nothing dispatched yet |
| 🔴 Red | Partial | Partially dispatched — some qty still at supply branch |

### Slicers & Filters

| Slicer | Field | Type | Synced |
|--------|-------|------|--------|
| Date | `dim_DateTable[Date]` | Date range | Yes — all pages |
| Branch | `dim_BranchLocation[Branch]` | Dropdown | Yes — all pages (filters on RequestingBranch) |
| Transfer Sub-Type | `Fact_OutstandingTransfers[TransferSubType]` | List | Page 3 only |
| Fulfillment Status | `Fact_OutstandingTransfers[FulfillmentStatus]` | List | Page 3 only |
| Aging Bucket | `Fact_OutstandingTransfers[Aging Bucket]` | List | Page 3 only |

### Business Questions Answered
- Which transfer orders have been open the longest?
- Are there transfers that have been requested but nothing has shipped yet (Pending)?
- Which branches have the most outstanding inbound transfers?
- Are there partially shipped orders that need follow-up from the supply branch?

### Notes
- All rows in `Fact_OutstandingTransfers` represent currently open orders (as of the last pipeline refresh). Completed transfers do not appear.
- **"Shipped" status does not mean received** — it means the supply branch has dispatched the full order quantity but the requesting branch has not yet confirmed receipt (`SuppliedQty < ShippedQty`).
- The Branch slicer filters on `RequestingBranch` (active relationship). To filter by supplying branch, use the search/filter on the SupplyingBranch column directly in the table.
- OrderAge is pre-calculated by the source system (not derived from the creation date in Power BI). It represents days since the transfer order was originally placed.

---

## Navigation

All pages share a collapsible left navigation panel (expand via the menu icon in the top-left). The panel contains page links and a "Clear All Slicers" action (SPI logo button). Page-to-page navigation is also available via icon buttons in the top navigation area of each page.

---

## Hidden Pages

| Page | Type | Purpose |
|------|------|---------|
| ToolTip 1 | Tooltip | Custom tooltip displayed when hovering over Page 1 chart visuals |
| ToolTip 2 | Tooltip | Custom tooltip displayed when hovering over Page 2 chart visuals |

These pages are not visible to end users in view mode — they are referenced automatically by the visuals they are attached to.
