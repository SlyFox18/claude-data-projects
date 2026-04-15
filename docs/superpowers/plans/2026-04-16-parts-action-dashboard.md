# Parts Action Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Power BI report that surfaces daily parts action items to ~20 branch managers (filtered by RLS) and a roll-up view to 4 corp-level managers, paired with a Power Automate daily email.

**Architecture:** One PBIP report with two pages and two RLS roles. A new `dim_BranchUserAccess` Lakehouse table maps user emails to branch codes (or ALL). Corp managers land on Page 1 (all-branch summary); branch managers land on Page 2 (their branch action items) via a direct link from the daily email. Power Automate queries branch counts each morning and sends personalized HTML emails.

**Tech Stack:** Power BI Desktop (PBIP format), Fabric Lakehouse (SQL endpoint), TMDL for semantic model, Power Automate (scheduled cloud flow), Dataflow Gen2 (dim_BranchUserAccess load)

**Spec:** `docs/superpowers/specs/2026-04-16-parts-action-dashboard-design.md`

---

## Source Tables (confirmed in LH_Master_Data)

| Table | Branch Key | Key Columns Used |
|---|---|---|
| `Fact_NegativeOnHand_OnHandNoBin` | `Branch` (verify format — may be BranchID e.g. "1", "1I", "1S") | `HasNegativeBinQty`, `HasBinQtyNoBin`, `PartNumber`, `Description`, `BinQty`, `QuantityOnHand`, `IssueType` |
| `Fact_Parts_Open_Tickets` | `Location` (verify format — likely LocationID e.g. "01") | `Days_Open`, `Aging`, `#_On_Back_Order`, `Order_No`, `Customer`, `Salesman`, `Order_Total_$$` |

> **Branch key note — IMPORTANT:** `dim_BranchUserAccess.BranchCode` stores the **LocationID** (zero-padded 2-char code: "01", "02", etc.). There are **22 locations** confirmed. Sub-branches exist with suffixes I/S/C/B (e.g. "1I" = Inventory, "1S" = Service, "1C" = Combine/Vault) — RLS must filter at the **dim_BranchLocation level** (by LocationID) and let the model relationship propagate to sub-branches. Do NOT filter directly on the fact table Branch column as it would miss sub-branches.
>
> ⚠️ **BranchCode 4 anomaly:** Two entries share BranchCode 4 in dim_BranchLocation (Las Cruces and Mesquite). Investigate whether LocationID 04 covers both locations or if Mesquite has its own LocationID. Resolve before populating dim_BranchUserAccess.

## Confirmed Locations (22 total)

| LocationID | BranchCode | Location Name |
|---|---|---|
| 01 | 1 | Seminole |
| 02 | 2 | Tornillo |
| 03 | 3 | Denver City |
| 04 | 4 | Las Cruces / Mesquite (⚠️ verify) |
| 05 | 5 | Deming |
| 06 | 6 | San Angelo |
| 07 | 7 | Ballinger |
| 08 | 8 | Big Spring |
| 11 | 11 | Brownfield |
| 12 | 12 | O'Donnell |
| 13 | 13 | Lamesa |
| 14 | 14 | Littlefield |
| 15 | 15 | Levelland |
| 16 | 16 | Morton |
| 17 | 17 | Tahoka |
| 91 | 91 | Lorenzo |
| 92 | 92 | Slaton |
| 93 | 93 | Lubbock |
| 94 | 94 | Crosbyton |
| 95 | 95 | Abernathy |
| 96 | 96 | Snyder |
| 97 | 97 | Colorado City |

> **Aging threshold:** Default threshold for "Open Tickets Aging" is `Days_Open >= 30` OR `#_On_Back_Order > 0`. Confirm with Corp Parts Manager before going live — this is the DAX constant `_AgingThresholdDays = 30` defined in the measure.

---

## File Structure

```
projects/parts action dashboard - report/
├── CLAUDE.md                                          ← project context file
├── reports/
│   └── current/
│       ├── Parts Action Dashboard.pbip               ← PBIP project file
│       ├── Parts Action Dashboard.Report/
│       │   ├── .platform
│       │   ├── definition.pbir
│       │   └── definition/
│       │       ├── report.json
│       │       ├── version.json
│       │       └── pages/
│       │           ├── pages.json
│       │           ├── [page1-id]/                   ← Branch Summary (corp)
│       │           │   ├── page.json
│       │           │   └── visuals/
│       │           └── [page2-id]/                   ← Branch Action Items
│       │               ├── page.json
│       │               └── visuals/
│       └── Parts Action Dashboard.SemanticModel/
│           ├── .platform
│           ├── definition.pbism
│           ├── diagramLayout.json
│           └── definition/
│               ├── database.tmdl
│               ├── model.tmdl
│               ├── relationships.tmdl
│               └── tables/
│                   ├── _Measures.tmdl               ← all DAX measures
│                   ├── dim_BranchUserAccess.tmdl    ← new RLS mapping table
│                   ├── dim_BranchLocation.tmdl      ← shared dimension
│                   ├── Fact_NegativeOnHand_OnHandNoBin.tmdl
│                   ├── Fact_Parts_Open_Tickets.tmdl
│                   └── Data Refresh.tmdl
└── documentation/
    └── power-automate-setup.md                       ← flow setup guide
```

