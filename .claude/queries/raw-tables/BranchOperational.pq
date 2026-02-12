/*
============================================================================
Query: BranchOperational (Raw)
Dataflow: df_BranchOperational_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64) - VIEW
Purpose: Operational branch data - supplemental source for dim_BranchLocation dimension
Created: [Unknown - pre-dates current documentation]
Last Modified: 07/02/2025
Output: Lakehouse table "BranchOperational"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: On-demand only (typically once per month or less)
Average Refresh Time: ~1 minute 20 seconds (1:20)
Refresh Strategy: Full refresh (no incremental - rarely changes)
Row Count: 99 rows (as of 1/14/2026)
Query Folding: ✅ YES (ODBC DataSource with hierarchical navigation + column selection)

✅ NO PERFORMANCE ISSUES - EFFICIENT AS-IS

**Why No Regular Schedule:**
• Branch operational data rarely changes (same as Branch_Name)
• 99 rows is tiny - refresh takes only 1:20 minutes
• On-demand refresh is appropriate for this use case
• Manual refresh when business notifies of changes or when refreshing Branch_Name

🎯 BUSINESS USE CASES:
• Dimension Foundation: Supplemental source for dim_BranchLocation dimension (along with Branch_Name)
• Relationship Establishment: **LocationID is the key field for establishing relationships in dim_BranchLocation!**
• Branch Identification: Provides BranchID and BranchName mapping
• Geographic Context: State and City information

📊 DATA STRUCTURE (5 COLUMNS - MINIMAL & FOCUSED):

**Branch Identification:**
• BranchID: Branch identifier
• BranchName: Branch name

**Key Relationship Field:**
• **LocationID: CRITICAL - Used to establish relationships in dim_BranchLocation to other tables on Branch**
  - This is the relationship key field
  - Other tables join to dim_BranchLocation using Branch → LocationID mapping
  - Without LocationID, relationships break down

**Geographic Information:**
• State: State abbreviation
• City: City name

🔧 DESIGN PRINCIPLES:

**Column Selection Applied:**
• Unlike Branch_Name (loads all columns), this query selects only 5 columns
• Focused on relationship and geographic data
• Table.SelectColumns() step added after navigation
• More efficient than loading entire view

**View vs Table:**
• Source is a VIEW (not a table like Branch_Name)
• Views typically provide curated/calculated data
• BranchOperational view likely joins/aggregates underlying tables
• May explain why both Branch_Name and BranchOperational exist

**Hierarchical Navigation:**
• Same navigation pattern as Branch_Name
• Three-step: DataSource → Schema → View (note: View, not Table)
• Then column selection step added

**Infrequent Refresh by Design:**
• Same reasoning as Branch_Name (branch data rarely changes)
• 99 rows matches Branch_Name row count (same branches)
• On-demand refresh when branch data changes

**Paired with Branch_Name:**
• Branch_Name provides extensive branch configuration (104 columns)
• BranchOperational provides relationship keys and geographic summary (5 columns)
• Together they form complete branch master data for dim_BranchLocation

⚠️ IMPORTANT NOTES:

**Dimension Dependency:**
• Supplemental source for dim_BranchLocation (along with Branch_Name)
• **LocationID is CRITICAL for relationships** - most important field!
• dim_BranchLocation is used in ALL reports
• Must refresh when Branch_Name is refreshed (keep in sync)

**LocationID Relationship Pattern:**
```
Fact/Dimension Tables (have Branch field)
    ↓ (join on Branch → LocationID)
dim_BranchLocation (has LocationID from BranchOperational)
    ↓ (provides branch context)
ALL REPORTS
```

**Row Count Matches Branch_Name:**
• Both have 99 rows (same branches)
• One-to-one relationship expected between tables
• If row counts differ, investigate missing branches

**Refresh Coordination:**
• When Branch_Name refreshes → Also refresh BranchOperational
• When BranchOperational refreshes → Also refresh dim_BranchLocation
• Keep all three in sync to avoid relationship issues

**View Source Consideration:**
• BranchOperational is a VIEW (not base table)
• View may have underlying complexity not visible here
• View definition maintained in SQL Anywhere database
• If relationship issues occur, may need to investigate view definition

**CU Optimization:**
• Current approach (on-demand) is optimal
• 1:20 refresh for 99 rows with 5 columns is negligible CU consumption
• Column selection (5 of potentially many) is good practice
• No benefit to scheduled refresh or incremental refresh
• Keep as on-demand

🔄 REFRESH WORKFLOW:

**When to Refresh:**
1. Same triggers as Branch_Name:
   - Business notifies of new branch opening
   - Business notifies of branch closure or merger
   - Monthly check-in with operations
2. **Always refresh together with Branch_Name** (keep in sync)
3. Before refreshing dim_BranchLocation dimension

**How to Refresh:**
1. Run df_BranchOperational_Raw dataflow manually (on-demand)
2. Takes ~1:20 minutes
3. Verify row count matches Branch_Name (should be 99)
4. After both Branch_Name and BranchOperational refresh, refresh dim_BranchLocation
5. After dim_BranchLocation refresh, refresh any reports using it (ALL reports!)

**Refresh Order:**
```
1. Branch_Name (1:12 min)
2. BranchOperational (1:20 min) - can run in parallel with #1
3. dim_BranchLocation (after both complete)
4. Reports (after dim_BranchLocation)
```

Dependencies:
• None directly (view in SQL Anywhere)
• Paired with Branch_Name (should refresh together)

Used By:
• df_Dim_BranchLocation (supplemental source alongside Branch_Name)
• dim_BranchLocation dimension (all reports depend on this!)

Critical Path:
Branch_Name + BranchOperational → dim_BranchLocation → ALL REPORTS

============================================================================
*/

