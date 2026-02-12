/*
============================================================================
Query: Branch_Name (Raw)
Dataflow: [No dataflow - manual/on-demand refresh]
Location: LH_Master_Data → Lakehouse (loaded on-demand)
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Branch/location master data - foundation for dim_BranchLocation dimension
Created: [Unknown - pre-dates current documentation]
Last Modified: 12/30/2025 (recently - 1/13/2026 in data)
Output: Lakehouse table "Branch_Name"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: On-demand only (typically once per month or less)
Average Refresh Time: ~1 minute 12 seconds (1:12)
Refresh Strategy: Full refresh (no incremental - rarely changes)
Row Count: 99 rows (as of 1/14/2026)
Query Folding: ✅ YES (ODBC DataSource with hierarchical navigation)

✅ NO PERFORMANCE ISSUES - EFFICIENT AS-IS

**Why No Regular Schedule:**
• Branch/location data rarely changes (new branches are infrequent)
• 99 rows is tiny - refresh takes only 1:12 minutes
• On-demand refresh is appropriate for this use case
• Manual refresh when business notifies of new branch or location changes

🎯 BUSINESS USE CASES:
• Dimension Foundation: Primary (and likely only) source for dim_BranchLocation dimension
• Branch Management: Complete branch/location master data
• Contact Information: Branch addresses, phones, emails
• Territory Management: Branch types, main branch relationships
• Service Management: Workshop configuration (bays, loan cars)
• Parts Management: Inventory transfer rules, bin configuration
• Financial Accounting: Department, account, sub-account assignments per branch
• Survey Management: Parts, workshop, sales, rental survey counts

📊 DATA STRUCTURE (104 COLUMNS - EXTENSIVE!):

**Core Branch Identification:**
• branch: Branch code/number (key field)
• name: Branch name
• Branch_Type: Branch type classification (M = Main, etc.)
• Main_Branch_Code: Main branch reference
• Company: Company code

**Contact Information:**
• street: Street address
• city: City
• state: State
• pcode: Postal code
• phone_bus: Business phone
• phone_home: Home phone (typically null)
• phone_mob: Mobile phone
• email_address: Email address
• Contact_Code: Contact code reference

**Branch Management:**
• branch_manager: Branch manager name
• Polling_Unit: Polling unit classification
• MISC_CODE: Miscellaneous code
• AUTHORITY_GP: Authority group
• FR_LOC_INDICATOR: Franchise location indicator

**Workshop/Service Configuration:**
• wshop_no_of_bays: Number of workshop bays
• no_of_loan_cars: Number of loan cars available
• Loan_Car_Br: Loan car branch reference
• workshop_inv_message: Workshop invoice message
• time_adjust_minute: Time adjustment in minutes

**Workshop Charge Structures (3 types: P, L, PL):**
• p_wkshop_charge_desc: Parts workshop charge description
• p_wkshop_charge_rate: Parts workshop charge rate
• p_wkshop_charge_min: Parts workshop charge minimum
• p_wkshop_charge_max: Parts workshop charge maximum
• Auto_Apply_P_Wkshop_Charge: Auto-apply parts workshop charge flag
• (Similar fields for L and PL types)

**Parts/Inventory Management:**
• parts_inv_message: Parts invoice message
• Default_Supplier_code: Default supplier
• Display_Qty_In_Barcode: Display quantity in barcode flag
• Suggest_Bin_Days: Suggested bin days
• Random_Bin_Days: Random bin days
• Random_Bin_No: Random bin number
• Random_Bin_Count: Random bin count
• Receipting_Auto_Issue_Ind: Auto-issue indicator
• Receipting_Upd_Desc_Ind: Update description indicator
• Receipting_Upd_Alt_Part_Ind: Update alternate part indicator

**Parts Transfer Rules (XML fields - complex configuration):**
• Transfer_In: XML configuration for parts transfer in rules
• Transfer_Out: XML configuration for parts transfer out rules
  - Includes: Max/Min month supply, extended value limits
  - ReOrder code inclusions/exclusions
  - Activity code inclusions/exclusions
  - SLC (Service Level Code) rules
  - Source rules
  - Dealer group code rules
  - Commodity code rules
  - Bin location rules

**Financial/Accounting Assignments (Multiple departments):**
• Sales: Sales_COY, Sales_Branch, Sales_Dept, Sales_Acct, Sales_Sub_Acct
• Parts: Parts_COY, Parts_Branch, Parts_Dept, Parts_Acct, Parts_Sub_Acct
• Service: Service_COY, Service_Branch, Service_Dept, Service_Acct, Service_Sub_Acct
• Solution: Solution_COY, Solution_Branch, Solution_Dept, Solution_Acct, Solution_Sub_Acct
• SVAP: SVAP_COY, SVAP_BRANCH, SVAP_DEPT, SVAP_ACCT, SVAP_SUB_ACCT
• Stamp Duty: fas_stamp_duty_* fields (multiple)

**Survey Management:**
• Parts_Survey_Count: Parts survey count
• Wkshop_Survey_Count: Workshop survey count
• sales_survey_count: Sales survey count
• Rental_Survey_Count: Rental survey count
• Survey_Month: Survey month

**Business Process Configuration:**
• Quote_Exp_Days: Quote expiration days
• SCAN_TO_TRUCK_IND: Scan to truck indicator
• ALLOW_NEG_AGREEMENT: Allow negative agreement flag
• dtf_path: DTF file path (\\EQSVC01-SP2010\APPS\JDIS\PROG\COMM\UPLOAD)

**Tax & Regulatory:**
• Tax_Region: Tax region code
• trader_regn_no: Trader registration number
• police_book_dealer_code: Police book dealer code

**Labor/Scheduling Configuration:**
• Bf_Hours_Per_Day: Billable hours per day
• Bf_Days_Per_Week: Billable days per week
• Bf_Weeks_Per_Month: Billable weeks per month
• Rd_Days_Per_Week: RD days per week
• Rd_Days_Per_Month: RD days per month
• Rd_Calendar_Month_Ind: Calendar month indicator

**Territory & Market:**
• LMCT: LMCT code
• RUCD: RUCD code

**Timeline Intelligence:**
• CreationDate: Branch creation date
• ModifiedDate: Last modification date (important: shows 1/13/2026 - recent!)

🔧 DESIGN PRINCIPLES:

**True Raw Table - NO Column Renaming:**
• Unlike other raw tables, this one preserves exact source column names
• No PascalCase standardization applied
• Column names kept as-is from SQL Anywhere
• Reason: Dimension building (dim_BranchLocation) handles normalization
• This is the "truest" raw table in the entire system

**Simple Navigation-Based Query:**
• Uses hierarchical navigation (not SQL query)
• Three-step navigation: DataSource → Schema → Table
• Entire table loaded as-is
• No filtering, no transformations, no column selection

**Infrequent Refresh by Design:**
• Branch/location master data changes rarely
• New branches added infrequently (business expansion is slow)
• Location info rarely updates (addresses, phones relatively stable)
• On-demand refresh when business reports changes

**ModifiedDate Available:**
• ModifiedDate field exists and is current (1/13/2026 - yesterday!)
• Could implement incremental refresh if frequent updates needed
• Current on-demand approach is more appropriate given low change frequency

⚠️ IMPORTANT NOTES:

**Dimension Dependency:**
• This is the PRIMARY (likely only) source for dim_BranchLocation dimension
• dim_BranchLocation is used in ALL reports (critical!)
• If Branch_Name not refreshed, dim_BranchLocation will be stale
• Business must notify when new branches added or info changes

**Complex XML Fields:**
• Transfer_In and Transfer_Out contain XML configuration
• These define parts inventory transfer rules between branches
• May not be used in current reporting but critical for operations
• XML parsing may be needed if these fields required in future analytics

**No Dataflow:**
• Unlike other raw tables, this doesn't have a dedicated dataflow
• Loaded manually/on-demand into Lakehouse
• Not part of any pipeline
• Refresh triggered manually when needed

**Data Sample Provided:**
• Branch 1 = Seminole, TX (79360)
• Shows full complexity of XML Transfer_In/Transfer_Out fields
• ModifiedDate: 1/13/2026 (yesterday!) - something was recently updated
• CreationDate: 8/13/2019 - original branch setup

**CU Optimization:**
• Current approach (on-demand) is optimal
• 1:12 refresh for 99 rows is negligible CU consumption
• No benefit to incremental refresh or scheduled refresh
• Keep as on-demand

🔄 REFRESH WORKFLOW:

**When to Refresh:**
1. Business notifies of new branch opening
2. Business notifies of branch closure or merger
3. Branch contact information changes (address, phone, email)
4. Monthly check-in with operations (is anything changed?)
5. Before refreshing dim_BranchLocation dimension (if stale)

**How to Refresh:**
1. Run dataflow manually (on-demand)
2. Takes ~1:12 minutes
3. Verify row count (should be 99 or close)
4. After Branch_Name refresh, refresh dim_BranchLocation dimension
5. After dim_BranchLocation refresh, refresh any reports using it (ALL reports!)

Dependencies:
• None (direct source system table)

Used By:
• df_Dim_BranchLocation (primary use - critical!)
• dim_BranchLocation dimension (all reports depend on this!)

Critical Path:
Branch_Name → dim_BranchLocation → ALL REPORTS

============================================================================
*/