---

## Task 1: Verify Branch Codes and Scaffold Project Folder

**Files:**
- Create: `projects/parts action dashboard - report/CLAUDE.md`

- [ ] **Step 1: Verify branch codes in dim_BranchLocation**

Open Power BI Desktop with any existing report connected to LH_Master_Data. Run this DAX in Performance Analyzer or use `pbi dax execute`:

```dax
EVALUATE
SELECTCOLUMNS(
    DISTINCT(
        SELECTCOLUMNS(dim_BranchLocation, "BranchCode", dim_BranchLocation[Branch])
    ),
    "BranchCode", [BranchCode]
)
ORDER BY [BranchCode]
```

Expected: A list of 2-char numeric codes (e.g. "01", "02", ... "20"). Write these down — you need them for the `dim_BranchUserAccess` seed CSV in Task 2.

- [ ] **Step 2: Create the project folder structure**

```bash
mkdir -p "projects/parts action dashboard - report/reports/current"
mkdir -p "projects/parts action dashboard - report/documentation"
```

- [ ] **Step 3: Create CLAUDE.md**

Write `projects/parts action dashboard - report/CLAUDE.md`:

```markdown
# Parts Action Dashboard

## Purpose
Daily action item dashboard for branch-level parts managers and corp-level parts staff.

## Audience
- Corp managers (4): see all branches — RLS role: CorpManager
- Branch managers (~20): see own branch only — RLS role: BranchManager

## Source Tables (LH_Master_Data)
- Fact_NegativeOnHand_OnHandNoBin — branch key: Branch
- Fact_Parts_Open_Tickets — branch key: Location
- dim_BranchUserAccess — RLS mapping (UserEmail → BranchCode or ALL)
- dim_BranchLocation — branch names and metadata

## RLS
dim_BranchUserAccess maps USERPRINCIPALNAME() to a BranchCode.
BranchCode = 'ALL' bypasses branch filter (corp managers).

## Aging Threshold
Open Tickets flagged when Days_Open >= 30 OR #_On_Back_Order > 0.
Confirm threshold with Corp Parts Manager before go-live.

## Extensibility
Each action category = 1 KPI card + 1 detail table + 1 measure + 1 email card.
To add a new category: add the source table, write 1 measure, add visuals to both pages, add one card to the Power Automate email template.

## Spec
docs/superpowers/specs/2026-04-16-parts-action-dashboard-design.md
```

- [ ] **Step 4: Commit scaffold**

```bash
git add "projects/parts action dashboard - report/"
git commit -m "feat(parts-action-dashboard): scaffold project folder and CLAUDE.md"
```

---

## Task 2: Create dim_BranchUserAccess Lakehouse Table

**Files:**
- Create: `projects/parts action dashboard - report/documentation/branch-user-access-seed.csv`

This table drives all RLS filtering and the Power Automate email recipient loop. It must exist in LH_Master_Data before the semantic model can be built.

- [ ] **Step 1: Create the seed CSV**

Write `projects/parts action dashboard - report/documentation/branch-user-access-seed.csv`:

```csv
UserEmail,BranchCode,BranchName,FirstName,IsCorpManager
bfox@spitractor.com,ALL,All Branches,Brian,TRUE
[corp-parts-manager-email],ALL,All Branches,[FirstName],TRUE
[jd-manager-1-email],ALL,All Branches,[FirstName],TRUE
[jd-manager-2-email],ALL,All Branches,[FirstName],TRUE
[non-jd-manager-email],ALL,All Branches,[FirstName],TRUE
[manager-email],01,Seminole,[FirstName],FALSE
[manager-email],02,Tornillo,[FirstName],FALSE
[manager-email],03,Denver City,[FirstName],FALSE
[manager-email],04,Las Cruces,[FirstName],FALSE
[manager-email],05,Deming,[FirstName],FALSE
[manager-email],06,San Angelo,[FirstName],FALSE
[manager-email],07,Ballinger,[FirstName],FALSE
[manager-email],08,Big Spring,[FirstName],FALSE
[manager-email],11,Brownfield,[FirstName],FALSE
[manager-email],12,O'Donnell,[FirstName],FALSE
[manager-email],13,Lamesa,[FirstName],FALSE
[manager-email],14,Littlefield,[FirstName],FALSE
[manager-email],15,Levelland,[FirstName],FALSE
[manager-email],16,Morton,[FirstName],FALSE
[manager-email],17,Tahoka,[FirstName],FALSE
[manager-email],91,Lorenzo,[FirstName],FALSE
[manager-email],92,Slaton,[FirstName],FALSE
[manager-email],93,Lubbock,[FirstName],FALSE
[manager-email],94,Crosbyton,[FirstName],FALSE
[manager-email],95,Abernathy,[FirstName],FALSE
[manager-email],96,Snyder,[FirstName],FALSE
[manager-email],97,Colorado City,[FirstName],FALSE
```