let
    // ========================================================================
    // HIERARCHICAL NAVIGATION WITH COLUMN SELECTION - FOCUSED RAW DATA
    // ========================================================================
    /*
    STRATEGY: Load only necessary columns from BranchOperational view
    APPROACH: Hierarchical navigation (DataSource → Schema → View) + Column selection
    DESIGN: Focused on relationship key (LocationID) and geographic data
    FREQUENCY: On-demand only (branch data changes rarely)
    KEY FIELD: LocationID - critical for establishing relationships in dim_BranchLocation
    */

    Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
    #"Navigation 1" = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[Name = "BranchOperational", Kind = "View"]}[Data],
    #"Choose columns" = Table.SelectColumns(#"Navigation 2", {"BranchID", "BranchName", "LocationID", "State", "City"})

in
    #"Choose columns"

/*
============================================================================
✅ PRODUCTION STATUS: OPTIMAL - NO CHANGES NEEDED
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Focused Column Set: Only 5 essential columns selected
• Column Selection: Efficient - loads only what's needed
• Simple Query: Hierarchical navigation + column selection
• On-Demand Refresh: Appropriate for infrequently changing data

✅ PERFORMANCE: EXCELLENT
• 1:20 minutes for 99 rows is efficient
• Column selection reduces data transfer (5 of potentially many columns)
• No scheduled refresh needed (saves CU consumption)
• On-demand approach is optimal for this use case

🔍 KEY CHARACTERISTICS:

**Data Stability:**
• 99 branches (matches Branch_Name exactly)
• Branch data rarely changes
• Row count should always match Branch_Name
• If mismatch, investigate missing or extra branches

**Critical Relationship Field:**
• **LocationID is the most important field in this table**
• Used to establish relationships in dim_BranchLocation
• Other tables join on Branch → LocationID mapping
• Without correct LocationID, ALL report relationships break
• Example relationship pattern:
  ```
  Fact_InTrans.Branch → dim_BranchLocation.LocationID → Branch context
  jdis_Part_Information.Branch → dim_BranchLocation.LocationID → Branch context
  ```

**Complementary to Branch_Name:**
• Branch_Name: Extensive configuration (104 columns)
• BranchOperational: Relationship keys and geography (5 columns)
• Together: Complete branch master for dim_BranchLocation
• Both needed for full dimension build

**View vs Table:**
• Source is VIEW (not base table)
• View may aggregate or transform underlying data
• View definition maintained in SQL Anywhere
• More abstracted than Branch_Name (which is base table)

**No Optimization Needed:**
• Current approach is optimal for this data pattern
• 1:20 refresh time is negligible
• Column selection is best practice (don't load unnecessary columns)
• On-demand is more efficient than scheduled
• No incremental refresh benefit (entire view loads fast)

📝 BUSINESS PROCESS:

**Refresh Triggers (Same as Branch_Name):**
1. New branch opens → Refresh both Branch_Name and BranchOperational
2. Branch closes or merges → Refresh both
3. Branch info changes → Refresh both (keep in sync)
4. Monthly operations check-in → Refresh both if any changes

**Downstream Impact:**
• BranchOperational refresh → Must refresh dim_BranchLocation
• dim_BranchLocation refresh → Affects ALL reports (branch relationships)
• Missing refresh = broken relationships in all reports

**Sync with Branch_Name:**
• **Critical: Always refresh both together**
• Row counts should match (99 = 99)
• If out of sync, dim_BranchLocation may have incomplete data
• Consider creating process to refresh both simultaneously

💡 RECOMMENDATIONS:

**Current State: OPTIMAL**
• Keep on-demand refresh approach
• Keep column selection (efficient practice)
• Keep simple hierarchical navigation query

**Process Improvement:**
• Document "Branch Master Refresh Process":
  1. Refresh Branch_Name (1:12)
  2. Refresh BranchOperational (1:20) - parallel with #1
  3. Refresh dim_BranchLocation (after both complete)
  4. Refresh reports (or wait for scheduled)
• Create checklist to ensure both tables refreshed together
• Verify row counts match after refresh (99 = 99)

**Quality Check:**
• After refresh, verify: SELECT COUNT(*) WHERE LocationID IS NULL
• LocationID should never be null (critical relationship field)
• If nulls found, investigate view definition or source data issue

**Future Consideration:**
• If branches start changing frequently, schedule weekly refresh
• If scheduled, ensure both Branch_Name and BranchOperational refresh together
• Consider consolidating into single dataflow if always refreshed together

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: On-demand (typically monthly or less)
• Data Completeness: 5 essential columns (focused, efficient)
• Column Selection: Best practice applied
• Critical Dependency: LocationID for ALL report relationships
• Performance: Excellent (1:20 for 99 rows)
• CU Impact: Negligible (on-demand only)
• Sync Requirement: Must refresh with Branch_Name

🔑 CRITICAL SUCCESS FACTOR:
**LocationID integrity is essential for ALL reports**
• Verify no nulls in LocationID after refresh
• Verify row count matches Branch_Name (99 = 99)
• Verify dim_BranchLocation build succeeds after refresh
• Test sample report relationships after dim refresh

============================================================================
*/