let
    // ========================================================================
    // HIERARCHICAL NAVIGATION - TRUE RAW TABLE (NO TRANSFORMATIONS)
    // ========================================================================
    /*
    STRATEGY: Load entire Branch_Name table as-is from source
    APPROACH: Hierarchical navigation (DataSource → Schema → Table)
    DESIGN: True raw table - NO column renaming or transformations
    FREQUENCY: On-demand only (branch data changes rarely)
    */

    Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
    #"Navigation 1" = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Name = "Branch_Name", Kind = "Table"]}[Data]

in
    #"Navigation 2"

/*
============================================================================
✅ PRODUCTION STATUS: OPTIMAL - NO CHANGES NEEDED
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Complete Column Set: All 104 source columns loaded as-is
• No Transformations: True raw table (dimension handles normalization)
• Simple Query: Three-step hierarchical navigation
• On-Demand Refresh: Appropriate for infrequently changing data

✅ PERFORMANCE: EXCELLENT
• 1:12 minutes for 99 rows is efficient
• No scheduled refresh needed (saves CU consumption)
• On-demand approach is optimal for this use case

🔍 KEY CHARACTERISTICS:

**Data Stability:**
• 99 branches (relatively stable count)
• New branches are rare (business expansion is slow)
• Location data rarely changes
• ModifiedDate shows recent update (1/13/2026) but typically infrequent

**Critical Dependency:**
• Foundation for dim_BranchLocation (used in ALL reports!)
• Must be refreshed before dim_BranchLocation if data changes
• Business must notify of new branches or location changes
• Failure to refresh could cause missing branches in all reports

**Data Complexity:**
• 104 columns (most extensive raw table)
• XML fields (Transfer_In, Transfer_Out) with complex configuration
• Financial assignments across multiple departments (Sales, Parts, Service, Solution, SVAP)
• Workshop charge structures (P, L, PL types)

**No Optimization Needed:**
• Current approach is optimal for this data pattern
• 1:12 refresh time is negligible
• On-demand is more efficient than scheduled
• No incremental refresh benefit (entire table loads fast)

📝 BUSINESS PROCESS:

**Refresh Triggers:**
1. New branch opens → Notify data team → Manual refresh
2. Branch closes or merges → Notify data team → Manual refresh
3. Contact info changes → Notify data team → Manual refresh (if needed for reports)
4. Monthly operations check-in → Ask "any branch changes?" → Refresh if yes

**Downstream Impact:**
• After Branch_Name refresh → Refresh dim_BranchLocation
• After dim_BranchLocation refresh → Refresh all reports (or wait for scheduled refresh)
• Missing refresh = stale branch data in ALL reports

💡 RECOMMENDATIONS:

**Current State: OPTIMAL**
• Keep on-demand refresh approach
• Keep true raw table design (no transformations)
• Keep simple hierarchical navigation query

**Process Improvement:**
• Create business notification process for branch changes
• Document downstream refresh process (Branch_Name → dim_BranchLocation → Reports)
• Monthly check-in with operations to catch any missed branch changes

**Future Consideration:**
• If branches start changing frequently (rapid expansion), consider scheduled weekly refresh
• XML fields (Transfer_In/Transfer_Out) may be valuable for future advanced analytics
• ModifiedDate field could enable change detection if needed

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: On-demand (typically monthly or less)
• Data Completeness: All 104 source columns preserved
• No Transformations: True raw table design
• Critical Dependency: Foundation for dim_BranchLocation (all reports!)
• Performance: Excellent (1:12 for 99 rows)
• CU Impact: Negligible (on-demand only)

============================================================================
*/
