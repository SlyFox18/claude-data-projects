# Power Automate Flow Setup Guide
## Parts Action Summary — Weekly Branch Email

---

## Flow Overview

| Setting | Value |
|---|---|
| Flow name | Parts Action Summary - Orchestrator |
| Trigger | Recurrence — weekly Wednesday 8:00 AM CST |
| Schedule | Always sends to every eligible recipient regardless of thresholds |
| Recipient source | SPI-PARTS Azure AD group — filtered by officeLocation |
| Branch mapping | PartsBranchMapping SharePoint list (OfficeLocation → BranchFilter) |
| Data source | Power BI REST API (DAX queries against multiple datasets) |
| Email service | Microsoft Graph API via plain HTTP connector (Office 365 Outlook connector for the separate Branch 12 mailing — see below) |

**2026-07-27 update:** two changes landed together —
1. A new **"MD Freight" KPI section + CSV attachment** was merged into this
   flow (both the Orchestrator and its test child), sourced from the
   "MD Invoices With No Freight" report. This absorbs what was originally
   built as a separate standalone "MD Freight Weekly Digest" flow — Ben
   asked for it to ride this existing weekly email instead of adding another
   one. See the "MD Freight" subsections below.
2. The **NegOH/NoBin attachment thresholds changed from `>= 10` to `> 0`**
   (any count above zero now attaches the CSV, not just 10+) — this was a
   deliberate change made directly in the live Orchestrator while fixing the
   Branch 12 bug below, then propagated into the test flow to keep them in
   sync. The Aging threshold was already `> 0` and is unchanged. **This doc's
   DAX/table snippets below have been updated to reflect `> 0` — if you're
   comparing against an old export or a stale local copy, expect to see
   `>= 10` there instead.**

---

## Architecture

### Two-flow structure

| Flow | Purpose |
|---|---|
| Parts Action Summary - Orchestrator | Production flow — runs on schedule, loops through all SPI-PARTS members |
| Parts Action Summary - Weekly Branch Email | Manual testing only — accepts 4 inputs (Name, BranchName, BranchFilter, Email), runs single-branch email |

The orchestrator was built by merging the child flow's logic directly into a loop. "Run a child flow" is not available in this tenant, and the new designer does not support changing triggers on existing flows — both were blockers that led to the JSON-merge approach.

### Recipient pipeline

```
SPI-PARTS Azure AD group (88 members)
  → skip: blank officeLocation, officeLocation = "Support Center"
  → PartsBranchMapping SharePoint lookup (OfficeLocation → BranchFilter)
  → skip: no matching row found
  → send email with that branch's data
```

### Skip list (managed via Azure AD officeLocation)

| Person | Why skipped |
|---|---|
| Nick Sloan | Blank officeLocation |
| Cody Lewis | Blank officeLocation (cleared — CSR, not parts) |
| Chris Snodgrass | Blank officeLocation (cleared — Owner) |
| Casey Hurst | officeLocation = Support Center |
| Barry Sheets | officeLocation = Support Center |
| Shannon Brooks | officeLocation = Support Center |
| Ben Hill | officeLocation = Support Center |

To skip someone new: clear their officeLocation in Azure AD or set it to "Support Center". No flow changes needed.

---

## Azure App Registration

An app registration named **"Parts Action Dashboard Email"** was created in Microsoft Entra ID.

| Setting | Value |
|---|---|
| App name | Parts Action Dashboard Email |
| Tenant | spitractor.com |
| Permissions | Microsoft Graph → Mail.Send (Application), GroupMember.Read.All (Application), User.Read.All (Application) |
| Admin consent | Granted |
| Secret expiry | April 2028 (24 months from creation) |

To find the Client ID and Tenant ID: Azure Portal → Microsoft Entra ID → App registrations → Parts Action Dashboard Email → Overview.

**Important:** The client secret expires April 2028. Before that date, go to Certificates & secrets → create a new secret → update the HTTP action authentication in both HTTP steps of the flow (HTTP - Get Users and the sendMail HTTP).

---

## SharePoint — PartsBranchMapping List

**Site:** South Plains Implement - Report Site
**List:** PartsBranchMapping
**List GUID:** 19da5d2c-18b8-4359-8c0b-9a4e2711210d

| Column | Type | Purpose |
|---|---|---|
| Title | Text | Unused (default SharePoint column) |
| OfficeLocation | Text | Matches Azure AD officeLocation property — used as lookup key |
| BranchFilter | Text | Full branch string used in all DAX queries (e.g. "2 - Tornillo") |