> Replace all `[bracketed]` placeholders with real values before uploading. `FirstName` is used in the email greeting. `IsCorpManager = TRUE` users do not receive the daily branch email — they use the report directly. Note: LocationID 04 (Mesquite/Las Cruces anomaly) — confirm whether Mesquite needs its own row before finalizing.

- [ ] **Step 2: Upload CSV to Fabric Lakehouse**

1. Open `LH_Master_Data` in the Fabric portal
2. Navigate to Files section
3. Upload `branch-user-access-seed.csv` to `Files/reference/`

- [ ] **Step 3: Create Dataflow Gen2 to load the table**

1. In LH_Master_Data, create a new Dataflow Gen2
2. Name it: `df_BranchUserAccess`
3. Get Data → Lakehouse → Files → `reference/branch-user-access-seed.csv`
4. Verify column types:
   - `UserEmail`: Text
   - `BranchCode`: Text
   - `BranchName`: Text
   - `FirstName`: Text
   - `IsCorpManager`: True/False (logical)
5. Add data destination → Lakehouse → `LH_Master_Data` → new table: `dim_BranchUserAccess`
6. Update method: Replace
7. Save and run the dataflow

- [ ] **Step 4: Validate the table loaded correctly**

In the Lakehouse SQL endpoint, run:

```sql
SELECT * FROM dim_BranchUserAccess ORDER BY IsCorpManager DESC, BranchCode
```

Expected: All rows from the CSV, with BranchCode = 'ALL' for corp managers and 2-char codes for branch managers.

- [ ] **Step 5: Commit the seed file**

```bash
git add "projects/parts action dashboard - report/documentation/branch-user-access-seed.csv"
git commit -m "feat(parts-action-dashboard): add dim_BranchUserAccess seed CSV"
```

---

## Task 3: Build the Semantic Model

**Files:**
- Create: `projects/parts action dashboard - report/reports/current/Parts Action Dashboard.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `projects/parts action dashboard - report/reports/current/Parts Action Dashboard.SemanticModel/definition/tables/dim_BranchUserAccess.tmdl`
- Create: `projects/parts action dashboard - report/reports/current/Parts Action Dashboard.SemanticModel/definition/tables/Fact_NegativeOnHand_OnHandNoBin.tmdl`
- Create: `projects/parts action dashboard - report/reports/current/Parts Action Dashboard.SemanticModel/definition/tables/Fact_Parts_Open_Tickets.tmdl`
- Create: `projects/parts action dashboard - report/reports/current/Parts Action Dashboard.SemanticModel/definition/model.tmdl`

> **Build in Power BI Desktop.** Open Desktop, create a new file, connect to the Fabric SQL endpoint (`xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com / LH_Master_Data`), and save as PBIP format to the path above. Then refine by editing TMDL files directly.

- [ ] **Step 1: Create new PBIP project in Power BI Desktop**

1. Open Power BI Desktop
2. File → Options → Preview features → Enable "Power BI Project (.pbip)" if not already on
3. Get Data → SQL Server → Server: `xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com` Database: `LH_Master_Data`
4. Load these tables: `Fact_NegativeOnHand_OnHandNoBin`, `Fact_Parts_Open_Tickets`, `dim_BranchLocation`, `dim_BranchUserAccess`
5. File → Save As → select format "Power BI Project (.pbip)" → save to `projects/parts action dashboard - report/reports/current/Parts Action Dashboard.pbip`

- [ ] **Step 2: Edit Fact_NegativeOnHand_OnHandNoBin.tmdl — hide unused columns**

Open the generated TMDL file and verify these columns are present (they are the only ones needed for this report). Mark all others as `isHidden`. The columns to KEEP visible:

```
Branch, PartNumber, Description, Franchise, Bin, BinQty, QuantityOnHand,
HasNegativeBinQty, HasBinQtyNoBin, IssueType, IssueSeverity
```

Add `isHidden` to all other columns (Cost, SellPrice1, Current12MoSales, etc.) to keep the model clean:

```tmdl
column Cost
    dataType: double
    isHidden
    ...
