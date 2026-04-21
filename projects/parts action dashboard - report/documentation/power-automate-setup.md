# Power Automate Flow Setup Guide
## Parts Action Dashboard — Branch Email

---

## Flow Overview

| Setting | Value |
|---|---|
| Flow name | Parts Action Dashboard - Daily Branch Email |
| Trigger | Manual (schedule TBD — pending Ben's approval) |
| Recipient source | `dim_BranchUserAccess` WHERE IsCorpManager = FALSE |
| Data source | LH_Master_Data — Power BI REST API (DAX queries) |
| Email service | Microsoft Graph API via plain HTTP connector |

---

## Architecture Decision

The email is sent via the **Microsoft Graph API** (`/v1.0/users/bfox@spitractor.com/sendMail`) using Power Automate's plain HTTP connector with Active Directory OAuth authentication. This approach was chosen over the Office 365 Outlook connector because:

- The Outlook connector rejects dynamic arrays in the attachments field (InternalServerError)
- The Graph API approach supports fully dynamic attachments — adding a new metric requires no structural changes to the email step
- Scales to 10+ metrics without rebuilding the flow

---

## Azure App Registration

An app registration named **"Parts Action Dashboard Email"** was created in Microsoft Entra ID to authenticate the Graph API call.

| Setting | Value |
|---|---|
| App name | Parts Action Dashboard Email |
| Tenant | spitractor.com |
| Permission | Microsoft Graph → Mail.Send (Application) |
| Admin consent | Granted |
| Secret expiry | April 2028 (24 months from creation) |

To find the Client ID and Tenant ID: Azure Portal → Microsoft Entra ID → App registrations → Parts Action Dashboard Email → Overview.

**Important:** The client secret expires April 2028. Before that date, go to Certificates & secrets → create a new secret → update the HTTP action authentication in the flow.

---

## Power BI REST API Connection

Dataset queries use the Power BI REST API (Run a query against a dataset action).

| Setting | Value |
|---|---|
| Workspace | RP - Sandbox (dev) / RP - Parts Reports (production) |
| Dataset | Parts Action Dashboard |

---

## Power BI Report URL

Page 2 (Branch Action Items) direct link — used in the "View My Action Items" button:

```
https://app.powerbi.com/groups/ba9d8de4-ef13-44e6-9156-e23a2511f3ad/reports/cb9176a3-6ef9-46bf-bafc-cc45ccc0368a/b57fa641072c9323ed1a?experience=power-bi
```

Update this URL after promoting to production workspace.

---

## Flow Structure

```
Trigger: Manual (change to Recurrence when schedule approved)
│
├── Action: Run a query against a dataset (aggregate counts)
│   DAX:
│   EVALUATE ROW(
│       "NegOH", CALCULATE(COUNTROWS(Fact_NegativeOnHand_OnHandNoBin),
│           Fact_NegativeOnHand_OnHandNoBin[HasNegativeBinQty] = TRUE(),
│           dim_BranchLocation[Branch] = "2 - Tornillo"),
│       "NoBin", CALCULATE(COUNTROWS(Fact_NegativeOnHand_OnHandNoBin),
│           Fact_NegativeOnHand_OnHandNoBin[HasBinQtyNoBin] = TRUE(),
│           dim_BranchLocation[Branch] = "2 - Tornillo"),
│       "Aging", CALCULATE(DISTINCTCOUNT(Fact_Parts_Open_Tickets[Order_No]),
│           Fact_Parts_Open_Tickets[Days_Open] >= 30,
│           dim_BranchLocation[Branch] = "2 - Tornillo")
│   )
│
├── Action: Parse JSON (extract counts from query result)
│
├── Compose: NegOH — extracts NegOH count
├── Compose: NoBin — extracts NoBin count
├── Compose: Aging — extracts Aging count
│
├── Initialize variable: Attachments (Array, empty)
├── Initialize variable: NegOHCSV (String, empty)
├── Initialize variable: NoBinCSV (String, empty)
├── Initialize variable: AgingCSV (String, empty)
├── Initialize variable: AttachmentsJSON (String, empty)
│
├── Condition - NegOH: int(outputs('NegOH')) >= 10
│   └── TRUE:
│       ├── Run a query (NegOH detail — CALCULATETABLE)
│       ├── Create CSV table
│       ├── Set variable: NegOHCSV = body('Create_CSV_table')
│       ├── Append to string variable: AttachmentsJSON
│       │   concat(',{"@odata.type":"#microsoft.graph.fileAttachment",
│       │       "name":"Negative_On_Hand.csv","contentBytes":"',
│       │       base64(body('Create_CSV_table')),'"}')
│       └── Append to array variable: Attachments
│
├── Condition - NoBin: int(outputs('NoBin')) >= 10
│   └── TRUE:
│       ├── Run a query (NoBin detail — CALCULATETABLE)
│       ├── Create CSV table 1
│       ├── Set variable: NoBinCSV = body('Create_CSV_table_1')
│       ├── Append to string variable: AttachmentsJSON
│       │   concat(',{"@odata.type":"#microsoft.graph.fileAttachment",
│       │       "name":"On_Hand_No_Bin.csv","contentBytes":"',
│       │       base64(body('Create_CSV_table_1')),'"}')
│       └── Append to array variable 1: Attachments
│
├── Condition - Aging: int(outputs('Aging')) > 0
│   └── TRUE:
│       ├── Run a query (Aging detail — CALCULATETABLE)
│       ├── Create CSV table 2
│       ├── Set variable: AgingCSV = body('Create_CSV_table_2')
│       ├── Append to string variable: AttachmentsJSON
│       │   concat(',{"@odata.type":"#microsoft.graph.fileAttachment",
│       │       "name":"Open_Tickets_Aging.csv","contentBytes":"',
│       │       base64(body('Create_CSV_table_2')),'"}')
│       └── Append to array variable 2: Attachments
│
└── Condition - Should We Send: length(variables('Attachments')) > 0
    └── TRUE:
        ├── Compose: concat('[',substring(variables('AttachmentsJSON'),1),']')
        │   Builds the final JSON array of attachment objects
        │
        ├── Compose: HTML Body
        │   Built in text mode with 5 HTML segments and 4 dynamic expressions:
        │   Segment 1 → formatDateTime(utcNow(),'MMMM d, yyyy') →
        │   Segment 2 → outputs('NegOH') →
        │   Segment 3 → outputs('NoBin') →
        │   Segment 4 → outputs('Aging') →
        │   Segment 5
        │
        └── HTTP (Graph API sendMail)
            Method: POST
            URI: https://graph.microsoft.com/v1.0/users/bfox@spitractor.com/sendMail
            Auth: Active Directory OAuth (Parts Action Dashboard Email app)
            Body expression:
            concat('{"message":{"subject":"Parts Action Summary - [Branch] - ',
                formatDateTime(utcNow(),'MMMM d, yyyy'),
                '","body":{"contentType":"HTML","content":"',
                replace(outputs('HTML_Body'),'"','\"'),
                '"},"toRecipients":[{"emailAddress":{"address":"[email]"}}],
                "attachments":',outputs('Compose'),'}}')
```

---

## DAX Detail Queries (CALCULATETABLE Pattern)

All three detail queries follow the same pattern — CALCULATETABLE filters via
dim_BranchLocation relationship, which propagates to the fact table correctly.
Direct FILTER on the fact table branch column does NOT work (stores sub-branch
suffixes like "02I", "02S", not the display name).

### NegOH Detail
```
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
    dim_BranchLocation[Branch] = "2 - Tornillo"
)
```

### NoBin Detail
```
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
    dim_BranchLocation[Branch] = "2 - Tornillo"
)
```

### Aging Detail
```
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
    dim_BranchLocation[Branch] = "2 - Tornillo"
)
```

---

## Attachment Thresholds

| Metric | Threshold | Attachment Name |
|---|---|---|
| Negative On Hand | Count >= 10 | Negative_On_Hand.csv |
| No Bin Assigned | Count >= 10 | On_Hand_No_Bin.csv |
| Open Tickets Aging | Count > 0 | Open_Tickets_Aging.csv |

Email only sends if at least one threshold is crossed (Should We Send condition).
Each attachment is only included if its threshold is met — any combination of
1, 2, or 3 attachments is handled automatically by the AttachmentsJSON variable.

---

## Adding a New Metric

This is the key scalability feature. Adding metric #4 (or #10) requires the same
steps every time — nothing inside "Should We Send" needs to change.

1. Add a new **Condition** at the main flow level (after the existing 3 conditions):
   - Expression: `int(outputs('NewMetricCompose')) >= [threshold]`

2. Inside the True branch add these steps in order:
   - **Run a query** — DAX CALCULATETABLE for the detail rows
   - **Create CSV table** — converts query result to CSV
   - **Set variable** — store CSV: `body('Create_CSV_table_N')`
   - **Append to string variable** — AttachmentsJSON:
     ```
     concat(',{"@odata.type":"#microsoft.graph.fileAttachment",
         "name":"New_Metric.csv","contentBytes":"',
         base64(body('Create_CSV_table_N')),'"}')
     ```
   - **Append to array variable** — Attachments (any value — just tracks threshold was met)

3. Add the new count to the aggregate DAX query at the top of the flow (add a new
   column to the ROW() expression)

4. Add a new Compose step to extract the new count from the Parse JSON result

5. Add a new KPI card `<td>` block to the HTML Body compose (copy the existing pattern)

That's it. The email sending step handles any number of attachments automatically.

---

## Adding a New Recipient

1. Add a row to `branch-user-access-seed.csv`
2. Re-upload to Fabric Files (`Files/reference/`)
3. Re-run the `df_BranchUserAccess` dataflow
4. No flow changes needed — the branch loop reads the table dynamically

---

## Changing the Aging Threshold

Update in three places:
1. Aggregate DAX query in the flow: `Fact_Parts_Open_Tickets[Days_Open] >= 30` → new value
2. Detail DAX query in the flow: same filter line
3. `[Open Tickets Aging Count]` DAX measure: `_AgingThresholdDays = 30` → new value
4. `[Is Aging Ticket]` DAX measure: same constant

---

## TODO — Remaining Before Full Launch

- [ ] Switch trigger from Manual to Recurrence (schedule TBD — pending Ben approval)
- [ ] Build branch loop — wrap flow in Apply to each from dim_BranchUserAccess
- [ ] Replace hardcoded "2 - Tornillo" / "Tornillo" / recipient email with dynamic values from loop
- [ ] Update Power BI URL after promoting report to production workspace
- [ ] Validate RLS — confirm each manager only sees their branch after clicking button
- [ ] Test edge cases — branches where NegOH < 10, NoBin < 10, or Aging = 0

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Email not received | Flow run failed | Check Power Automate run history for errors |
| HTTP step fails with 401 Unauthorized | App registration secret expired | Go to Azure → App registrations → Parts Action Dashboard Email → Certificates & secrets → create new secret → update HTTP action authentication |
| HTTP step fails with 403 Forbidden | Mail.Send permission revoked | Go to Azure → App registrations → Parts Action Dashboard Email → API permissions → re-grant admin consent |
| Attachments empty or missing data | CALCULATETABLE branch filter wrong | Verify dim_BranchLocation[Branch] value matches exactly — format is "## - BranchName" e.g. "02 - Tornillo" |
| AttachmentsJSON is empty / substring error | None of the 3 threshold conditions fired | Check that outer conditions (NegOH/NoBin/Aging) are evaluating correctly and Append to string variable steps exist in each True branch |
| Wrong counts in email | DAX aggregate query filter | Verify dim_BranchLocation[Branch] value in aggregate query matches the branch exactly |
| RLS not working after clicking button | User email not in dim_BranchUserAccess | Add/correct their row in the seed CSV, re-run dataflow |
| "Compose" action not found in HTTP body | Compose was renamed or deleted | Check the Compose step name inside Should We Send True branch — update outputs() reference to match |
