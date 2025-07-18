# Price Matrix Project - Enhanced Data Model Documentation

**Generated:** 2025-07-18 15:29
**Project:** Price Matrix Analysis System

## Executive Summary

This Power BI data model supports comprehensive price matrix analysis with 21 tables, 
218 columns, 12 relationships, and 83 DAX measures.

The model follows star schema design principles with clear separation between fact tables 
(transaction data) and dimension tables (master data).

## Model Statistics

| Component | Count | Details |
|-----------|-------|---------|
| **Tables** | 21 | 2 fact, 8 dimension, 2 configuration |
| **Columns** | 218 | All attributes and calculated columns |
| **Relationships** | 12 | Star schema connections |
| **Measures** | 83 | DAX calculations and KPIs |

---

## Data Model Architecture

### Star Schema Design

The model implements a star schema with centralized fact tables surrounded by dimension tables:

#### Fact Tables (2 tables)
Core business data containing transactions and events:

**Fact_Inventory**
- Purpose: Core inventory and sales data with 12-month rolling metrics
- Total Columns: 23
- Key Columns: 8 (for relationships)
- Measure Columns: 9 (numeric data)
- Date Columns: 2 (time dimensions)

**Fact_Part_Transactions**
- Purpose: Individual sales transactions with customer and margin details
- Total Columns: 32
- Key Columns: 4 (for relationships)
- Measure Columns: 17 (numeric data)
- Date Columns:  (time dimensions)


#### Dimension Tables (8 tables)
Master data providing context and attributes for analysis:

**dim_BranchLocation**
- Purpose: Branch and location master data for geographic analysis
- Total Columns: 9
- Primary Keys: 
- Business Attributes: 7

**dim_Parts**
- Purpose: Part master data with descriptions and franchise assignments
- Total Columns: 5
- Primary Keys: 
- Business Attributes: 3

**dim_Franchise**
- Purpose: Franchise master data for organizational reporting
- Total Columns: 3
- Primary Keys: 
- Business Attributes: 

**dim_DealerGroupCode**
- Purpose: Supporting table for specialized analysis or system functions
- Total Columns: 3
- Primary Keys: 
- Business Attributes: 

**dim_Source**
- Purpose: Supporting table for specialized analysis or system functions
- Total Columns: 3
- Primary Keys: 
- Business Attributes: 

**dim_SLC**
- Purpose: Supporting table for specialized analysis or system functions
- Total Columns: 3
- Primary Keys: 
- Business Attributes: 

**dim_VendorCode**
- Purpose: Supporting table for specialized analysis or system functions
- Total Columns: 3
- Primary Keys: 
- Business Attributes: 

**dim_DateTable**
- Purpose: Supporting table for specialized analysis or system functions
- Total Columns: 21
- Primary Keys: 
- Business Attributes: 19


#### Configuration Tables (2 tables)
System configuration and calculated tables:

**MeasuresTable**
- Purpose: Container table for DAX measures (Power BI calculated table)
- Columns: 3

**Price_Matrix**
- Purpose: Price range configuration with target margin percentages
- Columns: 24


### Data Model Relationships

The following relationships connect the tables in a star schema:

- **Price_Matrix** [Many] â†’ **Range Selection** [One]
  - Join: Range = Range
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Inventory** [Many] â†’ **dim_BranchLocation** [One]
  - Join: BranchKey = BranchKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Inventory** [Many] â†’ **dim_Parts** [One]
  - Join: PartNumberKey = PartNumberKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Inventory** [Many] â†’ **dim_Franchise** [One]
  - Join: FranchiseKey = FranchiseKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Inventory** [Many] â†’ **dim_VendorCode** [One]
  - Join: VendorCodeKey = VendorCodeKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Inventory** [Many] â†’ **dim_Source** [One]
  - Join: SourceKey = SourceKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Inventory** [Many] â†’ **dim_SLC** [One]
  - Join: SLCKey = SLCKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Inventory** [Many] â†’ **dim_DealerGroupCode** [One]
  - Join: DealerGroupKey = DealerGroupKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Part_Transactions** [Many] â†’ **dim_Parts** [One]
  - Join: PartNumberKey = PartNumberKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Part_Transactions** [Many] â†’ **dim_Franchise** [One]
  - Join: FranchiseKey = FranchiseKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Part_Transactions** [Many] â†’ **dim_BranchLocation** [One]
  - Join: BranchKey = BranchKey
  - Filter Direction: OneDirection
  - Active: True

- **Fact_Part_Transactions** [Many] â†’ **dim_DateTable** [One]
  - Join: TransactionDate = Date
  - Filter Direction: OneDirection
  - Active: True


---

## Key Column Analysis

### Critical Business Columns

**Relationship Keys (33 columns)**
Essential for connecting tables in the star schema.

**Price/Financial Columns (17 columns)**
Core metrics for pricing analysis and financial calculations.

**Quantity/Volume Columns (3 columns)**
Sales volumes and transaction counts for business analysis.

**Date/Time Columns (6 columns)**
Time dimensions for trend analysis and filtering.


## Data Sources and Lineage

### Source Systems

**Primary Sources:**
- SQL Anywhere Database (via ODBC â†’ On-Premises Gateway â†’ Fabric Lakehouse)
  - jdis_Part_Information â†’ Fact_Inventory
  - InTrans â†’ Fact_Part_Transactions
- OneDrive CSV Files
  - PRICE MATRIX 7-9-25.csv â†’ Price_Matrix

**Data Flow:**
1. Raw data extracted from source systems
2. Loaded into Fabric Lakehouse for processing
3. Transformations applied to create clean dimension tables
4. Fact tables built with business logic and calculations
5. Relationships established to create star schema
6. DAX measures added for business calculations


## Usage Guidelines

### Performance Best Practices

**Optimal Filtering:**
- Start with Price_Matrix price ranges (value_from, value_to)
- Filter dates using Fact_Part_Transactions[TransactionDate]
- Use dimension tables for categorical filtering
- Filter for active sales: Current12MoSales > 0

**Common Analysis Patterns:**
- **Price Range Analysis:** Use Price_Matrix for segmentation
- **Time-Series Analysis:** Filter by TransactionDate ranges
- **Geographic Analysis:** Filter through dim_BranchLocation
- **Product Analysis:** Use dim_Parts for part-level insights


## Model Maintenance

### Current Refresh Strategy
- **Refresh Method:** Manual (currently)
- **Fact Tables:** Refresh together to maintain consistency
- **Dimension Tables:** Refresh before fact tables
- **Price Matrix:** Update from OneDrive as needed

### Data Quality Monitoring
- Verify relationship integrity after refreshes
- Check for unexpected null values in key columns
- Validate measure calculations with known test cases
- Monitor query performance for complex calculations

### Model Evolution
- Document all schema changes in Git
- Test measure impacts before deployment
- Maintain backward compatibility when possible
- Update documentation automatically with each change

---

*This documentation is automatically generated from Power BI model metadata.*
*For detailed measure documentation, see dax-measures-complete-guide.md*
*Last updated: 2025-07-18 15:29*
