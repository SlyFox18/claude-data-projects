# dim_BranchUserAccess — Setup Instructions

## What This Is
The `branch-user-access-seed.csv` file is the source of truth for who can access the
Parts Action Dashboard and what branch they see. It drives both RLS in Power BI and
the recipient list for the daily Power Automate email.

## Before Uploading to Fabric

1. Replace ALL `[manager-email]` placeholders with real Microsoft 365 email addresses
2. Replace ALL `[FirstName]` placeholders with the manager's first name (used in email greeting)
3. Replace ALL `[corp-parts-manager-email]`, `[jd-manager-1-email]`, etc. with real emails
4. Investigate the BranchCode 4 anomaly: two entries in dim_BranchLocation share BranchCode 4
   (Las Cruces and Mesquite). Confirm with Corp Parts Manager whether:
   - Both cities are managed by the same person (one row with BranchCode 04 covers both), OR
   - Mesquite has its own manager and needs its own LocationID and row

## Column Reference

| Column | Format | Example | Notes |
|---|---|---|---|
| UserEmail | Microsoft 365 UPN | john.smith@spitractor.com | Must match exactly — RLS uses USERPRINCIPALNAME() |
| BranchCode | LocationID (zero-padded) or ALL | 01 | ALL = corp manager, no branch filter |
| BranchName | Text label | Seminole | Used for display only |
| FirstName | First name only | John | Used in email greeting "Good morning, John" |
| IsCorpManager | TRUE or FALSE | FALSE | TRUE = excluded from daily email, accesses report directly |

## How to Upload to Fabric

1. Open `LH_Master_Data` in the Fabric portal
2. Navigate to Files section
3. Upload this CSV to `Files/reference/branch-user-access-seed.csv`
4. Create Dataflow Gen2: `df_BranchUserAccess`
   - Source: Lakehouse Files → reference/branch-user-access-seed.csv
   - Column types: UserEmail=Text, BranchCode=Text, BranchName=Text, FirstName=Text, IsCorpManager=True/False
   - Destination: Lakehouse table `dim_BranchUserAccess`, Update method: Replace
5. Run the dataflow and validate:
```sql
SELECT * FROM dim_BranchUserAccess ORDER BY IsCorpManager DESC, BranchCode
```

## How to Add a New User Later

Add one row to this CSV with the correct UserEmail, BranchCode, BranchName, FirstName, and IsCorpManager.
Re-upload the CSV to Fabric Files and re-run the `df_BranchUserAccess` dataflow.
No changes needed to the Power BI report or Power Automate flow.
