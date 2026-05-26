# Service Time Sheets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the manual email-based time sheet process with a SharePoint-based submission system that feeds a Fabric Dataflow and Power BI report comparing submitted technician hours and draws against source system invoice data.

**Architecture:** Service managers save a standardized Excel workbook to a dedicated SharePoint site (one folder per location). Power Automate fires an HR notification on each new file. A scheduled Fabric Dataflow reads all workbooks using `SharePoint.Files()` + `Excel.Workbook()`, normalizes data across all tabs into a single Lakehouse table (`service_time_sheets`), and feeds a Power BI report that compares submitted data against `TechnicianInvoiceDetailServiceForm` from the existing Fabric warehouse.

**Tech Stack:** Excel (template with data validation, formulas, locked cells), SharePoint Online (file storage + folder permissions), Power Automate (file trigger → email notification), Fabric Dataflow Gen2 (Power Query M, SharePoint.Files connector), LH_Master_Data Lakehouse, Power BI Desktop (semantic model + report with RLS)

**Spec:** `docs/superpowers/specs/2026-04-28-service-time-sheets-design.md`

---

## Dependency Map

```
Task 1 (SharePoint site)
  └── Task 2 (Folder structure + permissions)
        └── Task 3 (Power Automate notification)
        └── Task 4 (Excel template) ← BLOCKED on starred stakeholder questions
              └── Task 5 (Fabric Dataflow) ← needs finalized template column layout
                    └── Task 6 (Semantic model)
                          └── Task 7 (Power BI report)
                                └── Task 8 (RLS + access)
                                      └── Task 9 (UAT + go-live)
```

Tasks 1–3 can start immediately. Tasks 4–9 require answers to the starred questions in the spec before building.

---

## Starred Blockers (gather before Task 4)

Before building the Excel template, confirm all of the following with HR Director and Corp Service Manager:

| # | Question | Needed For |
|---|---|---|
| A | Which locations pay mileage? | Template mileage flag logic |
| B | Mileage rate — fixed company-wide, per-location, or manual entry? | Mileage $ formula |
| C | Do After Hours roll into Total Pay or informational only? | Summary formula |
| D | Confirm pay rates: Level 3 = $40, Level 4 = $43, Level 5 = $46. Any exceptions? | Pay Rate lookup |
| E | Power BI access for HR — license them, route through Corp SM, or PA email summary? | Task 8 |
| F | SharePoint site name preference (suggest: SouthPlainsImplement-ServicePayroll) | Task 1 |

---

## Task 1: Create the SharePoint Site

**What:** Provision a dedicated SharePoint site for payroll submissions, separate from the existing Report Site.

**Files/Resources:**
- New SharePoint site: `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ServicePayroll` (or HR-approved name)
- New Document Library: `Service Time Sheets`

- [ ] **Step 1: Create the SharePoint site**

  Navigate to the Microsoft 365 Admin Center or SharePoint Admin Center.
  Create a new Team Site (not Communication Site — Team Site supports folder-level permissions better).
  - Site name: `SouthPlainsImplement-ServicePayroll` (confirm with HR first — see Blocker F)
  - Site address: `spitractor.sharepoint.com/sites/SouthPlainsImplement-ServicePayroll`
  - Privacy: **Private** (not public)
  - Add only yourself (Brian) as initial owner
  - Do NOT add broad member groups at this step — permissions are configured per-folder in Task 2

- [ ] **Step 2: Create the Document Library**

  Inside the new site, create a Document Library named `Service Time Sheets`.
  Do not use the default "Documents" library — a named library makes the Power Query URL cleaner and the purpose unambiguous.

- [ ] **Step 3: Verify the site URL**

  Confirm the site is accessible at the expected URL. Note the full URL — you'll need it in Task 3 (Power Automate), Task 4 (template), and Task 5 (Dataflow).

  URL format for Power Query later:
  `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ServicePayroll`

- [ ] **Step 4: Commit site URL to project docs**

  Open `docs/superpowers/specs/2026-04-28-service-time-sheets-design.md` and update the site name from the suggestion to the confirmed name.

  ```bash
  git add docs/superpowers/specs/2026-04-28-service-time-sheets-design.md
  git commit -m "docs(service-time-sheets): confirm SharePoint site URL"
  ```

---

## Task 2: Create Folder Structure and Permissions

**What:** Create one subfolder per location inside the Document Library, then configure access so each location manager can only write to their own folder.

**Files/Resources:**
- 13 location folders inside `Service Time Sheets/`
- SharePoint permission groups (created here, populated in this task)

- [ ] **Step 1: Create the 13 location folders**

  Inside the `Service Time Sheets` document library, create one folder for each location:
  ```
  Abernathy
  Big Spring
  Brownfield
  Lamesa
  Levelland
  Littlefield
  Lorenzo
  Lubbock
  Morton
  San Angelo
  Seminole
  Slaton
  Snyder
  Tahoka
  ```
  Folder names must match exactly — the Dataflow will parse location from the folder path.

- [ ] **Step 2: Create SharePoint permission groups**

  In Site Settings → People and Groups, create the following groups:
  - `STS-HR-Payroll` — for HR Director and Payroll Specialist
  - `STS-Management` — for Corp Service Manager and CFO
  - `STS-Admin` — for Brian
  - One group per location manager, named `STS-Mgr-[Location]` (e.g., `STS-Mgr-Lorenzo`)

  Add members to each group. Use the Tech Levels CSV (`projects/service time sheets/tech levels/TECH LEVELS.csv`) to identify which tech is the likely manager contact per location — confirm actual manager email addresses with the Corp Service Manager.

