# Power Automate Flow Setup Guide
## Parts Action Dashboard — Daily Branch Email

---

## Flow Overview

| Setting | Value |
|---|---|
| Flow name | Parts Action Dashboard - Daily Branch Email |
| Trigger | Scheduled — 7:00 AM Central Time, Mon–Fri |
| Recipient source | `dim_BranchUserAccess` WHERE IsCorpManager = FALSE |
| Data source | LH_Master_Data SQL endpoint (Fabric) |
| Email service | Office 365 Outlook connector |

---

## SQL Endpoint Connection

Server: `xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com`
Database: `LH_Master_Data`

---

## Flow Structure

```
Trigger: Recurrence (7:00 AM Mon-Fri Central)
│
├── Action: Get rows from dim_BranchUserAccess (WHERE IsCorpManager = false)
│
└── Apply to each: [row from dim_BranchUserAccess]
    │
    ├── Action: Run SQL query — Negative On Hand + No Bin counts
    │   Query:
    │   SELECT
    │       SUM(CASE WHEN HasNegativeBinQty = 1 THEN 1 ELSE 0 END) AS NegativeOnHandCount,
    │       SUM(CASE WHEN HasBinQtyNoBin = 1 THEN 1 ELSE 0 END)    AS OnHandNoBinCount
    │   FROM Fact_NegativeOnHand_OnHandNoBin
    │   WHERE Branch = @BranchCode
    │   (Replace @BranchCode with dynamic content: BranchCode from current row)
    │
    ├── Action: Run SQL query — Open Tickets Aging count
    │   Query:
    │   SELECT COUNT(DISTINCT Order_No) AS OpenTicketsAgingCount
    │   FROM Fact_Parts_Open_Tickets
    │   WHERE Location = @BranchCode
    │     AND (Days_Open >= 30 OR [#_On_Back_Order] > 0)
    │   (Replace @BranchCode with dynamic content: BranchCode from current row)
    │
    ├── Condition: Are all counts = 0?
    │   ├── YES → Send all-clear email (green variant)
    │   └── NO  → Send action items email (counts variant)
    │
    └── Action: Send email (Office 365 Outlook)
        To: [UserEmail from current row]
        Subject: Parts Action Summary — [BranchName] — [formatted date]
        Body: [HTML template — see Email Templates section below]
```

---

## Email Templates

### Counts Variant (used when any count > 0)

```html
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0">
<tr><td align="center" style="padding:24px 16px">
<table width="560" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:8px;overflow:hidden">
  <tr><td style="background:#1e3a5f;padding:20px 24px">
    <p style="margin:0;color:#fff;font-size:18px;font-weight:bold">Parts Action Summary</p>
    <p style="margin:4px 0 0;color:#94b8d8;font-size:13px">@{items('Apply_to_each')?['BranchName']} &nbsp;·&nbsp; @{formatDateTime(utcNow(), 'MMMM d, yyyy')}</p>
    <p style="margin:4px 0 0;color:#94b8d8;font-size:12px">Good morning, @{items('Apply_to_each')?['FirstName']}</p>
  </td></tr>
  <tr><td style="padding:20px 24px">
    <p style="margin:0 0 12px;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.05em">Items Needing Attention Today</p>
    <table width="100%" cellpadding="0" cellspacing="0"><tr>
      <td width="31%" style="background:#fff5f5;border:1px solid #fecaca;border-radius:6px;padding:12px;text-align:center">
        <p style="margin:0;font-size:28px;font-weight:bold;color:#dc2626">@{body('Run_Neg_OH_query')?['ResultSets']['Table1'][0]['NegativeOnHandCount']}</p>
        <p style="margin:4px 0 0;font-size:11px;color:#991b1b">Negative<br>On Hand</p>
      </td>
      <td width="4%"></td>
      <td width="31%" style="background:#fff7ed;border:1px solid #fed7aa;border-radius:6px;padding:12px;text-align:center">
        <p style="margin:0;font-size:28px;font-weight:bold;color:#ea580c">@{body('Run_Neg_OH_query')?['ResultSets']['Table1'][0]['OnHandNoBinCount']}</p>
        <p style="margin:4px 0 0;font-size:11px;color:#9a3412">No Bin<br>Assigned</p>
      </td>
      <td width="4%"></td>
      <td width="31%" style="background:#fefce8;border:1px solid #fef08a;border-radius:6px;padding:12px;text-align:center">
        <p style="margin:0;font-size:28px;font-weight:bold;color:#ca8a04">@{body('Run_Tickets_query')?['ResultSets']['Table1'][0]['OpenTicketsAgingCount']}</p>
        <p style="margin:4px 0 0;font-size:11px;color:#854d0e">Open Tickets<br>Aging</p>
      </td>
    </tr></table>
  </td></tr>
  <tr><td style="padding:0 24px 24px;text-align:center">
    <a href="[PASTE_PAGE2_URL_HERE]" style="display:inline-block;background:#1e3a5f;color:#fff;text-decoration:none;padding:12px 32px;border-radius:6px;font-size:14px;font-weight:bold">View My Action Items →</a>
    <p style="margin:8px 0 0;font-size:11px;color:#94a3b8">Opens directly to your branch in Power BI</p>
  </td></tr>
  <tr><td style="background:#f8fafc;padding:12px 24px;text-align:center;border-top:1px solid #e2e8f0">
    <p style="margin:0;font-size:11px;color:#94a3b8">Sent daily at 7:00 AM · Parts Action Dashboard · South Plains Implement</p>
    <p style="margin:4px 0 0;font-size:11px;color:#94a3b8">Questions? Contact bfox@spitractor.com</p>
  </td></tr>
</table>
</td></tr>
</table>
</body>
</html>
```