```

- [ ] **Step 3: Edit Fact_Parts_Open_Tickets.tmdl — hide unused columns**

Columns to KEEP visible:

```
Location, Order_No, Customer, Salesman, Order_Date, Days_Open, Aging,
#_Parts_On_Order, #_On_Back_Order, Order_Total_$$, $$_BackOrdered
```

Mark all others as `isHidden`.

- [ ] **Step 4: Edit dim_BranchUserAccess.tmdl — add partition source**

Verify the partition source matches the Lakehouse. If Desktop generated a DirectQuery partition, confirm it reads correctly:

```tmdl
table dim_BranchUserAccess
    lineageTag: [generated-by-desktop]

    column UserEmail
        dataType: string
        lineageTag: [generated]
        summarizeBy: none
        sourceColumn: UserEmail

    column BranchCode
        dataType: string
        lineageTag: [generated]
        summarizeBy: none
        sourceColumn: BranchCode

    column BranchName
        dataType: string
        lineageTag: [generated]
        summarizeBy: none
        sourceColumn: BranchName

    column FirstName
        dataType: string
        lineageTag: [generated]
        summarizeBy: none
        sourceColumn: FirstName

    column IsCorpManager
        dataType: boolean
        lineageTag: [generated]
        summarizeBy: none
        sourceColumn: IsCorpManager

    partition dim_BranchUserAccess = m
        mode: import
        source =
            let
                Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
                dbo_dim_BranchUserAccess = Source{[Schema="dbo",Item="dim_BranchUserAccess"]}[Data]
            in
                dbo_dim_BranchUserAccess
```

- [ ] **Step 5: Add relationships in Power BI Desktop**

In the Model view, create these relationships (all single direction, many-to-one):

| From Table | From Column | To Table | To Column | Cardinality |
|---|---|---|---|---|
| Fact_NegativeOnHand_OnHandNoBin | Branch | dim_BranchLocation | Branch | Many-to-one |
| Fact_Parts_Open_Tickets | Location | dim_BranchLocation | Branch | Many-to-one |

> Do NOT create a relationship from dim_BranchUserAccess to either fact table — RLS uses LOOKUPVALUE/USERPRINCIPALNAME in DAX, not a model relationship.

- [ ] **Step 6: Set up RLS roles in Power BI Desktop**

RLS filters at the `dim_BranchLocation` level (by LocationID). The model relationships propagate the filter to both fact tables automatically, including sub-branches (I/S/C/B suffixes).

In Desktop: Modeling → Manage Roles → Create two roles:

**Role: BranchManager**
Table: `dim_BranchLocation`
DAX filter:
```dax
[Branch] = LOOKUPVALUE(
    dim_BranchUserAccess[BranchCode],
    dim_BranchUserAccess[UserEmail], USERPRINCIPALNAME()
)
```

> This single filter on `dim_BranchLocation[Branch]` (the LocationID column, e.g. "01") propagates through the relationships to both fact tables, covering all sub-branches (1, 1I, 1S, 1C) automatically. No filters needed on the fact tables themselves.

**Role: CorpManager**
No filters — leave all table filters empty. Corp managers see all data.

- [ ] **Step 7: Validate RLS works in Desktop before writing measures**

Modeling → View As → Select "BranchManager" and enter a test user email (one that has a specific branch code in dim_BranchUserAccess). Create a simple table visual with `Fact_NegativeOnHand_OnHandNoBin[Branch]` and `Fact_NegativeOnHand_OnHandNoBin[PartNumber]`. Confirm only that branch's rows appear.

Switch to "CorpManager" — confirm all branches appear.

- [ ] **Step 8: Commit the initial semantic model**

```bash
git add "projects/parts action dashboard - report/reports/current/"
git commit -m "feat(parts-action-dashboard): initial semantic model with RLS roles"
```

---

## Task 4: Write Core DAX Measures

**Files:**
- Modify: `projects/parts action dashboard - report/reports/current/Parts Action Dashboard.SemanticModel/definition/tables/_Measures.tmdl`

Add all measures to the `_Measures` table. Write them in Desktop via the measure editor, then verify TMDL was updated correctly after saving.

> Do NOT add `//` comment lines in the TMDL file — they cause parse errors. DAX `//` comments inside backtick measure expressions are fine.

- [ ] **Step 1: Add Negative On Hand count measure**

```dax
[Negative On Hand Count] =
CALCULATE(
    COUNTROWS(Fact_NegativeOnHand_OnHandNoBin),
    Fact_NegativeOnHand_OnHandNoBin[HasNegativeBinQty] = TRUE()
)
```

- [ ] **Step 2: Add On Hand No Bin count measure**

```dax
[On Hand No Bin Count] =
CALCULATE(
    COUNTROWS(Fact_NegativeOnHand_OnHandNoBin),
    Fact_NegativeOnHand_OnHandNoBin[HasBinQtyNoBin] = TRUE()
)
```

- [ ] **Step 3: Add Open Tickets Aging count measure**

```dax
[Open Tickets Aging Count] =
VAR _AgingThresholdDays = 30
RETURN
CALCULATE(
    DISTINCTCOUNT(Fact_Parts_Open_Tickets[Order_No]),
    Fact_Parts_Open_Tickets[Days_Open] >= _AgingThresholdDays
        || Fact_Parts_Open_Tickets[#_On_Back_Order] > 0
)
```