### Current rows (19 branches)

| OfficeLocation | BranchFilter |
|---|---|
| Abernathy | 95 - Abernathy |
| Ballinger | 7 - Ballinger |
| Big Spring | 8 - Big Spring |
| Brownfield | 11 - Brownfield |
| Crosbyton | 94 - Crosbyton |
| Denver City | 3 - Denver City |
| Lamesa | 13 - Lamesa |
| Levelland | 15 - Levelland |
| Littlefield | 14 - Littlefield |
| Lorenzo | 91 - Lorenzo |
| Lubbock | 93 - Lubbock |
| Mesquite | 4 - Mesquite |
| Morton | 16 - Morton |
| San Angelo | 6 - San Angelo |
| Seminole | 1 - Seminole |
| Slaton | 92 - Slaton |
| Snyder | 96 - Snyder |
| Tahoka | 17 - Tahoka |
| Tornillo | 2 - Tornillo |

### Adding a new recipient

1. Ensure the person is in the SPI-PARTS Azure AD group
2. Ensure their officeLocation in Azure AD matches an OfficeLocation row in this list
3. No flow changes needed

### Removing a recipient

Set their officeLocation to blank in Azure AD or remove them from SPI-PARTS. No flow changes needed.

---

## Power BI REST API Connection

| Dataset | Workspace | Group ID | Dataset ID |
|---|---|---|---|
| Parts Action Dashboard | RP - Parts Reports | ba9d8de4-ef13-44e6-9156-e23a2511f3ad | 04f152e2-07a4-4715-9a4c-8adf82280f06 |
| Transfers | RP - Parts Reports | 4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7 | 47405102-4966-4658-9a49-6457d0a617ff |
| Parts Adjustments | RP - Parts Reports | 4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7 | 97fc2743-290c-46fb-a033-d12a20f8759b |
| Bin Location | RP - Parts Reports | 4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7 | 28cced68-a852-412b-befd-d41d8118a2ea |
| Pin Capture | RP - Parts Reports | 4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7 | f7ab2948-e3ae-42c9-833e-61f5f955c790 |
| Physical Inventory | RP - Parts Reports | 4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7 | 80c1dc15-60b3-4c6a-9398-3c79b77a4667 |
| MD Invoices With No Freight (added 2026-07-27) | RP - Parts Reports | 4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7 | 88bcada9-ceeb-42e5-99f9-9b6cd06a9f0d |

---

## Flow Structure (Orchestrator)