- [ ] **Step 3: Break permission inheritance on the library**

  In the `Service Time Sheets` library settings → Permissions → Stop Inheriting Permissions.
  Grant the following library-level access:
  - `STS-HR-Payroll`: Contribute (read + write to all folders)
  - `STS-Management`: Read (all folders, no write)
  - `STS-Admin`: Full Control

  Do NOT add any location manager groups at the library level — they get folder-level access only.

- [ ] **Step 4: Set folder-level permissions for each location manager**

  For each of the 13 folders:
  1. Open folder → Manage Access → Advanced Settings → Stop Inheriting Permissions
  2. Add `STS-Mgr-[Location]` with Contribute access
  3. Confirm `STS-HR-Payroll` and `STS-Management` still have access (inherited from library)

  Repeat for all 13 locations.

- [ ] **Step 5: Test permissions**

  Log in as (or use "Check permissions" for) a location manager account. Verify:
  - Can see and write to their own folder
  - Cannot browse to other location folders
  - Cannot see site settings or other libraries

  Log in as HR. Verify:
  - Can see and open files in all 13 folders

- [ ] **Step 6: Commit permission group names to docs**

  ```bash
  git add docs/superpowers/specs/2026-04-28-service-time-sheets-design.md
  git commit -m "docs(service-time-sheets): add confirmed SharePoint permission group names"
  ```

---

## Task 3: Build Power Automate Notification Flow

**What:** Create a simple flow that emails HR when a new Excel file lands in any location folder. No data extraction — notification only.

