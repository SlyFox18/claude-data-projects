# Price Matrix Project - Current State

## Project Overview
This report tracks the Sales, Margin and Margin % of parts within the Price Matrix. The Price Matrix is divided into "Ranges" or buckets and lists a suggested markup for that part. Example: Range $0.01 - $0.99 has a markup of 75%, Range $1.00 - $1.99 has a markup of 40% and so on. This report will examine these buckets for Sales, Margin and Margin %.
Additional Context: I am a data analyst and power pi developer. My primary source of data is on a SQL Aywhere database, and I use an ODBC connection through a On-Premises Gateway. This data is then loaded into a Lakehouse in Fabric. I am in the process of restructuring my data into clearly defined folders and naming scheme. I have a Workspace for my master data, and folders setup for Raw Sources, Transformations, Dimensions, and Fact Tables. The raw source is loaded into my Lakehouse and then used to build my dim's and Fact tables.   

## Current Status
- **Started:** 7/7/25
- **Current Phase:** Migrating to Git workflow / adding some additional metrics
- **Report Status:** Functional/In Development - need to add new metrics added to the data on 7/11

## Data Model Summary
- **Tables:** 6 data tables - (2 Fact tables - (Fact_Inventory) (Fact_Part_Transactions), 3 dimension tables - (dim_BranchLocation) (dim_Franchise) (dim_Parts) (Fabric Lakehouse)), 1 .csv - (Price_Martix) (OnDrive)
- **Measures:** 31
- **Key Relationships:** Fact tables are connected to the dimension tables

## Current Functionality
### What Works Well:
- [Feature 1] - Range buckets defined and working
- [Feature 2] - Capturing sales from Fact_Part_Transactions and assigning them to the buckets

### Known Issues:
- Dax measure naming - needs to be clearer, often confusing to find the right measure. Find a good way to note which fact table is producing the results. 
- Create new measures to show the new data that was added on 7/11 - EffectiveListSalVal, EfectiveListMargin, EffectiveListMargin%, MatrixSalesGained, MartixMarginGained

### Planned Improvements:
- Add a pricing calculator - be able to show expected changes to sales if the markup was changed.
- Better visualiations and clarity

## Data Sources
- **Source 1:** jdis_Part_Information, manual refresh currently (This is the raw source that Fact_Inventory is built from)
- **Source 2:** InTrans, manual refresh currently (This is the raw source that Fact_Part_Transactions is built from)
- **Source 3:** Fact_Inventory, manual refresh currently
- **Source 4:** Fact_Part_Transactions, manual refresh currently
- **Source 5:** PRICE MATRIX 7-9-25.csv (re-named: Price_Matrix), stored in OneDrive, manual refresh

## Key Business Logic
### Price Calculations:
[Explain your pricing logic]

### Matrix Structure:
The Price Matrix is divided into "Ranges" or buckets and lists a suggested markup for that part. Example: Range $0.01 - $0.99 has a markup of 75%, Range $1.00 - $1.99 has a markup of 40% and so on. This report will examine these buckets for Sales, Margin and Margin %.

## Context for Claude Conversations
**Current Question/Focus:** Figure out the best way to handle writting the measure for these metrics: EffectiveListSalVal, EfectiveListMargin, EffectiveListMargin%, MatrixSalesGained, MartixMarginGained

**Available Files for Analysis:**
- `/data/info-exports/` - Complete model metadata
- `/powerbi/current/` - Current working report
- `/sql/dax-measures/` - Individual DAX measures

**Key Metrics to Understand:**
- [Metric 1]: [Brief explanation]
- [Metric 2]: [Brief explanation]