```
Trigger: Recurrence — weekly Wednesday 8:00 AM Central Standard Time
│
├── HTTP - Get Users
│   GET https://graph.microsoft.com/v1.0/groups/{SPI-PARTS-id}/members
│       ?$select=displayName,givenName,mail,officeLocation&$top=999
│   Auth: Active Directory OAuth (Parts Action Dashboard Email app)
│   Returns: array of up to 999 SPI-PARTS members
│
├── Initialize variables (9 — declared once before the loop)
│   RecipientName, RecipientBranchName, RecipientBranchFilter, RecipientEmail (String)
│   Attachments (Array), AttachmentsJSON, NegOHCSV, NoBinCSV, AgingCSV (String)
│
└── Apply to each — body('HTTP_-_Get_Users')?['value']
    │
    ├── Condition (SKIP): or(empty(officeLocation), equals(officeLocation, 'Support Center'))
    │   TRUE → skip (no actions)
    │   FALSE →
    │       ├── Get_items (SharePoint PartsBranchMapping)
    │       │   Filter: OfficeLocation eq '{item officeLocation}'
    │       │   Top: 1
    │       │
    │       └── Condition_1: length(Get_items results) > 0
    │           TRUE →
    │               ├── Set RecipientName = item givenName
    │               ├── Set RecipientBranchName = item officeLocation
    │               ├── Set RecipientBranchFilter = first Get_items result BranchFilter
    │               ├── Set RecipientEmail = item mail
    │               │
    │               ├── Run aggregate query (NegOH / NoBin / Aging counts)
    │               ├── Parse JSON
    │               ├── Compose: NegOH, NoBin, Aging
    │               │
    │               ├── Reset variables (Attachments=[], AttachmentsJSON='',
    │               │   NegOHCSV='', NoBinCSV='', AgingCSV='')
    │               │
    │               ├── Condition - NegOH: int(NegOH) > 0  (changed 2026-07-27, was >= 10)
    │               │   TRUE → NegOH detail query → CSV → append to AttachmentsJSON
    │               │
    │               ├── Condition - NoBin: int(NoBin) > 0  (changed 2026-07-27, was >= 10)
    │               │   TRUE → NoBin detail query → CSV → append to AttachmentsJSON
    │               │
    │               ├── Condition - Aging: int(Aging) > 0
    │               │   TRUE → Aging detail query → CSV → append to AttachmentsJSON
    │               │
    │               ├── Transfers query → CSV → append (always included)
    │               │
    │               ├── Parts Adjustments query → Condition (if any rows)
    │               │   TRUE → CSV → append
    │               │
    │               ├── Bin Location query → CSV → append (always included)
    │               │
    │               ├── Pin Capture query → Compose 4 metrics
    │               │
    │               ├── Physical Inventory query → Compose 2 metrics
    │               │
    │               ├── Physical Inventory Detail query → CSV → append (always included)
    │               │
    │               ├── MD Freight detail query → Parse JSON (added 2026-07-27)
    │               ├── MD Freight aggregate query → Compose 2 metrics
    │               ├── MD Freight CSV → append to AttachmentsJSON (always included)
    │               │
    │               └── Condition - Should We Send (always true)
    │                   TRUE →
    │                       ├── Compose: build final attachments JSON array
    │                       ├── Compose: HTML Body (now includes an "MD Freight" KPI section)
    │                       └── HTTP: Graph API sendMail
    │           FALSE → skip (no branch mapping found)
│
└── (outside the Apply to each, runs once after it finishes)
    Branch 12 (O'Donnell) Bin Location Report — see its own section below
    ├── Branch 12 Bin Location query → CSV
    ├── Filter SPI-PARTS members → Ballinger, Abernathy (two separate filters)
    ├── Select mail addresses for each
    └── Send email (Office 365 Outlook connector) to each branch's members
```

---

## DAX Queries

All queries use `variables('RecipientBranchFilter')` for the branch filter.
CALCULATETABLE filters via dim_BranchLocation relationship — do NOT filter directly
on the fact table branch column (stores sub-branch suffixes like "02I", "02S").

### Aggregate Query (NegOH / NoBin / Aging counts)

Uses COALESCE to return 0 instead of BLANK for branches with no data.

```dax
EVALUATE
ROW(
    "NegOH", COALESCE(CALCULATE(
        COUNTROWS(FILTER(Fact_NegativeOnHand_OnHandNoBin,
            Fact_NegativeOnHand_OnHandNoBin[HasNegativeBinQty] = TRUE())),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0),
    "NoBin", COALESCE(CALCULATE(
        COUNTROWS(FILTER(Fact_NegativeOnHand_OnHandNoBin,
            Fact_NegativeOnHand_OnHandNoBin[HasBinQtyNoBin] = TRUE())),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0),
    "Aging", COALESCE(CALCULATE(
        DISTINCTCOUNT(Fact_Parts_Open_Tickets[Order_No]),
        Fact_Parts_Open_Tickets[Days_Open] >= 30,
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0)
)
```