> The `_AgingThresholdDays = 30` constant is intentional — change this one number when the Corp Parts Manager confirms the threshold.

- [ ] **Step 4: Validate measures in Desktop with a card visual**

Add three card visuals to a blank page using each measure. With no RLS active, you should see company-wide totals. With "View As → BranchManager" (test user), you should see only that branch's counts. Confirm all three return numbers.

- [ ] **Step 5: Commit measures**

```bash
git add "projects/parts action dashboard - report/reports/current/Parts Action Dashboard.SemanticModel/"
git commit -m "feat(parts-action-dashboard): add three core action item measures"
```

---

## Task 5: Build Page 1 — Branch Summary (Corp View)

This page is only reachable by CorpManager role users. Build it in Power BI Desktop.

- [ ] **Step 1: Add a new page in Desktop, name it "Branch Summary"**

Right-click the page tab → Rename → "Branch Summary"

- [ ] **Step 2: Add three KPI card visuals (company-wide totals)**

Add a Card visual for each measure — these show totals across all branches when viewed by a corp manager:
- `[Negative On Hand Count]` — red accent color (`#dc2626`)
- `[On Hand No Bin Count]` — orange accent color (`#ea580c`)
- `[Open Tickets Aging Count]` — yellow accent color (`#ca8a04`)

Arrange them in a row across the top of the page.

- [ ] **Step 3: Add the branch matrix table**

Add a Matrix visual with:
- Rows: `dim_BranchLocation[Branch]` and `dim_BranchLocation[BranchName]`
- Values: `[Negative On Hand Count]`, `[On Hand No Bin Count]`, `[Open Tickets Aging Count]`
- Sort by: `dim_BranchLocation[Branch]` ascending

Format the value columns with conditional formatting (background color) — red background when > 0, neutral when 0.

- [ ] **Step 4: Add drill-through to Page 2**

This allows a corp manager to right-click any branch row and drill through to that branch's detail page.

On Page 2 (built in Task 6), add `dim_BranchLocation[Branch]` as a drill-through field.
Then on Page 1, the matrix rows will automatically support right-click → Drill through → Branch Action Items.

> Note: Complete this step after Page 2 is built in Task 6.

- [ ] **Step 5: Add a page-level filter to hide from BranchManager role**

This page has no page-level filter — the RLS on the fact tables already restricts what branch managers can see. However, add a text box note in an off-canvas area:
"This page is intended for corp managers. Branch managers are directed to Page 2 via email link."

This is a documentation note only — RLS handles the actual security.

- [ ] **Step 6: Commit Page 1**

```bash
git add "projects/parts action dashboard - report/reports/current/Parts Action Dashboard.Report/"
git commit -m "feat(parts-action-dashboard): build Page 1 branch summary for corp managers"
```

---

## Task 6: Build Page 2 — Branch Action Items (Branch View)

This is the page branch managers land on from the email link. Keep it as simple as possible.

- [ ] **Step 1: Add a new page in Desktop, name it "Branch Action Items"**

Right-click the page tab → Rename → "Branch Action Items"

- [ ] **Step 2: Add three KPI card visuals (branch-filtered)**

Same three measures as Page 1 — but because RLS is active, these automatically show only the current user's branch when viewed by a BranchManager. No additional filter needed.

- `[Negative On Hand Count]` — red accent (`#dc2626`)
- `[On Hand No Bin Count]` — orange accent (`#ea580c`)
- `[Open Tickets Aging Count]` — yellow accent (`#ca8a04`)

Add a title text box above the cards: "Action Items — [use a slicer or dynamic title showing branch name]"

For the dynamic branch name, add a card visual showing:
```dax
[Current Branch Name] =
LOOKUPVALUE(
    dim_BranchUserAccess[BranchName],
    dim_BranchUserAccess[UserEmail], USERPRINCIPALNAME()
)
```
Add this measure to `_Measures.tmdl` and use it as a card on the page header.

- [ ] **Step 3: Add Negative On Hand detail table**

Add a Table visual below the KPI cards:

Columns: `Fact_NegativeOnHand_OnHandNoBin[PartNumber]`, `[Description]`, `[Bin]`, `[BinQty]`, `[QuantityOnHand]`

Add a visual-level filter: `HasNegativeBinQty = TRUE`

Title the visual: "⚠ Negative On Hand"

Format `QuantityOnHand` with conditional formatting — red font when < 0.

- [ ] **Step 4: Add On Hand No Bin detail table**

Add a second Table visual:

Columns: `Fact_NegativeOnHand_OnHandNoBin[PartNumber]`, `[Description]`, `[QuantityOnHand]`, `[BulkBin]`

Add a visual-level filter: `HasBinQtyNoBin = TRUE`

Title the visual: "⚠ On Hand No Bin"

- [ ] **Step 5: Add Open Tickets Aging detail table**

Add a third Table visual:

Columns: `Fact_Parts_Open_Tickets[Order_No]`, `[Customer]`, `[Salesman]`, `[Order_Date]`, `[Days_Open]`, `[#_On_Back_Order]`, `[Order_Total_$$]`