### All-Clear Variant (used when all counts = 0)

Replace the KPI cards `<tr>` block above with:

```html
  <tr><td style="padding:20px 24px">
    <p style="margin:0;background:#f0fdf4;border-radius:6px;padding:16px;font-size:14px;color:#166534;text-align:center">
      ✅ No action items today — your branch is in good shape!
    </p>
  </td></tr>
```

Keep all other sections (header, button, footer) identical.

---

## Key Variables

| Variable | Source | Usage |
|---|---|---|
| `[PASTE_PAGE2_URL_HERE]` | Copy from browser after publishing report | Replace in both email templates |
| `BranchCode` | dim_BranchUserAccess row | SQL WHERE clause parameter |
| `BranchName` | dim_BranchUserAccess row | Email header |
| `FirstName` | dim_BranchUserAccess row | Email greeting |
| `UserEmail` | dim_BranchUserAccess row | Send email To: field |

---

## Adding a New Recipient

1. Add a row to `branch-user-access-seed.csv` with the correct email, BranchCode, BranchName, FirstName, IsCorpManager
2. Re-upload to Fabric Files (`Files/reference/`)
3. Re-run the `df_BranchUserAccess` dataflow
4. No changes to the flow itself — it reads the table dynamically

## Adding a New Metric to the Email

1. Add a new SQL query action in the flow for the new metric
2. Add a new KPI card `<td>` block to the HTML template (copy the existing pattern)
3. Update the all-clear `Condition` to also check the new metric count = 0
4. Update the all-clear email variant subject line if needed

## Changing the Aging Threshold

Update in three places:
1. SQL query in the flow: `Days_Open >= 30` → new value
2. `[Open Tickets Aging Count]` DAX measure: `_AgingThresholdDays = 30` → new value
3. `[Is Aging Ticket]` DAX measure: same constant
4. Page 2 visual title: "Open Tickets Aging (30+ Days or Backordered)" → update label

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Email not received | Flow run failed | Check Power Automate run history for errors |
| Wrong counts in email | SQL query not matching DAX | Verify SQL WHERE clause matches fact table branch key format |
| RLS not working after clicking email link | User email not in dim_BranchUserAccess | Add/correct their row in the seed CSV, re-run dataflow |
| All managers see all branches | CorpManager role applied instead of BranchManager | Check role assignment in Fabric semantic model security settings |
| "0" appears in email instead of real count | SQL result format mismatch | Check Power Automate expression path: `body('action_name')?['ResultSets']['Table1'][0]['ColumnName']` |