### NegOH Detail (conditional — only if count > 0, changed 2026-07-27, was >= 10)

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(Fact_NegativeOnHand_OnHandNoBin,
            Fact_NegativeOnHand_OnHandNoBin[HasNegativeBinQty] = TRUE()),
        "PartNumber", Fact_NegativeOnHand_OnHandNoBin[PartNumber],
        "Description", Fact_NegativeOnHand_OnHandNoBin[Description],
        "Franchise", Fact_NegativeOnHand_OnHandNoBin[Franchise],
        "Bin", Fact_NegativeOnHand_OnHandNoBin[Bin],
        "BinQty", Fact_NegativeOnHand_OnHandNoBin[BinQty],
        "OnHandQty", Fact_NegativeOnHand_OnHandNoBin[QuantityOnHand]
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### NoBin Detail (conditional — only if count > 0, changed 2026-07-27, was >= 10)

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(Fact_NegativeOnHand_OnHandNoBin,
            Fact_NegativeOnHand_OnHandNoBin[HasBinQtyNoBin] = TRUE()),
        "PartNumber", Fact_NegativeOnHand_OnHandNoBin[PartNumber],
        "Description", Fact_NegativeOnHand_OnHandNoBin[Description],
        "Franchise", Fact_NegativeOnHand_OnHandNoBin[Franchise],
        "OnHandQty", Fact_NegativeOnHand_OnHandNoBin[QuantityOnHand],
        "BulkBin", Fact_NegativeOnHand_OnHandNoBin[BulkBin]
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### Aging Detail (conditional — only if count > 0)

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(Fact_Parts_Open_Tickets,
            Fact_Parts_Open_Tickets[Days_Open] >= 30),
        "OrderNo", Fact_Parts_Open_Tickets[Order_No],
        "Customer", Fact_Parts_Open_Tickets[Customer],
        "DaysOpen", Fact_Parts_Open_Tickets[Days_Open],
        "AgingBucket", Fact_Parts_Open_Tickets[Aging],
        "OrderTotal", Fact_Parts_Open_Tickets[Order_Total_$$]
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### Transfers (always included)

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        Fact_OutstandingTransfers,
        "Requesting Branch", Fact_OutstandingTransfers[RequestingBranch],
        "Supplying Branch", Fact_OutstandingTransfers[SupplyingBranch],
        "Part Ticket", Fact_OutstandingTransfers[PartTicket],
        "Date", Fact_OutstandingTransfers[Date],
        "Part Number", Fact_OutstandingTransfers[PartNumber],
        "Description", RELATED(dim_Parts[Description]),
        "Transfer Type", Fact_OutstandingTransfers[TransferSubType],
        "Order Qty", Fact_OutstandingTransfers[OrderQty],
        "Shipped Qty", Fact_OutstandingTransfers[ShippedQty],
        "Order Age (Days)", Fact_OutstandingTransfers[OrderAge],
        "Status", Fact_OutstandingTransfers[FulfillmentStatus]
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### Parts Adjustments (conditional — only if any rows returned)

