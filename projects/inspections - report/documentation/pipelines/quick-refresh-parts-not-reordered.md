# Quick Refresh: Parts Not Re-Ordered 24 Hours

## Purpose
Provides time-sensitive updates to parts ordering insights
twice daily after morning and afternoon parts orders are placed.

## Schedule
- 9:30 AM (Monday-Friday)
- 4:00 PM (Monday-Friday)

## Duration
~11 minutes

## Architecture
[Include pipeline diagram]

## Tables Refreshed
1. InTrans_Incremental (via Pipeline_InTrans)
2. jdis_Part_Information
3. Fact_PartSales_24Hours

## Semantic Model
- Name: Parts Not Re-Ordered 24 Hours
- Workspace: RP - Parts Reports
- Dataset ID: a66dfb45-ff50-4844-8b14-a8b554de53c4

## Success Criteria
- Duration < 15 minutes
- Report refresh time within 2 minutes of pipeline completion
- Data current through pipeline start time

## Troubleshooting
[Common issues and solutions]