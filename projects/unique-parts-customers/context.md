# Unique Parts Customers - Current State

## Project Overview
This report tracks the Sales, Margin and Margin % of unique customers. It will compare current year sales to previous year sales. These unique customers are identified by "Trade Type". Trade Type = "D" then "Pearsall", Trade Type = "T" then "Dell City/Tornillo". Other unique customers are identified by "cust_ord_no AS CustomerOrderNumber" from the Invoice table. These customers are: "Jim", "Manuel" and "MR Tractor", how this is defined will be explained in detail below. This project is a upadte from an already completed Power Bi report. The data structure on the backend has been updated to help with refresh times and overall functionality and scaleabilty. All data is being pulled from a SQL Anywhere database, via an ODBC connection utilizing an On-Premisis Gateway, and being loaded into a Lakehouse in Fabric (Power Bi Service). Fact and dimension tables are being created from the raw source loaded into this Lakehouse. The existing completed report only contains information from 2 of these unique customers (Pearsall & Dell City/Tornillo). The Update to this project will add (Jim, Manuel & MR Tractor). The challenge here is this information is comming from 2 different data tables. The information for Dell City/ Tornillo & Pearsall comes from the InTrans table, Jim, Manuel & MR Tractor will be found in the Invoice table. Different fact tables have been built for this: Fact_Part_Transaction (InTrans table), and Fact_UniqueCustomer_Part (Invoice). Git intergration, documentation, automation is wanted for this project.       

## Current Status
- **Started:** Original report completed 3/5/25 and updated to add "Manuel" 6/20/25, Updated report started on 7/11/25
- **Current Phase:** Migrating to Git workflow / building a new report, replicating the original and adding new unique customers using newly structured data
- **Report Status:** Functional/In Development - starting new report

## Data Model Summary
- **Original Report**
- **Tables:** 3 data tables: Location: (Lakehouse - LH - Parts_Data_Prep, Dataflow: DF_Unique_Parts_Cusomers) - ArMaster_Customer_Unique , InTrans_Unique, Invoice. 1 dimension table: Dim_Branch. 1 calculated date table.
- **Measures:** 94
- **Key Relationships:** InTrans connected to ArMaster_Customer_Unique on "Customer No". Intrans_Unique connected to Invoice on REF_NO (Intrans_Unique), document_no (Invoice)

- **New Report**
- **Tables:** 2 Fact tables: Fact_Part_Transactions & Fact_UniqueCustomer_Parts. 6 Dimension tables: dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Franchise, dim_InvoiceLookup, dim_Parts
- **Measures:** No new measure have been created yet, but want to document all of this as the report is being built
- **Key Relationships:** Fact tables connected to dim's using unique keys. 

## Current Functionality of original report
### What Works Well:
- [Feature 1] - Clearly shows comparision of YTD vs. PYTD 

### Known Issues of original report and transition to new report:
- Dax measure naming - needs to be clearer, often confusing to find the right measure. Find a good way to note which fact table is producing the results. Documentation 
- Add new unique customers.
- Establish consistant refresh schedule controlling CU usage. Incremental refresh if possiable

### Planned Improvements:
- Add a way to easily export data for leadership when requested.
- Better visualiations and clarity

## Data Sources - New Report
- **Source 1:** InTrans (raw source), manual refresh currently (This is the raw source that Fact_Part_Transactions is built from). Location: LH_Master_Data>Dataflows>01 - Raw Sources: df_INTRANS_Raw
- **Source 2:** Ar_Master_Customer (raw source), manual refresh currently (Used in creating The Fact_UniqueCustomer_Parts table and the dim_CustomerList connected on CustomerKey) Location: LH_Master_Data>Dataflows>01 - Raw Sources: df_ArMaster_Customer_Raw
- **Source 3:** Invoice (raw source), manual refresh currently (Used in creating The Fact_UniqueCustomer_Parts table and the dim_InvoiceLookup connected on InvoiceKey)
- **Source 4:** Fact_Part_Transactions, manual refresh currently
- **Source 5:** Fact_UniqueCustomer_Parts

## Key Business Logic
### Price Calculations:
[Explain your pricing logic]


## Context for Claude Conversations
**Current Question/Focus:** Analize current report structure/ measures and put together a clear plan to create a new report. Define new measures with a clear naming convention using the new data structure replicating the original report. Implement Git documentation and versioning strategies, with automation when possible.  

**Available Files for Analysis:**
- `/data/info-exports/` - Complete model metadata
- `/powerbi/current/` - Current working report


**Tools being Used:**
- Power Bi Desktop
- Fabric (Power Bi Service)
- VS Code
- GitHub Desktop and Web version