Last 7 days, excludes today.

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        Fact_PartsAdjustments,
        "Branch", Fact_PartsAdjustments[Branch],
        "Date", Fact_PartsAdjustments[TransDatetime],
        "Part Number", Fact_PartsAdjustments[PartNumber],
        "Description", RELATED(dim_Parts[Description]),
        "PA Type", Fact_PartsAdjustments[PAType],
        "Qty", Fact_PartsAdjustments[Qty],
        "Cost", Fact_PartsAdjustments[CostValue],
        "Ref No", Fact_PartsAdjustments[RONumber]
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}",
    Fact_PartsAdjustments[TransDatetime] >= TODAY() - 7,
    Fact_PartsAdjustments[TransDatetime] <= TODAY() - 1
)
```

### Bin Location (always included)

8 columns is the confirmed safe limit for the largest branch (Mesquite, 90,804 rows).
Column set confirmed 2026-04-27: replaced Bulk Bin / Bulk Bin Qty with Sell Price / Cost per Ben Hill.
Do NOT add columns without re-testing against Mesquite.

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        jdis_Part_Information,
        "Part Number", jdis_Part_Information[PartNumber],
        "Description", jdis_Part_Information[Description],
        "Franchise", jdis_Part_Information[Franchise],
        "Bin", jdis_Part_Information[Bin],
        "Bin Qty", jdis_Part_Information[BinQty],
        "Sell Price", jdis_Part_Information[SellPrice1],
        "Cost", jdis_Part_Information[Cost],
        "On Hand Qty", jdis_Part_Information[QuantityOnHand]
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### Pin Capture (always included — HTML metrics only, no CSV)

Date range: February 2, 2026 → today.

```dax
EVALUATE
ROW(
    "CaptureRate", COALESCE(CALCULATE(
        DIVIDE(
            CALCULATE(DISTINCTCOUNT(Fact_PinTransactions[RONumber]),
                Fact_PinTransactions[Has Pin] = TRUE),
            DISTINCTCOUNT(Fact_PinTransactions[RONumber]), 0),
        Fact_PinTransactions[Type] = "I",
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}",
        DATESBETWEEN(dim_DateTable[Date], DATE(2026,2,2), TODAY())), 0),
    "TotalTrans", COALESCE(CALCULATE(
        DISTINCTCOUNT(Fact_PinTransactions[RONumber]),
        Fact_PinTransactions[Type] = "I",
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}",
        DATESBETWEEN(dim_DateTable[Date], DATE(2026,2,2), TODAY())), 0),
    "TransWithPin", COALESCE(CALCULATE(
        DISTINCTCOUNT(Fact_PinTransactions[RONumber]),
        Fact_PinTransactions[Has Pin] = TRUE,
        Fact_PinTransactions[Type] = "I",
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}",
        DATESBETWEEN(dim_DateTable[Date], DATE(2026,2,2), TODAY())), 0),
    "CostCaptured", COALESCE(CALCULATE(
        SUM(Fact_PinTransactions[CostValue]),
        CALCULATETABLE(
            VALUES(Fact_PinTransactions[RONumber]),
            Fact_PinTransactions[Has Pin] = TRUE,
            Fact_PinTransactions[Type] = "I",
            dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}",
            DATESBETWEEN(dim_DateTable[Date], DATE(2026,2,2), TODAY())
        ),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}",
        DATESBETWEEN(dim_DateTable[Date], DATE(2026,2,2), TODAY())), 0)
)
```

### Physical Inventory Summary (always included — HTML metrics only)

```dax
EVALUATE
ROW(
    "BinsPctCounted", COALESCE(CALCULATE(
        DIVIDE(
            CALCULATE(DISTINCTCOUNT('Physical Inventory'[Bin]),
                'Physical Inventory'[Is Bin Uncounted This Year] = 0),
            DISTINCTCOUNT('Physical Inventory'[Bin]), 0),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0),
    "PartsPctCounted", COALESCE(CALCULATE(
        DIVIDE(
            CALCULATE(DISTINCTCOUNT('Physical Inventory'[PartNumber]),
                'Physical Inventory'[Is Part Uncounted This Year] = 0),
            DISTINCTCOUNT('Physical Inventory'[PartNumber]), 0),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0)
)
```

### Physical Inventory Detail — Parts Not Counted (always included)

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER('Physical Inventory', 'Physical Inventory'[Is Part Uncounted This Year] = 1),
        "Part Number", 'Physical Inventory'[PartNumber],
        "Description", 'Physical Inventory'[Description],
        "Franchise", 'Physical Inventory'[Franchise],
        "Bin", 'Physical Inventory'[Bin],
        "Bin Qty", 'Physical Inventory'[BinQty],
        "On Hand Qty", 'Physical Inventory'[OnHandQty],
        "Stocktake Date", 'Physical Inventory'[StocktakeDate],
        "Date Created", 'Physical Inventory'[DateCreated]
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### MD Freight Detail (always included — added 2026-07-27)

Merged in from the standalone MD Freight flows' already-validated DAX
(see `projects/md invoices with no freight - report/docs/power-automate/POWER-AUTOMATE-SETUP.md`
for the full derivation, including the `ALLEXCEPT` row-context fix and the
`FORMAT()` int-to-string cast — both required and already baked into this
query). Threshold: `FreightBucket = "No Freight"` OR (`FreightBucket =
"Partial Freight"` AND `PctFreightDifference >= 0.10`), hardcoded 10%.

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        "Invoice #", FORMAT(Fact_MDInvoices_NoFreight[FileNumber], "0"),
        "RO #", FORMAT(Fact_MDInvoices_NoFreight[RONumber], "0"),
        "Order Date", Fact_MDInvoices_NoFreight[OrderDate],
        "Branch", Fact_MDInvoices_NoFreight[Branch],
        "Part Number", Fact_MDInvoices_NoFreight[PartNumber],
        "Order Qty", [Order Qty],
        "Sell Price 1", [Sell Price 1],
        "Unit Price", [Unit Price],
        "Weight", CALCULATE([Total Weight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "Actual Freight", CALCULATE([Actual Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "Calculated Freight", CALCULATE([Calculated Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "% Freight Difference", CALCULATE([% Freight Difference], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "Missed Freight", CALCULATE([Missed Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber]))
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### MD Freight Aggregate (always included — HTML KPI cards only, no CSV)

```dax
EVALUATE
ROW(
    "InvoicesFlagged", COALESCE(CALCULATE(
        DISTINCTCOUNT(Fact_MDInvoices_NoFreight[FileNumber]),
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0),
    "OpportunityDollars", COALESCE(CALCULATE(
        SUMX(
            VALUES(Fact_MDInvoices_NoFreight[FileNumber]),
            CALCULATE([Missed Freight])
        ),
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0)
)
```

The HTML body's "MD Freight — Missing or Under-Charged" section (turquoise,
`#0e8a9c`/`#e9f7f9`/`#a9dee4`) shows these two KPIs as a 45%/10%/45% card
pair, matching the existing Physical Inventory section's layout — added
right before the footer row.

---

## Branch 12 (O'Donnell) Bin Location Report

A separate, always-on mailing that runs **once, after the main `Apply to
each` loop finishes** — not per-recipient like everything else in this
flow. Sends a Bin Location CSV for Branch 12 (O'Donnell, the Combine Vault)
to two specific branches' staff: Ballinger and Abernathy. Previously
undocumented; added here 2026-07-27 after a bug in it (see below) was found
and fixed.

**Query** (uses the same `jdis_Part_Information` dataset as the main Bin
Location query, hardcoded to Branch 12 rather than the looping recipient's
branch):

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        jdis_Part_Information,
        "Part Number", jdis_Part_Information[PartNumber],
        "Description", jdis_Part_Information[Description],
        "Franchise", jdis_Part_Information[Franchise],
        "Bin", jdis_Part_Information[Bin],
        "Bin Qty", jdis_Part_Information[BinQty],
        "Sell Price", jdis_Part_Information[SellPrice1],
        "Cost", jdis_Part_Information[Cost],
        "On Hand Qty", jdis_Part_Information[QuantityOnhand]
    ),
    dim_BranchLocation[Branch] = "12 - O'Donnell"
)
```

Note the column reference is `QuantityOnhand` (lowercase "h"), inconsistent
with the main Bin Location query's `QuantityOnHand` — DAX column references
are case-insensitive so this works, but worth normalizing if this section is
ever rebuilt.

**Distribution:** filters the same SPI-PARTS member list already fetched by
`HTTP - Get Users` down to `officeLocation = 'Ballinger'` and
`officeLocation = 'Abernathy'` (two separate `Filter`/`Select` action pairs),
then sends one email per branch via the **Office 365 Outlook connector**
(`shared_office365`, `SendEmailV2`) — not the Graph API HTTP pattern the
rest of this flow uses. Subject: `Branch 12 (O'Donnell) Bin Location
Report`. Attachment: `Branch 12 Bin Location.csv`.

**Bug found and fixed (2026-07-27):** the live Orchestrator's last 3 weekly
runs (July 8, 15, 22) all showed status `Failed`, with the actual error
isolated to this section: `Send_Branch_12_Bin_Location_-_Ballinger` /
`InvalidTemplate` / `"The template function 'select' is not defined or not
valid."` — someone had used `select()` as an inline expression function,
which doesn't exist in Power Automate's workflow expression language (the
correct construct is a `Select` **action**, type `"Select"`). The main
per-recipient `Apply to each` loop reported `Succeeded` independently of
this failure, so the regular weekly emails were unaffected and continued
going out correctly — confirmed directly with Brian, not just inferred from
the run history. Brian fixed this himself before this documentation pass by
converting the broken inline expression into proper `Query` (Filter Array)
and `Select` actions, matching the working pattern already used elsewhere in
this repo's flows (e.g. `Compose_CurrentKeys` in the MD Freight daily
alert). Not yet confirmed by an actual live Wednesday run as of this
writing — first live run since the fix will be the real confirmation.

**Testing:** the "Parts Action Summary - Weekly Branch Email" test flow
also includes a safety-redirected copy of this section (added 2026-07-27) —
the real query/filter/select logic runs against live data, but both
`To` fields are hardcoded to `bfox@spitractor.com` instead of the real
Ballinger/Abernathy member lists, with the email body text stating who it
would have gone to in production. Use this to verify the fix without any
risk of it reaching real branch staff. Running it may prompt for Office 365
connection authorization the first time (new connector for this flow).

---

## Attachment Summary

| Attachment | Included When | Filename |
|---|---|---|
| Negative On Hand | NegOH count > 0 (changed 2026-07-27, was >= 10) | Negative_On_Hand.csv |
| No Bin Assigned | NoBin count > 0 (changed 2026-07-27, was >= 10) | On_Hand_No_Bin.csv |
| Open Tickets Aging | Aging count > 0 | Open_Tickets_Aging.csv |
| Outstanding Transfers | Always | Outstanding_Transfers.csv |
| Parts Adjustments | Any rows in last 7 days | Parts_Adjustments.csv |
| Bin Location | Always | Bin_Location.csv |
| Parts Not Counted | Always | Physical_Inventory_Not_Counted.csv |
| MD Freight (added 2026-07-27) | Always | MD_Freight_Missed.csv |

Pin Capture and Physical Inventory percentages appear in the HTML body only — no CSV attachment.
Branch 12 Bin Location is a separate, non-per-recipient mailing — see its own section above, not part of the per-branch AttachmentsJSON mechanism.

---

## Bin Location — Response Size Limit

The Power BI REST API returns approximately 82K rows maximum depending on column count and data size per row.

**Confirmed safe limit: 8 columns** (tested against Mesquite at 90,804 rows — the largest branch).

Current column set (confirmed 2026-04-27):
Part Number, Description, Franchise, Bin, Bin Qty, Sell Price, Cost, On Hand Qty

Branch row counts (largest to smallest):
Mesquite 90,804 → Brownfield 82,511 → Seminole 81,296 → Big Spring 71,807 →
Tornillo 71,703 → San Angelo 67,379 → Lorenzo 65,921 → Lamesa 64,882 →
Lubbock 53,877 → Slaton 53,576 → Abernathy 49,974 → Levelland 46,628 →
Morton 42,562 → Littlefield 39,789 → Snyder 38,969 → Denver City 34,203 →
Tahoka 30,588 → Ballinger 30,379 → Crosbyton 29,759

Do not add a 9th column without re-testing against Mesquite.

---

## Changing the Aging Threshold

Update in four places:
1. Aggregate DAX query in the flow: `Fact_Parts_Open_Tickets[Days_Open] >= 30` → new value
2. Aging detail DAX query in the flow: same filter line
3. `[Open Tickets Aging Count]` DAX measure: `_AgingThresholdDays = 30` → new value
4. `[Is Aging Ticket]` DAX measure: same constant

---

## Corp Managers — Future Work

Barry Sheets (Corporate North), Curt Summers (Corporate South), and Shannon Brooks
(Corporate North + South) were intentionally excluded from the initial launch.
Ben Hill is also TBD.

**2026-08-18 update:** Ben asked to receive every branch's alert across all
three flows (this one, Low Margin New Item Alert, MD Freight New Item
Alert), with Barry and Curt added scoped to the branch groups below. Rather
than either Option A or B below, a lighter-weight approach was used instead
— a conditional CC directly on the existing `HTTP_sendMail` action, no
SharePoint schema change, no change to the SKIP condition or `Get_items`
lookup. **This has been applied to Low Margin and MD Freight New Item Alert
already** (see their setup docs' "Corp Manager CC" sections for the exact
expression) **but NOT yet to this flow** — its definition (92 actions) is
too large to safely round-trip through the flowagent MCP tools without risk
of the truncated-fetch corrupting untouched sections on write-back. Add it
by hand in the Power Automate portal designer instead:

1. Open `Parts Action Summary - Orchestrator` in the flow designer
2. Navigate to the `HTTP_sendMail` action inside `Apply_to_each` → the
   `Condition_1` → `Condition - Should We Send` branch
3. In the message JSON body, add a `ccRecipients` field alongside the
   existing `toRecipients`, set to this expression (paste into the
   expression editor, not as literal text):
   ```
   if(contains(createArray('Lamesa','Littlefield','Levelland','Morton','Tahoka','Lorenzo','Slaton','Lubbock','Crosbyton','Abernathy'), variables('RecipientBranchName')), createArray(createObject('emailAddress', createObject('address', 'bhill@spitractor.com')), createObject('emailAddress', createObject('address', 'bsheets@spitractor.com'))), if(contains(createArray('Seminole','Tornillo','Denver City','Mesquite','San Angelo','Ballinger','Big Spring','Brownfield','Snyder'), variables('RecipientBranchName')), createArray(createObject('emailAddress', createObject('address', 'bhill@spitractor.com')), createObject('emailAddress', createObject('address', 'csummers@spitractor.com'))), createArray(createObject('emailAddress', createObject('address', 'bhill@spitractor.com')))))
   ```
4. Save, then test via the "Parts Action Summary - Weekly Branch Email"
   test flow before trusting the live Wednesday run
5. Also apply the same field/expression to the safety-redirected Branch 12
   section's sendMail calls only if Ben/Barry/Curt should see that mailing
   too — not done by default, since that section already goes to
   Ballinger/Abernathy staff specifically

Shannon Brooks was not part of this ask — left out of the CC expression
above. Add her the same way (a third branch check, or add her address
alongside Ben's if she should see everything) if/when needed.

The original two heavier-weight options are still documented below for
reference, worth revisiting only if several more corp-level recipients are
expected (the CC-expression approach gets unwieldy past 3-4 people):

**Option A — Flag columns on PartsBranchMapping**
Add CorpNorth (Yes/No) and CorpSouth (Yes/No) columns to the SharePoint list.
Each branch row gets flagged for which corp group it belongs to.
The flow queries "all rows where CorpNorth = Yes" for Barry, etc.
Still requires mapping each corp manager to their flag (via Azure AD or a second lookup).

**Option B — UserEmail column on PartsBranchMapping (preferred)**
Add a UserEmail column to the SharePoint list.
Change the flow's Get_items filter from OfficeLocation to UserEmail.
Add multiple rows per corp manager — one per branch they oversee.
Requires no Azure AD changes. Email is a more reliable unique key than officeLocation.
Requires populating UserEmail on all existing rows (one-time effort).

**Pre-populated rows for Option A (ready to add when decided):**

Corporate North branches (Barry): Lamesa, Littlefield, Levelland, Morton, Tahoka,
Lorenzo, Slaton, Lubbock, Crosbyton, Abernathy (10 branches)

Corporate South branches (Curt): Seminole, Tornillo, Denver City, Mesquite,
San Angelo, Ballinger, Big Spring, Brownfield, Snyder (9 branches)

Shannon Brooks: all 19 branches (Corporate North + South combined)

The nested loop flow change required: remove `$top:1` from Get_items, wrap all
email logic in a second Apply_to_each on the Get_items results.

---

## Testing a Single Branch

Use the child flow (Parts Action Summary - Weekly Branch Email) for single-branch testing.
It accepts 4 manual inputs: RecipientName, RecipientBranchName, RecipientBranchFilter, RecipientEmail.
Enter values directly and run — no loop, no SharePoint lookup needed.

As of 2026-07-27, this test flow also includes the full MD Freight
KPI/CSV/HTML content (same as the live Orchestrator, safe to test with any
real branch's data) and a safety-redirected copy of the Branch 12 Bin
Location section (see that section above) that sends only to
`bfox@spitractor.com`, never real branch staff, regardless of which
Ballinger/Abernathy members actually exist. Fixed the same hardcoded
`213`/`56`/`55` KPI-card leftover this test flow previously had — it now
correctly reads live `outputs('NegOH')`/`outputs('NoBin')`/`outputs('Aging')`
like the Orchestrator always did.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Email not received | Flow run failed or member skipped | Check Power Automate run history. Verify officeLocation is set and matches a PartsBranchMapping row |
| HTTP - Get Users fails 401 | App registration secret expired | Azure → App registrations → Parts Action Dashboard Email → Certificates & secrets → new secret → update HTTP - Get Users auth |
| sendMail HTTP fails 401 | App registration secret expired | Same fix — update the sendMail HTTP action auth |
| sendMail HTTP fails 403 | Mail.Send permission revoked | Azure → App registrations → API permissions → re-grant admin consent |
| Member gets no email | No PartsBranchMapping row for their officeLocation | Add a row to the SharePoint list matching their exact Azure AD officeLocation value |
| Wrong branch data in email | BranchFilter value mismatch | Verify PartsBranchMapping BranchFilter matches dim_BranchLocation[Branch] exactly — format is "## - BranchName" e.g. "2 - Tornillo" |
| Bin Location CSV truncated | Response size limit hit | 8 columns is the confirmed limit for Mesquite (90,804 rows). Do not add columns |
| AttachmentsJSON empty | All conditional thresholds missed | Transfers, Bin Location, and MD Freight are always included — if still empty, check those three queries |
| Corp manager receives wrong branch data | officeLocation maps to single branch row | Corp managers not yet wired — see Corp Managers section above |
| Whole run shows `Failed` but branch managers still got their email | A failure in the once-only Branch 12 section (after `Apply to each`) doesn't affect the per-recipient loop, which completes and reports `Succeeded` independently | Check `Send_Branch_12_Bin_Location_-_Ballinger`/`-_Abernathy` specifically in run history; don't assume the whole send failed |
| `'select' is not defined or not valid` error | Someone used `select()` as an inline expression function — it doesn't exist in Power Automate's expression language | Replace with a proper `Select` action (type `"Select"`) plus a `Query`/Filter Array action, matching `Filter_-_Ballinger_Users`/`Select_-_Ballinger_Emails` |
| MD Freight section shows wrong/varying numbers across an invoice's rows | Missing `ALLEXCEPT` wrap on the freight measure calls in the MD Freight detail query | See `projects/md invoices with no freight - report/docs/power-automate/POWER-AUTOMATE-SETUP.md` gotcha #2 |