Add a visual-level filter: `Days_Open >= 30 OR #_On_Back_Order > 0`

> In Power BI, visual-level filters don't support OR directly. Use a measure as a filter instead:
```dax
[Is Aging Ticket] =
VAR _AgingThresholdDays = 30
RETURN
IF(
    MAX(Fact_Parts_Open_Tickets[Days_Open]) >= _AgingThresholdDays
        || MAX(Fact_Parts_Open_Tickets[#_On_Back_Order]) > 0,
    1, 0
)
```
Add this to `_Measures.tmdl`. Then filter the visual: `[Is Aging Ticket] = 1`

Title the visual: "⚠ Open Tickets Aging (30+ Days or Backordered)"

- [ ] **Step 6: Add drill-through field (needed for Page 1 drill-through)**

In the Drill through section of the Visualizations pane (while on Page 2), drag `dim_BranchLocation[Branch]` into the "Add drill-through fields here" area.

This enables right-click drill-through from the Page 1 matrix.

- [ ] **Step 7: Disable the back button auto-generated by drill-through**

Desktop adds a Back button automatically. Hide it for branch manager users (it takes them to Page 1, which they can't use). Delete the auto-generated Back button.

- [ ] **Step 8: Test both pages with View As**

Using Modeling → View As:
1. Select "CorpManager" — Page 1 should show all branch data. Drill-through to Page 2 should show filtered data for the selected branch.
2. Select "BranchManager" + enter test user email — Page 2 should show only that branch's three action item tables.

Verify all three detail tables show the correct rows and the KPI counts match the row counts in the detail tables.

- [ ] **Step 9: Commit Page 2**

```bash
git add "projects/parts action dashboard - report/reports/current/"
git commit -m "feat(parts-action-dashboard): build Page 2 branch action items with detail tables"
```

---

## Task 7: Publish to RP-Sandbox and Validate RLS

- [ ] **Step 1: Publish the report to RP-Sandbox**

In Power BI Desktop: Home → Publish → Select workspace "RP - Sandbox"

If the report already exists there from a previous publish, select "Replace".

- [ ] **Step 2: Assign RLS roles to test users in Fabric**

In the Fabric portal → RP-Sandbox → Find "Parts Action Dashboard" semantic model → Security

Assign roles:
- `CorpManager`: your email + Corp Parts Manager's email
- `BranchManager`: one test branch manager email for a branch you can verify

- [ ] **Step 3: Validate corp manager view**

Log in as (or use "View as role") a CorpManager. Navigate to Page 1. Confirm:
- [ ] All branches appear in the matrix table
- [ ] KPI counts are company-wide totals
- [ ] Drill-through to Page 2 works for at least two different branches

- [ ] **Step 4: Validate branch manager view**

Ask a test branch manager to open the report (or use View As with their email). Confirm:
- [ ] Page 1 is not accessible (they should see Page 2 by default or only Page 2 in nav)
- [ ] Page 2 shows only their branch's data
- [ ] All three detail tables show correct items for their branch
- [ ] KPI card counts match the row counts in the detail tables

- [ ] **Step 5: Validate "all clear" state**

Find a branch with zero issues (or temporarily modify a filter to simulate this). Confirm the detail tables show a clean empty state, not an error.

- [ ] **Step 6: Commit any fixes found during validation**

```bash
git add "projects/parts action dashboard - report/"
git commit -m "fix(parts-action-dashboard): [describe any fixes from validation]"
```

---

## Task 8: Set Up Power Automate Daily Email Flow

This task is a Fabric/Power Automate setup — no TMDL or PBIP files are modified. Write a setup guide doc as the deliverable.

- [ ] **Step 1: Get the direct link to Page 2 of the published report**

In Fabric → RP-Sandbox → Open "Parts Action Dashboard" report → Navigate to Page 2 ("Branch Action Items") → Copy the URL from the browser. It will look like:
`https://app.powerbi.com/groups/[workspace-id]/reports/[report-id]/[page-id]`

This is the `ViewMyActionItemsUrl` used in every email.

- [ ] **Step 2: Create a new Power Automate cloud flow**

Go to make.powerautomate.com → Create → Scheduled cloud flow

- Name: `Parts Action Dashboard - Daily Branch Email`
- Repeat every: 1 Day
- At: 7:00 AM (Central Standard Time / UTC-6)
- Days: Monday, Tuesday, Wednesday, Thursday, Friday

- [ ] **Step 3: Add action — Run a query against the Lakehouse**

Add action: "Run a query against a dataset" (Power BI connector)

For each branch manager row in `dim_BranchUserAccess` where `IsCorpManager = FALSE`, query these measures:

DAX to run (parameterized — use a loop in the flow):
```dax
EVALUATE
ROW(
    "NegativeOnHandCount",    [Negative On Hand Count],
    "OnHandNoBinCount",       [On Hand No Bin Count],
    "OpenTicketsAgingCount",  [Open Tickets Aging Count]
)
```

With a table filter context set to the current branch manager's BranchCode.

> Power Automate's Power BI "Run a query" action supports DAX with CALCULATETABLE or filter parameters. Alternatively, query the Lakehouse SQL endpoint directly using an HTTP action with a SQL query filtered to the branch code — this avoids needing a published dataset for the flow.

**Recommended approach: SQL endpoint query**

Add an HTTP action:
- Method: POST
- URI: `https://[fabric-sql-endpoint]/v1/datasets/[dataset-id]/executeQueries`

Or use the simpler path: query `LH_Master_Data` SQL endpoint with:
```sql
SELECT
    SUM(CASE WHEN HasNegativeBinQty = 1 THEN 1 ELSE 0 END) AS NegativeOnHandCount,
    SUM(CASE WHEN HasBinQtyNoBin = 1 THEN 1 ELSE 0 END)    AS OnHandNoBinCount
FROM Fact_NegativeOnHand_OnHandNoBin
WHERE Branch = @BranchCode
```

And separately for Open Tickets:
```sql
SELECT COUNT(DISTINCT Order_No) AS OpenTicketsAgingCount
FROM Fact_Parts_Open_Tickets
WHERE Location = @BranchCode
  AND (Days_Open >= 30 OR [#_On_Back_Order] > 0)
```

- [ ] **Step 4: Build the loop and email send action**

Flow structure:
1. Get all rows from `dim_BranchUserAccess` where `IsCorpManager = false`
2. For each row: run the SQL queries above with `BranchCode` from the row
3. Build the HTML email body (see the email template below)
4. Send email action (Office 365 Outlook connector) to `UserEmail`

**HTML email body template** (replace `{{variables}}` with dynamic values from the flow):

```html
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0">
<tr><td align="center" style="padding:24px 16px">
<table width="560" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:8px;overflow:hidden">

  <!-- Header -->
  <tr><td style="background:#1e3a5f;padding:20px 24px">
    <p style="margin:0;color:#fff;font-size:18px;font-weight:bold">Parts Action Summary</p>
    <p style="margin:4px 0 0;color:#94b8d8;font-size:13px">{{BranchName}} &nbsp;·&nbsp; {{TodayDate}}</p>
    <p style="margin:4px 0 0;color:#94b8d8;font-size:12px">Good morning, {{FirstName}}</p>
  </td></tr>

  <!-- KPI Cards -->
  <tr><td style="padding:20px 24px">
    <p style="margin:0 0 12px;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.05em">Items Needing Attention Today</p>
    <table width="100%" cellpadding="0" cellspacing="0"><tr>
      <td width="31%" style="background:#fff5f5;border:1px solid #fecaca;border-radius:6px;padding:12px;text-align:center">
        <p style="margin:0;font-size:28px;font-weight:bold;color:#dc2626">{{NegativeOnHandCount}}</p>
        <p style="margin:4px 0 0;font-size:11px;color:#991b1b">Negative<br>On Hand</p>
      </td>
      <td width="4%"></td>
      <td width="31%" style="background:#fff7ed;border:1px solid #fed7aa;border-radius:6px;padding:12px;text-align:center">
        <p style="margin:0;font-size:28px;font-weight:bold;color:#ea580c">{{OnHandNoBinCount}}</p>
        <p style="margin:4px 0 0;font-size:11px;color:#9a3412">No Bin<br>Assigned</p>
      </td>
      <td width="4%"></td>
      <td width="31%" style="background:#fefce8;border:1px solid #fef08a;border-radius:6px;padding:12px;text-align:center">
        <p style="margin:0;font-size:28px;font-weight:bold;color:#ca8a04">{{OpenTicketsAgingCount}}</p>
        <p style="margin:4px 0 0;font-size:11px;color:#854d0e">Open Tickets<br>Aging</p>
      </td>
    </tr></table>
  </td></tr>

  <!-- All Clear (shown when all counts = 0) -->
  <!-- In Power Automate: use a condition to show this row OR the counts row, not both -->
  <!-- All-clear row: -->
  <tr><td style="padding:0 24px 16px">
    <p style="margin:0;background:#f0fdf4;border-radius:6px;padding:10px 14px;font-size:13px;color:#166534">
      ✅ No action items today — your branch is in good shape!
    </p>
  </td></tr>

  <!-- CTA Button -->
  <tr><td style="padding:0 24px 24px;text-align:center">
    <a href="{{ViewMyActionItemsUrl}}" style="display:inline-block;background:#1e3a5f;color:#fff;text-decoration:none;padding:12px 32px;border-radius:6px;font-size:14px;font-weight:bold">View My Action Items →</a>
    <p style="margin:8px 0 0;font-size:11px;color:#94a3b8">Opens directly to your branch in Power BI</p>
  </td></tr>

  <!-- Footer -->
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

> **All-clear logic in Power Automate:** Add a Condition action before the email step. If `NegativeOnHandCount = 0 AND OnHandNoBinCount = 0 AND OpenTicketsAgingCount = 0`, use the all-clear HTML. Otherwise, use the counts HTML. Both branches send to the same `UserEmail`.

- [ ] **Step 5: Send a test email to yourself before enabling the schedule**

Disable the schedule trigger temporarily. Run the flow manually for your own test row. Verify:
- [ ] Email arrives with your name and branch data
- [ ] KPI counts match what you see in the Power BI report for that branch
- [ ] "View My Action Items" button opens the correct Power BI page
- [ ] All-clear state triggers when counts are all zero (test with a branch that has no issues)

- [ ] **Step 6: Enable the scheduled trigger**

Re-enable the 7:00 AM Mon-Fri schedule. The flow is live.

- [ ] **Step 7: Write the setup guide**

Write `projects/parts action dashboard - report/documentation/power-automate-setup.md`:

```markdown
# Power Automate Flow Setup Guide

## Flow Name
Parts Action Dashboard - Daily Branch Email

## Schedule
7:00 AM Central Time, Monday–Friday

## Data Source
LH_Master_Data SQL endpoint (Fabric)
Connection: xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com

## Recipient List
dim_BranchUserAccess WHERE IsCorpManager = FALSE
Corp managers (IsCorpManager = TRUE) do not receive the daily email — they use the report directly.

## Aging Threshold
Days_Open >= 30 OR #_On_Back_Order > 0
To change the threshold: update this SQL condition in the flow AND update _AgingThresholdDays in the [Open Tickets Aging Count] and [Is Aging Ticket] DAX measures.

## Adding a New Recipient
1. Add a row to the branch-user-access-seed.csv
2. Re-upload to Lakehouse Files and re-run df_BranchUserAccess dataflow
3. No flow changes needed — it reads from the table dynamically

## Adding a New Metric to the Email
1. Add a SQL query to the flow for the new metric
2. Add a new KPI card td block to the HTML template
3. Update the all-clear condition to include the new metric

## Report Link
Page 2 URL: [paste the Page 2 URL from Task 8 Step 1 here]

## Troubleshooting
- Email not received: check the flow run history in Power Automate for errors
- Wrong counts: verify the SQL queries match the DAX measures in the semantic model
- RLS not working after clicking email link: confirm the user's email is in dim_BranchUserAccess
```

- [ ] **Step 8: Commit documentation**

```bash
git add "projects/parts action dashboard - report/documentation/"
git commit -m "feat(parts-action-dashboard): add Power Automate setup guide"
```

---

## Task 9: Final Validation and Handoff

- [ ] **Step 1: Run the full end-to-end test**

1. Trigger the Power Automate flow manually for a test branch manager
2. Open the received email — verify name, branch, and counts
3. Click "View My Action Items" — verify landing on correct page with correct branch data
4. Verify corp managers can still open Page 1 and see all branches

- [ ] **Step 2: Confirm aging threshold with Corp Parts Manager**

Before go-live, confirm: "We're currently flagging open parts tickets that are 30+ days old OR have any backordered items. Does that threshold work, or would you prefer a different number of days?"

If the threshold changes, update:
- `_AgingThresholdDays = 30` in `[Open Tickets Aging Count]` measure
- `_AgingThresholdDays = 30` in `[Is Aging Ticket]` measure
- The SQL WHERE clause in the Power Automate flow: `Days_Open >= 30`
- The visual title on Page 2: "Open Tickets Aging (30+ Days or Backordered)"

- [ ] **Step 3: Push final report to data-projects repo**

```bash
git add "projects/parts action dashboard - report/"
git commit -m "feat(parts-action-dashboard): complete MVP — report, RLS, email flow docs"
git push origin dev
```

- [ ] **Step 4: Validate in RP-Sandbox, then open PR to main**

After push, validate in RP-Sandbox one final time. Then follow the standard workflow:
- Open PR: dev → main on both repos (data-projects and fabric-workspace-docs)
- After merge, sync RP - Parts Reports (or whichever production workspace this report belongs in) in Fabric UI
- Assign RLS roles for all real users in the production workspace

---

## Future Categories (Extensibility Reference)

When the Corp Parts Manager identifies additional action items to add, follow this pattern for each new category:

1. **Identify the source Lakehouse table** — confirm it exists in LH_Master_Data
2. **Add the table to the semantic model** if not already present
3. **Write one count measure** following the same pattern as the three existing measures
4. **Write one "Is [Category]" measure** for visual-level filtering
5. **Add one KPI card** to Page 2 (and Page 1 matrix)
6. **Add one detail table** to Page 2
7. **Add one SQL query + one KPI card** to the Power Automate email template
8. **Update the all-clear condition** in the flow to include the new metric

Each addition is self-contained. No existing measures, visuals, or flow logic need to change.