**Files/Resources:**
- Power Automate flow (cloud flow, runs under Brian's account)
- Trigger: SharePoint — "When a file is created (properties only)"

- [ ] **Step 1: Create the flow in Power Automate**

  Go to `make.powerautomate.com` → Create → Automated cloud flow.
  Name: `Service Time Sheet — New Submission Notification`
  Trigger: `SharePoint — When a file is created (properties only)`
  - Site Address: `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ServicePayroll`
  - Library Name: `Service Time Sheets`
  - Folder: leave blank (monitors all subfolders)

- [ ] **Step 2: Add a condition to filter .xlsx files only**

  Add a `Condition` action after the trigger.
  - Condition: `triggerOutputs()?['body/{FilenameWithExtension}']` ends with `.xlsx`
  - If No: Add a `Terminate` action (status: Succeeded) — ignores non-Excel files

- [ ] **Step 3: Parse location from folder path**

  Inside the Yes branch, add a `Compose` action named `Location`.
  Expression:
  ```
  last(split(triggerOutputs()?['body/{Path}'], '/'))
  ```
  This extracts the folder name (location) from the file path.

  Add another `Compose` action named `FileName`.
  Expression:
  ```
  triggerOutputs()?['body/{FilenameWithExtension}']
  ```

- [ ] **Step 4: Add Send Email action**

  Add `Office 365 Outlook — Send an email (V2)`.
  - To: HR Director email address + Payroll Specialist email address
  - CC: Corp Service Manager email address
  - Subject:
    ```
    Service Time Sheet Submitted — @{outputs('Location')}
    ```
  - Body:
    ```
    A new service time sheet has been submitted.

    Location: @{outputs('Location')}
    File: @{outputs('FileName')}
    Submitted by: @{triggerOutputs()?['body/Author/DisplayName']}
    Submitted at: @{triggerOutputs()?['body/{Modified}']}

    The file is available in SharePoint:
    @{triggerOutputs()?['body/{Link}']}

    This is an automated notification. The data will be available in the
    Power BI report after the next scheduled refresh.
    ```

- [ ] **Step 5: Test the flow**

  Save and turn on the flow.
  Upload a test `.xlsx` file to any location folder (e.g., Lorenzo/).
  Verify:
  - HR Director receives the email within 2 minutes
  - Location name in subject line is correct
  - File link in body opens the correct file
  - A non-.xlsx file upload does NOT trigger an email

- [ ] **Step 6: Commit flow name to docs**

  ```bash
  git add docs/superpowers/specs/2026-04-28-service-time-sheets-design.md
  git commit -m "docs(service-time-sheets): add Power Automate flow name and confirmed email recipients"
  ```

---

## Task 4: Build the Excel Submission Template

> ⚠ **BLOCKED** until Starred Blockers A–D are answered. Complete Tasks 1–3 first, then gather stakeholder answers before proceeding.

**What:** Build the standardized Excel workbook that all location managers will use. One workbook per location per pay period. One tab per technician. Guard rails prevent format-breaking.

**Files/Resources:**
- New file: `projects/service time sheets/template/Service Time Sheet Template.xlsx`
- Source data: `projects/service time sheets/tech levels/TECH LEVELS.csv` (for tech lookup table)
- Reference: `projects/service time sheets/sample time sheets/LORENZO - LORENZO TECHS 03.23.26 to 04.05.26.csv` (current format)

- [ ] **Step 1: Create a new Excel workbook**

  Create `projects/service time sheets/template/Service Time Sheet Template.xlsx`.

  The workbook will contain:
  - One hidden sheet: `_Config` (tech lookup table + location config)
  - One hidden sheet: `_Instructions` (brief guidance for managers)
  - One visible template tab: `TECH NAME` (the manager duplicates this per technician)

- [ ] **Step 2: Build the _Config sheet (hidden)**

  This sheet drives all dropdown validation and auto-fill logic. Managers never see it.

  **Table 1 — Tech Lookup** (columns A–E, starting row 2, named range `TechTable`):
  | Column | Header | Example |
  |---|---|---|
  | A | TechNumber | T9105 |
  | B | TechName | Nick Nunley |
  | C | TechLevel | 5 |
  | D | Branch | Lorenzo |
  | E | PayRate | 46 |

  Populate from TECH LEVELS CSV. Add all 58 techs.
  Name the range `TechTable` (select A1:E59 → Name Box → type `TechTable`).

  **Table 2 — Location Mileage Config** (columns G–H, named range `MileageConfig`):
  | Column | Header | Example |
  |---|---|---|
  | G | Location | Lorenzo |
  | H | MileageApplicable | Y or N |

  Populate with all 13 locations. Set Y/N based on answers from Blocker A.
  Add mileage rate in column I (`MileageRate`) if rate is fixed — leave blank if manually entered.
  Name range `MileageConfig`.

  **Table 3 — Payroll Period Dropdown List** (column K, named range `PayPeriods`):
  Pre-populate the next 26 bi-weekly pay period date ranges in format `YYYY-MM-DD to YYYY-MM-DD`.
  Starting from the first period after go-live. Update this list each year.
  Name range `PayPeriods`.

  Hide the sheet: right-click tab → Hide.

- [ ] **Step 3: Build the workbook header area (rows 1–8 of each tech tab)**

  This is the top section the manager fills out once per workbook (location + pay period).
  Place it on the template tab in rows 1–8.

  | Cell | Label | Input Type | Notes |
  |---|---|---|---|
  | B2 | Location | Dropdown | Data validation → list from `_Config!G2:G14` |
  | B3 | Payroll Start Date | Date | Auto-filled when pay period selected |
  | B4 | Payroll End Date | Date | Auto-filled when pay period selected |
  | B5 | Pay Date | Date | Manual entry — the actual payroll processing date |
  | E2 | Pay Period | Dropdown | Data validation → list from `PayPeriods` named range |
  | E3 | Mileage Applicable | Formula | `=IFERROR(VLOOKUP(B2, MileageConfig, 2, FALSE), "N")` — hidden row |

  Auto-fill start/end dates from pay period selection:
  - B3 formula: `=IF(E2="","",LEFT(E2,10))` (extracts start date from "YYYY-MM-DD to YYYY-MM-DD")
  - B4 formula: `=IF(E2="","",RIGHT(E2,10))` (extracts end date)

  Lock B3, B4, E3 (calculated, not editable):
  Format Cells → Protection → Locked = True (apply after sheet protection in Step 7)

- [ ] **Step 4: Build the tech header area (rows 10–14)**

  Manager selects the tech number — all other fields auto-fill.

  | Cell | Label | Input | Formula |
  |---|---|---|---|
  | B10 | Tech Number | Dropdown | Data validation → list from `_Config!A2:A59` |
  | B11 | Technician Name | Locked | `=IFERROR(VLOOKUP(B10, TechTable, 2, FALSE), "")` |
  | B12 | Tech Level | Locked | `=IFERROR(VLOOKUP(B10, TechTable, 3, FALSE), "")` |
  | B13 | Branch | Locked | `=IFERROR(VLOOKUP(B10, TechTable, 4, FALSE), "")` |
  | B14 | Pay Rate | Locked | `=IFERROR(VLOOKUP(B10, TechTable, 5, FALSE), "")` |

  Lock B11:B14 (calculated). Unlock B10 (manager input).

- [ ] **Step 5: Build the RO entry table (rows 17–47)**

  This is the repeating rows section. Pre-build 30 blank rows — manager fills only what they need.

  Named Excel Table: `ROEntries` (Insert → Table, headers in row 16)

  | Column | Header | Type | Notes |
  |---|---|---|---|
  | A | Customer Name | Text | Free entry |
  | B | Model | Text | Free entry |
  | C | RO# | Number | Integer, no decimals |
  | D | % Complete | Dropdown | 25%, 50%, 75%, 100% — data validation list |
  | E | Draw 1 Date | Date | Record-keeping only |
  | F | Draw 1 Hrs | Number | Record-keeping only |
  | G | Draw 2 Date | Date | Record-keeping only |
  | H | Draw 2 Hrs | Number | Record-keeping only |
  | I | Draw 3 Date | Date | Record-keeping only |
  | J | Draw 3 Hrs | Number | Record-keeping only |
  | K | Final Draw Date | Date | Record-keeping only |
  | L | Final Draw Hrs | Number | Record-keeping only |
  | M | Current Period Hrs | Number | **Main entry — hours claimed this period** |
  | N | After Hours | Number | Per Blocker C answer |

  Add a small italic note in the header row for columns E–L: "* Record-keeping only"

- [ ] **Step 6: Build the summary section (rows 50–62)**

  All calculated fields locked except Holiday Hours, PTO Hours, No Pay Hours, Pay Date.

  | Cell | Label | Formula or Input |
  |---|---|---|
  | B50 | Total Hours | `=SUM(ROEntries[Current Period Hrs])` — locked |
  | B51 | Holiday Hours | Manual entry |
  | B52 | PTO Hours | Manual entry |
  | B53 | No Pay Hours | Manual entry |
  | B54 | Mileage (miles) | Manual entry — hide row if `E3="N"` using conditional formatting (white font) |
  | B55 | Mileage $ | `=IF(E3="Y", B54 * [MileageRate], 0)` — locked. If rate is manually entered, replace `[MileageRate]` with a named cell. Hide row if `E3="N"` |
  | B56 | Subtotal | `=B50 * B14` — locked (Total Hours × Pay Rate) |
  | B57 | Total Pay | `=B56 + B55` — locked (Subtotal + Mileage $) |

  Note: After Hours handling depends on Blocker C answer. If they roll into Total Pay, add `+SUM(ROEntries[After Hours])` to B50. If informational only, leave as a separate display row with no formula impact.

- [ ] **Step 7: Protect the sheet**

  Select the cells managers ARE allowed to edit:
  - E2 (Pay Period dropdown), B2 (Location), B5 (Pay Date)
  - B10 (Tech Number dropdown)
  - B51, B52, B53 (Holiday, PTO, No Pay hours)
  - B54 (Mileage miles, if applicable)
  - All cells in the ROEntries table

  For those cells only: Format Cells → Protection → Locked = **False**

  Then protect the sheet: Review → Protect Sheet.
  - Allow: Select unlocked cells, Insert rows (so managers can add more RO rows)
  - Password: set a simple password and store it in the project notes

- [ ] **Step 8: Rename template tab and add instructions**

  Rename the tab from "Sheet1" to `TEMPLATE — DO NOT SUBMIT`.
  Add instructions at the top of `_Instructions` sheet:
  ```
  HOW TO USE THIS WORKBOOK:
  1. Select your Location and Pay Period from the dropdowns (top left)
  2. For each technician: right-click the TEMPLATE tab → Move or Copy → check "Create a copy"
     Rename the new tab to the technician's name
  3. Select the Tech Number from the dropdown — all other tech info fills automatically
  4. Fill in the RO entry rows for each job this pay period
  5. Fill in Holiday, PTO, and No Pay hours at the bottom
  6. When ALL technicians are complete, save the file as:
     [Location] - [YYYY-MM-DD] to [YYYY-MM-DD].xlsx
     Example: Lorenzo - 2026-03-23 to 2026-04-05.xlsx
  7. Save to the SharePoint folder for your location (link: [ADD SHAREPOINT LINK])
  ```

- [ ] **Step 9: Build a sample completed workbook for training**

  Using the Lorenzo sample CSV as reference data, build a completed version of the workbook:
  `projects/service time sheets/template/Service Time Sheet SAMPLE - Lorenzo.xlsx`

  Populate 3 techs (Nick Nunley, Kevin Hendley, Larry D Davis) with realistic data from the sample CSV. This becomes the training reference for managers.

- [ ] **Step 10: Test the template with a full simulation**

  Fill out the template as if you are a service manager:
  - Select Location = Lorenzo, Pay Period = current period
  - Duplicate the template tab 3 times for 3 techs
  - Select tech numbers — verify name/level/branch/pay rate auto-fill correctly
  - Enter RO rows, confirm totals calculate
  - Enter 0 mileage (Lorenzo — confirm mileage row hidden if Lorenzo is configured N)
  - Verify protected cells cannot be edited
  - Verify total pay calculates correctly

- [ ] **Step 11: Commit the template**

  ```bash
  git add "projects/service time sheets/template/"
  git commit -m "feat(service-time-sheets): add Excel submission template and sample workbook"
  ```

---

## Task 5: Build the Fabric Dataflow

> ⚠ **BLOCKED** until Task 4 (template) is finalized. Column names and structure must be locked before writing the Power Query.

**What:** Create `df_ServiceTimeSheets_Raw` in Fabric, connecting to the SharePoint document library, expanding all workbooks and tabs, normalizing into a flat table, and outputting to `LH_Master_Data.service_time_sheets`.

**Files/Resources:**
- New dataflow in LH_Master_Data → `01 - Raw Sources` group
- Output: Lakehouse table `service_time_sheets`
- Save a copy of the M query: `projects/service time sheets/queries/df_ServiceTimeSheets_Raw.pq`

- [ ] **Step 1: Create the dataflow in Fabric**

  In LH_Master_Data workspace → New → Dataflow Gen2.
  Name: `df_ServiceTimeSheets_Raw`
  Group: `01 - Raw Sources`

- [ ] **Step 2: Connect to SharePoint Files**

  In the Power Query editor → Get Data → SharePoint folder (or Online Services → SharePoint Online Files).
  URL: `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ServicePayroll`
  Sign in with Brian's account (same account that has Site Admin access).

  This returns a table of all files in the site. The initial load may show many files across all libraries — we'll filter in the next step.

- [ ] **Step 3: Write the full Power Query transformation**

  Replace the auto-generated query with the following. Paste this into the Advanced Editor:

  ```powerquery
  let
      Source = SharePoint.Files(
          "https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ServicePayroll",
          [ApiVersion = 15]
      ),

      // Keep only .xlsx files from the Service Time Sheets library
      FilterLibrary = Table.SelectRows(Source, each
          Text.Contains([Folder Path], "Service Time Sheets") and
          Text.EndsWith([Name], ".xlsx") and
          not Text.StartsWith([Name], "~")  // exclude temp files
      ),

      // Parse Location from folder path (last folder segment before filename)
      AddLocation = Table.AddColumn(FilterLibrary, "Location", each
          let
              parts = Text.Split(Text.TrimEnd([Folder Path], "/"), "/"),
              loc = List.Last(parts)
          in loc,
          type text
      ),

      // Expand each Excel workbook to get all sheets
      AddWorkbook = Table.AddColumn(AddLocation, "Workbook", each
          Excel.Workbook([Content], null, true),
          type table
      ),

      ExpandSheets = Table.ExpandTableColumn(
          AddWorkbook,
          "Workbook",
          {"Name", "Data", "Kind"},
          {"SheetName", "SheetData", "Kind"}
      ),

      // Keep only Sheet kind (not DefinedName or Table)
      // Exclude the template tab and hidden config sheets
      FilterSheets = Table.SelectRows(ExpandSheets, each
          [Kind] = "Sheet" and
          not Text.StartsWith([SheetName], "_") and
          not Text.StartsWith([SheetName], "TEMPLATE")
      ),

      // Expand each sheet's data table
      ExpandData = Table.ExpandTableColumn(
          FilterSheets,
          "SheetData",
          Table.ColumnNames(FilterSheets{0}[SheetData])
      ),

      // At this point columns will match the template structure.
      // Rename columns from template display names to PascalCase Lakehouse names.
      // Adjust these names if the template column headers change.
      RenameColumns = Table.RenameColumns(ExpandData, {
          {"Customer Name", "CustomerName"},
          {"Model", "Model"},
          {"RO#", "RONumber"},
          {"% Complete", "PercentComplete"},
          {"Draw 1 Date", "Draw1Date"},
          {"Draw 1 Hrs", "Draw1Hrs"},
          {"Draw 2 Date", "Draw2Date"},
          {"Draw 2 Hrs", "Draw2Hrs"},
          {"Draw 3 Date", "Draw3Date"},
          {"Draw 3 Hrs", "Draw3Hrs"},
          {"Final Draw Date", "FinalDrawDate"},
          {"Final Draw Hrs", "FinalDrawHrs"},
          {"Current Period Hrs", "CurrentPeriodHrs"},
          {"After Hours", "AfterHours"}
      }),

      // Select and add all needed columns
      AddMetadata = Table.AddColumn(
          RenameColumns, "LoadTimestamp", each DateTimeZone.UtcNow(), type datetimezone
      ),

      // Pull header fields from the workbook-level header area
      // These are passed from the workbook header (Location, PayrollStartDate, etc.)
      // via the SheetName or additional parsing — see note below.
      // For now, Location comes from the folder path (already added above).
      // PayrollStartDate and PayrollEndDate are parsed from the filename.
      AddPayrollDates = Table.AddColumn(AddMetadata, "PayrollStartDate", each
          let
              // Filename format: "Location - YYYY-MM-DD to YYYY-MM-DD.xlsx"
              datePart = Text.BetweenDelimiters([Name], " - ", " to "),
              parsed = try Date.From(datePart) otherwise null
          in parsed,
          type date
      ),

      AddPayrollEndDate = Table.AddColumn(AddPayrollDates, "PayrollEndDate", each
          let
              datePart = Text.BetweenDelimiters([Name], " to ", ".xlsx"),
              parsed = try Date.From(datePart) otherwise null
          in parsed,
          type date
      ),

      // Add TechnicianName from the sheet tab name
      AddTechName = Table.AddColumn(AddPayrollEndDate, "TechnicianName", each [SheetName], type text),

      // Select only the columns going to the Lakehouse (drop binary Content etc.)
      SelectColumns = Table.SelectColumns(AddTechName, {
          "Location", "PayrollStartDate", "PayrollEndDate",
          "TechnicianName",
          "CustomerName", "Model", "RONumber", "PercentComplete",
          "Draw1Date", "Draw1Hrs", "Draw2Date", "Draw2Hrs",
          "Draw3Date", "Draw3Hrs", "FinalDrawDate", "FinalDrawHrs",
          "CurrentPeriodHrs", "AfterHours",
          "LoadTimestamp", "Name"
      }),

      // Rename Name to SourceFile
      RenameSourceFile = Table.RenameColumns(SelectColumns, {{"Name", "SourceFile"}}),

      // Remove rows with no RO# (blank rows from the 30-row pre-built table)
      RemoveBlanks = Table.SelectRows(RenameSourceFile, each
          [RONumber] <> null and [RONumber] <> "" and [RONumber] <> 0
      ),

      // Set final types
      SetTypes = Table.TransformColumnTypes(RemoveBlanks, {
          {"RONumber", Int64.Type},
          {"Draw1Hrs", type number}, {"Draw2Hrs", type number},
          {"Draw3Hrs", type number}, {"FinalDrawHrs", type number},
          {"CurrentPeriodHrs", type number}, {"AfterHours", type number},
          {"PercentComplete", type text}
      })

  in
      SetTypes
  ```

  > **Note on Tech Number and Pay Rate:** The workbook header data (Tech Number, Pay Rate, Branch, Level) sits in the header rows of each tab, not in the ROEntries table rows. After initial testing, you may need to extract these separately and join them back. If the header cells land in the expanded table as the first rows, filter them out and join from the `_Config` sheet or from the existing `Technician_Code_Names` Lakehouse table instead. The Lakehouse join is cleaner and keeps the query simpler.

- [ ] **Step 4: Map output to Lakehouse**

  In the Dataflow editor → Data destination → Lakehouse.
  - Workspace: LH_Master_Data workspace
  - Lakehouse: LH_Master_Data
  - Table name: `service_time_sheets`
  - Update method: Replace (full reload each run — submissions accumulate in SharePoint, we reload all each time for simplicity. If volume grows, switch to append with dedup.)

- [ ] **Step 5: Test the dataflow with the sample workbook**

  Upload the sample workbook from Task 4 (`Service Time Sheet SAMPLE - Lorenzo.xlsx`) to the Lorenzo folder on SharePoint.
  Run the dataflow manually.
  Verify in the Lakehouse:
  - Table `service_time_sheets` exists and has rows
  - `Location` = "Lorenzo"
  - `PayrollStartDate` and `PayrollEndDate` parsed correctly from filename
  - `TechnicianName` matches the tab names
  - `RONumber` populated, blank rows removed
  - `LoadTimestamp` present

- [ ] **Step 6: Save the Power Query to the project**

  Copy the final M query from the Advanced Editor.
  Save to: `projects/service time sheets/queries/df_ServiceTimeSheets_Raw.pq`

  Add the standard header comment at the top of the file:
  ```
  // Purpose: Read all service time sheet Excel workbooks from SharePoint,
  //          expand all technician tabs, normalize to one row per tech per RO per period.
  // Grain: One row per technician per RO per pay period
  // Source: SharePoint - SouthPlainsImplement-ServicePayroll / Service Time Sheets /
  // Output: LH_Master_Data.service_time_sheets
  // Dependencies: Finalized Excel template (column names must match)
  ```

- [ ] **Step 7: Add to pipeline schedule**

  Open Pipeline_Master_Orchestrator in Fabric.
  Add `df_ServiceTimeSheets_Raw` to Phase 1 (Raw Sources), in whichever wave has available CU capacity.
  It reads from SharePoint (not ODBC), so it won't compete with the ODBC raw source queries.
  Estimated runtime: under 2 minutes for all 13 locations.

- [ ] **Step 8: Commit the query file**

  ```bash
  git add "projects/service time sheets/queries/df_ServiceTimeSheets_Raw.pq"
  git commit -m "feat(service-time-sheets): add Fabric Dataflow Power Query for SharePoint ingestion"
  ```

---

## Task 6: Build the Semantic Model

**What:** Create a Power BI semantic model connecting `service_time_sheets` to the existing source system and dimension tables. Build all DAX measures.

**Files/Resources:**
- New PBIP project: `projects/service time sheets/report/Service Time Sheets.pbip`
- Connects to: `LH_Master_Data.service_time_sheets`, `TechnicianInvoiceDetailServiceForm` (existing), `Technician_Code_Names` (existing), `dim_BranchLocation` (existing), `dim_DateTable` (existing)

- [ ] **Step 1: Create new Power BI Desktop project**

  Open Power BI Desktop → New → Save as PBIP format.
  Save to: `projects/service time sheets/report/Service Time Sheets.pbip`

- [ ] **Step 2: Connect to data sources**

  Get Data → Fabric (or SQL Server with the Fabric warehouse endpoint):

  **Table 1 — service_time_sheets** (from LH_Master_Data Lakehouse):
  ```
  Source: LH_Master_Data Lakehouse SQL endpoint
  Query: SELECT * FROM service_time_sheets
  ```

  **Table 2 — TechnicianInvoiceDetailServiceForm** (existing, from Fabric warehouse):
  The endpoint below is from the old prototype TMDL — verify it's still active before use.
  If it has changed, find the current endpoint in Power BI Desktop by opening an existing
  Service Reports report → Transform Data → check the source step of this table.
  ```
  Source: xcrafcusadsu3d3wi4anbgp6we-h4diddse4pienf2bknp7qv3ade.datawarehouse.fabric.microsoft.com
  Database: LH_Financial_Report_Data
  Table: dbo.TechnicianInvoiceDetailServiceForm
  ```
  Columns: Branch, RepairOrderNumber, InvoiceNumber, TechnicianCode, InvoiceDate, HoursPunched, InvoiceHours, LaborCost, LaborSale

  **Table 3 — Technician_Code_Names** (existing):
  ```
  Source: xcrafcusadsu3d3wi4anbgp6we-wczpfb6a52fude7azc6zsgeuty.datawarehouse.fabric.microsoft.com
  Database: LH_Service_Reports_Data
  Table: dbo.Technician_Code_Names
  ```

  **Table 4 — dim_BranchLocation** and **dim_DateTable**: import from LH_Master_Data as used in other reports.

- [ ] **Step 3: Create relationships**

  In the Model view, create the following relationships:

  | From | To | Cardinality | Direction |
  |---|---|---|---|
  | `service_time_sheets[Location]` | `dim_BranchLocation[BranchName]` | Many:1 | Single |
  | `service_time_sheets[PayrollStartDate]` | `dim_DateTable[Date]` | Many:1 | Single |
  | `TechnicianInvoiceDetailServiceForm[InvoiceDate]` | `dim_DateTable[Date]` | Many:1 | Single |

  Do NOT create a direct relationship between `service_time_sheets` and `TechnicianInvoiceDetailServiceForm` on RO number — this is a many-to-many and should be resolved in DAX using CALCULATE + FILTER, not a model relationship.

- [ ] **Step 4: Create the Measures table and write all DAX measures**

  Create a calculated table `_Measures` with `_Measures = ROW("x", 1)`.
  Add all measures to this table:

  ```dax
  Submitted Hours =
  SUM(service_time_sheets[CurrentPeriodHrs])
  ```

  ```dax
  Invoiced Hours =
  SUM(TechnicianInvoiceDetailServiceForm[InvoiceHours])
  ```

  ```dax
  Hours Difference =
  [Invoiced Hours] - [Submitted Hours]
  ```

  ```dax
  Total Draws =
  SUM(service_time_sheets[Draw1Hrs])
      + SUM(service_time_sheets[Draw2Hrs])
      + SUM(service_time_sheets[Draw3Hrs])
      + SUM(service_time_sheets[FinalDrawHrs])
  ```

  ```dax
  Pay Rate =
  MAX(service_time_sheets[PayRate])
  ```

  ```dax
  Tech Pay =
  [Submitted Hours] * [Pay Rate]
  ```

  ```dax
  Labor Billed =
  [Invoiced Hours] * [Pay Rate]
  ```

  ```dax
  Paid Difference =
  [Labor Billed] - [Tech Pay]
  ```

  ```dax
  Cumulative Draws on RO =
  VAR _RO = MAX(service_time_sheets[RONumber])
  RETURN
  CALCULATE(
      [Total Draws],
      ALL(service_time_sheets[PayrollStartDate]),
      service_time_sheets[RONumber] = _RO
  )
  ```

  ```dax
  Hours Difference Color =
  IF([Hours Difference] < -0.01, "#E68F96", BLANK())
  ```

  ```dax
  Paid Difference Color =
  IF([Paid Difference] < -0.01, "#E68F96", BLANK())
  ```

  ```dax
  Draws Exceed Invoice Flag =
  IF([Cumulative Draws on RO] > [Invoiced Hours], "#E68F96", BLANK())
  ```

- [ ] **Step 5: Validate measures with known data**

  Using the sample Lorenzo data uploaded in Task 5:
  - Create a simple table visual with TechnicianName, Submitted Hours
  - Verify the totals match what's in the sample workbook (Nick Nunley = 107.2 hrs per the CSV)
  - Check that Hours Difference and Paid Difference calculate without errors
  - Check that Cumulative Draws on RO shows the correct draw total per RO

- [ ] **Step 6: Export TMDL and commit**

  Use `pbi database export-tmdl ./tmdl` from pbi-cli (requires Desktop open).
  Copy exported TMDL files to:
  `projects/service time sheets/report/Service Time Sheets.SemanticModel/definition/`

  ```bash
  git add "projects/service time sheets/report/"
  git commit -m "feat(service-time-sheets): add semantic model with measures"
  ```

---

## Task 7: Build the Power BI Report

**What:** Build the 4-page report laid out in the spec.

**Files/Resources:**
- Existing PBIP: `projects/service time sheets/report/Service Time Sheets.pbip`
- Reference: old prototype report in `projects/service time sheets/report example - old/`

- [ ] **Step 1: Page 1 — Pay Period Summary**

  Add slicers: Pay Period (from `service_time_sheets[PayrollStartDate]`), Location, Technician Name.

  Add a Matrix visual:
  - Rows: Technician Name
  - Values: Submitted Hours, Invoiced Hours, Hours Difference, Total Draws, Labor Billed, Tech Pay, Paid Difference
  - Conditional formatting on Hours Difference: background color from `Hours Difference Color` measure
  - Conditional formatting on Paid Difference: background color from `Paid Difference Color` measure

  Add summary KPI cards at top:
  - Total Submitted Hours (all techs in filter context)
  - Total Invoiced Hours
  - Net Paid Difference ($)

- [ ] **Step 2: Page 2 — RO Detail (drill-through from Page 1)**

  Set page as drill-through: Drill-through fields → Technician Name.

  Add a Table visual:
  - Columns: RO#, Customer Name, Model, % Complete, Draw 1 Hrs, Draw 2 Hrs, Draw 3 Hrs, Final Draw Hrs, Current Period Hrs, Invoiced Hours, Cumulative Draws on RO, Hours Difference
  - Conditional formatting on Hours Difference: `Hours Difference Color`
  - Conditional formatting on Cumulative Draws on RO: `Draws Exceed Invoice Flag`

  Add a note visual (text box): "ROs showing in red have cumulative draws that exceed invoiced hours."

- [ ] **Step 3: Page 3 — Draw Tracking**

  This page tracks an RO's draw history across multiple pay periods.

  Add slicers: RO# (free-text slicer or search slicer), Technician Name, Location.

  Add a Table visual:
  - Columns: Pay Period, Technician Name, RO#, Customer, Draw 1 Hrs, Draw 2 Hrs, Draw 3 Hrs, Final Draw Hrs, Cumulative Draws on RO, Invoiced Hours (when available), Draws Exceed Invoice Flag
  - Sort by Pay Period descending

  Add a Line chart: X = Pay Period, Y = Cumulative Draws on RO vs. Invoiced Hours (two lines). Shows visually when draws cross the invoice amount.

- [ ] **Step 4: Page 4 — Location Summary**

  Add a Matrix:
  - Rows: Location, Technician Name (expandable hierarchy)
  - Columns: Pay Period (most recent 4)
  - Values: Submitted Hours, Paid Difference
  - Background conditional formatting on Paid Difference

  Intended audience: Corp Service Manager. Shows all locations at a glance.

- [ ] **Step 5: Apply consistent formatting**

  Match existing report style (use the existing prototype's theme file as reference):
  `projects/service time sheets/report example - old/Service Time Sheet.Report/StaticResources/SharedResources/BaseThemes/CY22SU11.json`

  Apply to the new report: View → Themes → Browse → select that file.

- [ ] **Step 6: Commit the report**

  ```bash
  git add "projects/service time sheets/report/"
  git commit -m "feat(service-time-sheets): add Power BI report with 4 pages"
  ```

---

## Task 8: Configure RLS and Publish

> **Note on Power BI access for HR:** This task depends on the decision from Starred Blocker E. If HR is getting Power BI Pro licenses, add them as Viewers in this step. If not, configure the report for Corp Service Manager access only and revisit.

**What:** Set up Row Level Security so location managers (if given report access in future) only see their location. Publish to the correct workspace.

**Files/Resources:**
- PBIP: `projects/service time sheets/report/Service Time Sheets.pbip`
- Target workspace: RP - Service Reports (production) or RP - Sandbox (testing first)

- [ ] **Step 1: Create RLS roles in Power BI Desktop**

  Modeling tab → Manage Roles → New Role: `LocationManager`

  Add the following DAX filter to `service_time_sheets`:
  ```dax
  [Location] = USERPRINCIPALNAME()
  ```
  > This is a placeholder — it works if UPN = location name, which it won't. In practice, create a mapping table `_RLS_LocationMap` with columns `UserEmail` and `Location`, then use:
  ```dax
  [Location] IN
  CALCULATETABLE(
      VALUES(_RLS_LocationMap[Location]),
      _RLS_LocationMap[UserEmail] = USERPRINCIPALNAME()
  )
  ```

  Create `_RLS_LocationMap` as a calculated table or static import:
  ```dax
  _RLS_LocationMap =
  DATATABLE(
      "UserEmail", STRING,
      "Location", STRING,
      {
          {"manager-lorenzo@spitractor.com", "Lorenzo"},
          {"manager-abernathy@spitractor.com", "Abernathy"}
          // ... add all 13 location managers once emails are confirmed
      }
  )
  ```
  Add similar filters to `TechnicianInvoiceDetailServiceForm[Branch]` for the LocationManager role.

  Create a second role: `HRPayroll` — no filters (sees everything).
  Create a third role: `Management` — no filters (sees everything).

- [ ] **Step 2: Test RLS**

  In Desktop: Modeling → View as → LocationManager.
  Verify only Lorenzo data shows (or whichever location is mapped in the test).
  Switch to HRPayroll role — verify all locations show.

- [ ] **Step 3: Publish to RP - Sandbox first**

  File → Publish → RP - Sandbox.
  In the workspace, open the dataset → Security → assign roles:
  - `HRPayroll`: HR Director email, Payroll Specialist email
  - `Management`: Corp Service Manager email, CFO email
  - `LocationManager`: location manager emails (as gathered in Task 2)

- [ ] **Step 4: Validate in the browser**

  Open the published report in the browser as yourself.
  Verify all 4 pages load, slicers work, drill-through works from Page 1 to Page 2.

- [ ] **Step 5: After sandbox validation, promote to production**

  Follow the standard deployment workflow from CLAUDE.md:
  - Publish to RP - Service Reports (production workspace)
  - In Fabric workspace → Git integration → Commit → pushes to fabric-workspace-docs/dev
  - Open PR dev → main in fabric-workspace-docs

---

## Task 9: User Acceptance Testing and Go-Live

**What:** Run a pilot with one location before rolling out to all 13, then go live.

- [ ] **Step 1: Select a pilot location**

  Recommend Lorenzo — largest location (11 techs), most representative test.
  Coordinate with the Corp Service Manager to select the pilot contact.

- [ ] **Step 2: Prepare the pilot submission package**

  Provide the Lorenzo manager with:
  - The pre-built workbook template (or a Lorenzo-specific copy with the template tab already set to Lorenzo)
  - A one-page instruction sheet (printed + emailed): how to fill out, how to name the file, where to save it
  - The SharePoint link bookmarked to their location folder
  - Brian's contact info for questions

- [ ] **Step 3: Run the pilot for one pay period**

  Lorenzo manager submits their workbook through the new process.
  Verify end-to-end:
  - File lands in SharePoint Lorenzo folder
  - Power Automate notification email arrives at HR within 2 minutes
  - After pipeline refresh: `service_time_sheets` Lakehouse table updated
  - Power BI report shows Lorenzo data, measures calculate correctly
  - RO comparison data appears correctly (submitted vs. invoiced)

- [ ] **Step 4: Gather pilot feedback and fix issues**

  Meet with the Lorenzo manager and HR Director.
  Document any template issues, confusion points, or missing data.
  Fix and re-test before rolling out to all 13 locations.

- [ ] **Step 5: Roll out to all 13 locations**

  Provide each location manager with the same submission package.
  Stagger the rollout over 2–3 pay periods if needed to avoid support overload.

- [ ] **Step 6: Mark "Technician Pay Tracking" complete in todo.md**

  Update `C:/Users/bfox/todo.md` — move the "Technician Pay Tracking — meet with HR" item to Completed.
  Update `todo.html` to match.

  ```bash
  git add todo.md todo.html
  git commit -m "chore: mark Technician Pay Tracking complete"
  ```

---

## Summary of What Can Start Now vs. What Is Blocked

| Task | Can Start? | Blocked On |
|---|---|---|
| Task 1 — SharePoint site | ✅ Now | Blocker F (site name) — use suggested name and rename if needed |
| Task 2 — Folders + permissions | ✅ After Task 1 | Manager email addresses (get from Corp SM) |
| Task 3 — Power Automate flow | ✅ After Task 2 | HR email addresses (easy to get) |
| Task 4 — Excel template | ⚠ After blockers A–D answered | Mileage locations, after hours, pay rates |
| Task 5 — Fabric Dataflow | ⚠ After Task 4 | Template must be finalized |
| Task 6 — Semantic model | ⚠ After Task 5 | Dataflow must produce data |
| Task 7 — Report | ⚠ After Task 6 | Semantic model must exist |
| Task 8 — RLS + publish | ⚠ After Task 7 + Blocker E | Power BI access decision for HR |
| Task 9 — UAT + go-live | ⚠ After Task 8 | All above complete |
