# Fact_LaborJobSummary - Data Dictionary

**Last Updated:** 2025-10-30  
**Table Name:** `Fact_LaborJobSummary`  
**Grain:** One row per job code per work order  
**Total Fields:** 31  
**Source Query:** `queries/fact-tables/Fact_LaborJobSummary.pq`

---

## 📋 Table of Contents

1. [Core Identifiers](#core-identifiers)
2. [Financial Fields - Labor](#financial-fields---labor)
3. [Financial Fields - Parts](#financial-fields---parts)
4. [Hours Fields](#hours-fields)
5. [Operational Context](#operational-context)
6. [Business Classification](#business-classification)
7. [Integration Fields](#integration-fields)
8. [Work Order Context](#work-order-context)
9. [Calculated Fields](#calculated-fields)
10. [Data Governance](#data-governance)

---

## Core Identifiers

### BranchCode
- **Data Type:** Text
- **Nullable:** No
- **Description:** Work order branch/location identifier
- **Source:** Raw_wkothsub.Branch
- **Business Purpose:** Primary location dimension for reporting
- **Sample Values:** "11", "13", "14", "91", "93", "95"
- **Usage:** Filter reports by location, aggregate by branch
- **Cardinality:** ~20 distinct branches

---

### WorkOrderNumber
- **Data Type:** Text
- **Nullable:** No
- **Description:** Unique work order number
- **Source:** Raw_wkothsub.WorkOrder
- **Business Purpose:** Primary work order identifier
- **Sample Values:** "669579", "662660", "658568"
- **Usage:** Drill-through to work order detail, link to other fact tables
- **Format:** 6-digit numeric string
- **Cardinality:** ~50,000-100,000 distinct work orders

---

### JobCode
- **Data Type:** Text
- **Nullable:** No
- **Description:** Service job code classification
- **Source:** Raw_wkothsub.JobCode
- **Business Purpose:** Identifies the type of work performed (inspection, repair, service)
- **Sample Values:** "IS-TRACTOR INSPECT", "IS-COMBINE INSPECT", "IS-D160"
- **Usage:** Primary filter for inspection identification, job type analysis
- **Inspection Codes:** See [inspection-job-codes.md](inspection-job-codes.md) for complete list
- **Cardinality:** ~500+ distinct job codes (111 are inspections)

---

### JobType
- **Data Type:** Text
- **Nullable:** No
- **Description:** Job type indicator
- **Source:** Raw_wkothsub.JobType
- **Business Purpose:** Categorizes work by business type (customer pay, warranty, internal)
- **Sample Values:** "r" (Retail), "w" (Warranty), "i" (Internal), "f" (Fleet)
- **Usage:** Filter by payment type, warranty vs customer pay analysis
- **Common Values:**
  - "r" = Retail (customer pay)
  - "w" = Warranty (manufacturer pays)
  - "i" = Internal (company equipment)
  - "f" = Fleet (fleet customer)
  - "p" = Policy (insurance work)

---

## Financial Fields - Labor

### EstimatedLaborAmount
- **Data Type:** Number (Currency)
- **Nullable:** No (can be 0)
- **Description:** Estimated labor value for the job
- **Source:** Raw_wkothsub.EstLabor (EST_LAB_VAL)
- **Business Purpose:** Quote amount given to customer, baseline for variance analysis
- **Sample Values:** $427.00, $385.25, $251.63
- **Usage:** Compare to Actual and Invoiced for profitability analysis
- **Typical Range:** $0 - $5,000 (most inspections $200-$800)
- **Calculation:** Based on estimated hours × labor rate

---

### ActualLaborAmount
- **Data Type:** Number (Currency)
- **Nullable:** No (can be 0)
- **Description:** Actual labor cost for the job
- **Source:** Raw_wkothsub.ActLabor (Act_Lab_Val)
- **Business Purpose:** True cost of labor (technician cost), used for margin analysis
- **Sample Values:** $320.00, $285.50, $190.25
- **Usage:** Calculate labor margin, cost analysis
- **Typical Range:** $0 - $4,000 (typically less than estimated)
- **Note:** Based on actual hours worked × technician cost rate

---

### InvoicedLaborAmount
- **Data Type:** Number (Currency)
- **Nullable:** No (can be 0)
- **Description:** Invoiced labor amount (what customer is billed)
- **Source:** Raw_wkothsub.InvLabor (Inv_Lab_Val)
- **Business Purpose:** Revenue recognition, what customer actually pays
- **Sample Values:** $427.00, $385.25, $0.00
- **Usage:** Revenue reporting, primary metric for inspection dollars
- **Typical Range:** $0 - $5,000 (often matches estimated, can be adjusted)
- **Note:** May differ from estimated due to warranty claims, goodwill adjustments, or change orders

---

## Financial Fields - Parts

### EstimatedPartsAmount
- **Data Type:** Number (Currency)
- **Nullable:** No (can be 0)
- **Description:** Estimated parts value for the job
- **Source:** Raw_wkothsub.EstParts (EST_PART_VAL)
- **Business Purpose:** Quote amount for parts, planning purposes
- **Sample Values:** $150.00, $0.00, $89.50
- **Usage:** Compare to actual for parts variance analysis
- **Typical Range:** $0 - $10,000 (inspections often $0-$500)
- **Note:** Many inspections have $0 parts (inspection labor only)

---

### ActualPartsAmount
- **Data Type:** Number (Currency)
- **Nullable:** No (can be 0)
- **Description:** Actual parts cost for the job
- **Source:** Raw_wkothsub.ActParts (Act_Part_Val)
- **Business Purpose:** True cost of parts used, used for margin analysis
- **Sample Values:** $120.00, $0.00, $75.25
- **Usage:** Calculate parts margin, inventory cost analysis
- **Typical Range:** $0 - $8,000 (typically less than estimated)

---

### InvoicedPartsAmount
- **Data Type:** Number (Currency)
- **Nullable:** No (can be 0)
- **Description:** Invoiced parts amount (what customer is billed)
- **Source:** Raw_wkothsub.InvParts (Inv_Part_Val)
- **Business Purpose:** Parts revenue recognition
- **Sample Values:** $150.00, $0.00, $89.50
- **Usage:** Parts revenue reporting, total job revenue calculation
- **Typical Range:** $0 - $10,000
- **Note:** Often $0 for inspection-only jobs (no parts replaced)

---

## Hours Fields

### EstimatedHours
- **Data Type:** Number (Decimal)
- **Nullable:** No (can be 0)
- **Description:** Estimated labor hours for the job
- **Source:** Raw_wkothsub.EstHours (est_hours)
- **Business Purpose:** Job planning, quote basis, efficiency baseline
- **Sample Values:** 2.5, 4.0, 1.5
- **Usage:** Compare to ActualHoursWorked for efficiency analysis
- **Typical Range:** 0.5 - 20 hours (most inspections 1-4 hours)
- **Format:** Decimal hours (e.g., 2.5 = 2 hours 30 minutes)

---

### ActualHoursWorked
- **Data Type:** Number (Decimal)
- **Nullable:** Yes
- **Description:** SUM of all technician hours worked on this job (aggregated from punch records)
- **Source:** Raw_wkmechwk.HoursWorked (HOURS_WORK) - AGGREGATED
- **Business Purpose:** Actual time spent, efficiency tracking, labor productivity
- **Sample Values:** 2.7, 4.5, NULL (if no labor punches)
- **Usage:** Primary metric for "Hours Worked", efficiency variance calculation
- **Typical Range:** 0.5 - 25 hours
- **NULL Handling:** NULL indicates no labor punches (parts-only job or not yet worked)
- **Aggregation:** SUM across all technicians and punch records for this job
- **Important:** Multiple techs working same job = sum of all their hours

---

### InvoicedHours
- **Data Type:** Number (Decimal)
- **Nullable:** Yes
- **Description:** SUM of all invoiced hours for this job (aggregated from punch records)
- **Source:** Raw_wkmechwk.InvoiceHours (INVOICE_HRS) - AGGREGATED
- **Business Purpose:** Billable hours tracking, may differ from actual hours worked
- **Sample Values:** 2.5, 4.0, NULL
- **Usage:** Billing analysis, compare to EstimatedHours for quote accuracy
- **Typical Range:** 0.5 - 20 hours
- **NULL Handling:** NULL indicates no labor punches
- **Note:** May be less than ActualHoursWorked (rework not billed, warranty adjustments)

---

## Operational Context

### IsMachineDown
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Machine downtime indicator
- **Source:** Raw_wkothsub.IsMachineDown (Machine_Down_Ind)
- **Business Purpose:** Identifies critical equipment down situations (priority work)
- **Sample Values:** "Y", "N", NULL
- **Usage:** Filter urgent repairs, downtime analysis
- **Common Values:**
  - "Y" = Machine is down (priority)
  - "N" = Machine operational (routine work)
  - NULL = Not specified

---

### WorkCategory
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Work categorization
- **Source:** Raw_wkothsub.WorkCategory (Work_Cat)
- **Business Purpose:** Additional work classification for operational reporting
- **Sample Values:** "MAINT", "REPAIR", "INSP", NULL
- **Usage:** Work type analysis, operational metrics
- **Note:** Not consistently populated across all branches

---

### JobStatus
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Current job status
- **Source:** Raw_wkothsub.JobStatus (STATUS)
- **Business Purpose:** Job-level status tracking (different from work order status)
- **Sample Values:** "COMPLETE", "ACTIVE", "PENDING", NULL
- **Usage:** Job completion tracking, status reporting
- **Note:** See WorkOrderStatus for work order-level status

---

## Business Classification

### IsNonRevenue
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Non-revenue job flag
- **Source:** Raw_wkothsub.IsNonRevenue (non_revenue)
- **Business Purpose:** Identifies internal work that doesn't generate customer revenue
- **Sample Values:** "Y", "N", NULL
- **Usage:** Filter revenue-generating work, exclude internal jobs from revenue metrics
- **Common Values:**
  - "Y" = Non-revenue (internal, goodwill, warranty absorbed)
  - "N" = Revenue-generating
  - NULL = Not specified (assume revenue)

---

### IsFieldRepair
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Field service indicator
- **Source:** Raw_wkothsub.IsFieldRepair (Field_Repair)
- **Business Purpose:** Identifies work performed at customer location vs shop
- **Sample Values:** "Y", "N", NULL
- **Usage:** Field service vs shop analysis, travel cost tracking
- **Common Values:**
  - "Y" = Field service (at customer site)
  - "N" = Shop service (at dealership)
  - NULL = Not specified

---

### IsStandardLabor
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Standard labor rate indicator
- **Source:** Raw_wkothsub.IsStandardLabor (Std_Lab_Ind)
- **Business Purpose:** Identifies if standard labor rate was used
- **Sample Values:** "Y", "N", NULL
- **Usage:** Pricing analysis, rate variance analysis
- **Common Values:**
  - "Y" = Standard labor rate applied
  - "N" = Custom/negotiated rate
  - NULL = Not specified

---

## Integration Fields

### InvoiceNumber
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Invoice number for billing integration
- **Source:** Raw_wkothsub.InvoiceNumber (INVOICE_NO)
- **Business Purpose:** Links to invoice records, accounts receivable integration
- **Sample Values:** "1780279", "1721397", NULL
- **Usage:** Cross-reference to InTrans for parts detail, AR reconciliation
- **Format:** 7-digit numeric string
- **NULL Handling:** NULL if job not yet invoiced

---

### InvoiceDate
- **Data Type:** Date
- **Nullable:** Yes
- **Description:** Invoice date for billing cycle analysis
- **Source:** Raw_wkothsub.InvoiceDate (INVOICE_DATE)
- **Business Purpose:** Revenue timing, aging analysis, billing cycle tracking
- **Sample Values:** 2025-06-26, 2025-03-28, NULL
- **Usage:** Time intelligence calculations, monthly revenue reporting
- **NULL Handling:** NULL if job not yet invoiced

---

### ClaimNumber
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Warranty/claim number for warranty analysis
- **Source:** Raw_wkothsub.ClaimNumber (CLAIM_NO)
- **Business Purpose:** Links to warranty claims, warranty vs customer pay analysis
- **Sample Values:** "W2025-12345", NULL
- **Usage:** Warranty tracking, manufacturer reimbursement reconciliation
- **NULL Handling:** NULL if not a warranty job (most customer pay jobs)
- **Note:** Populated for warranty work only

---

## Work Order Context

### WorkOrderStatus
- **Data Type:** Text
- **Nullable:** Yes
- **Description:** Work order progress status
- **Source:** Raw_wkrofile.ProgressStatus (RO_PROGRESS_STATUS)
- **Business Purpose:** Current status of the entire work order (not just this job)
- **Sample Values:** "wip", "bi", "va", "wf", "iv", "ca", "vp"
- **Usage:** Pending inspection tracking, workflow status filtering
- **Common Values:**
  - "bi" = Booked-In (work order created)
  - "va" = Vehicle/Equipment Arrived
  - "wip" = Work In Progress
  - "wf" = Work Finished
  - "iv" = Invoiced
  - "ca" = Customer Advised (ready for pickup)
  - "vp" = Vehicle/Equipment Picked-up
- **IsPending Logic:** "wip", "bi", "va" are considered pending

---

### WorkOrderCreationDate
- **Data Type:** DateTime
- **Nullable:** Yes
- **Description:** Work order creation date
- **Source:** Raw_wkrofile.CreatedOn (Creation_Date)
- **Business Purpose:** Work order aging analysis, timeline tracking
- **Sample Values:** 2025-06-26 08:15:30, 2025-01-14 14:22:00
- **Usage:** Pending inspection aging, time-to-completion analysis
- **Format:** Date with time component
- **Note:** Use for aging calculations (days since creation)

---

### WorkOrderClosedDate
- **Data Type:** DateTime
- **Nullable:** Yes
- **Description:** Work order closure date
- **Source:** Raw_wkrofile.ClosedDate (Closed_Date)
- **Business Purpose:** Completion tracking, cycle time analysis
- **Sample Values:** 2025-06-28 16:45:00, NULL (if not closed)
- **Usage:** Calculate days to complete, historical analysis
- **NULL Handling:** NULL if work order still open

---

## Calculated Fields

### IsInspection
- **Data Type:** Boolean
- **Nullable:** No
- **Description:** Boolean flag identifying inspection jobs
- **Source:** CALCULATED - JobCode matched to embedded inspection code lookup table
- **Business Purpose:** Primary filter for all inspection reporting
- **Values:** TRUE, FALSE
- **Usage:** Filter all inspection metrics, count inspections
- **Calculation Logic:**
```
  IF JobCode IN (111 inspection codes)
  THEN TRUE
  ELSE FALSE
```
- **Inspection Codes:** See [inspection-job-codes.md](inspection-job-codes.md)
- **Expected Distribution:** ~5-15% of all jobs are inspections

---

### TotalInvoicedAmount
- **Data Type:** Number (Currency)
- **Nullable:** No
- **Description:** Total invoiced amount (Labor + Parts)
- **Source:** CALCULATED
- **Business Purpose:** Total job revenue, simplified reporting metric
- **Sample Values:** $577.00, $385.25, $516.50
- **Usage:** Total job revenue analysis, single revenue metric
- **Calculation:** `InvoicedLaborAmount + InvoicedPartsAmount`
- **Note:** Pre-calculated for report performance (avoid repeated DAX calculation)

---

### TotalEstimatedAmount
- **Data Type:** Number (Currency)
- **Nullable:** No
- **Description:** Total estimated amount (Labor + Parts)
- **Source:** CALCULATED
- **Business Purpose:** Total job quote amount, estimate accuracy analysis
- **Sample Values:** $600.00, $400.00, $500.00
- **Usage:** Compare to TotalInvoicedAmount for quote accuracy
- **Calculation:** `EstimatedLaborAmount + EstimatedPartsAmount`
- **Variance Calculation:** `TotalInvoicedAmount - TotalEstimatedAmount`

---

### HoursVariance
- **Data Type:** Number (Decimal)
- **Nullable:** Yes
- **Description:** Difference between Actual and Estimated hours
- **Source:** CALCULATED
- **Business Purpose:** Labor efficiency analysis, estimate accuracy tracking
- **Sample Values:** 0.2, -0.5, NULL
- **Usage:** Efficiency reporting, identify over/under estimated jobs
- **Calculation:** `ActualHoursWorked - EstimatedHours`
- **Interpretation:**
  - Positive = Took longer than estimated (less efficient)
  - Negative = Took less time than estimated (more efficient or underestimated)
  - NULL = No labor punches recorded
- **NULL Handling:** NULL if ActualHoursWorked is NULL

---

### IsPending
- **Data Type:** Boolean
- **Nullable:** No
- **Description:** Boolean flag for pending work orders
- **Source:** CALCULATED - based on WorkOrderStatus
- **Business Purpose:** Identify work orders still in progress
- **Values:** TRUE, FALSE
- **Usage:** Pending Inspections page filter, aging analysis
- **Calculation Logic:**
```
  IF WorkOrderStatus IN ("wip", "bi", "va")
  THEN TRUE
  ELSE FALSE
```
- **Status Definitions:**
  - "wip" = Work In Progress (actively being worked)
  - "bi" = Booked-In (scheduled, not started)
  - "va" = Vehicle/Equipment Arrived (waiting to start)
- **Note:** May need adjustment if status codes change

---

## Data Governance

### ModifiedDate
- **Data Type:** DateTime
- **Nullable:** No
- **Description:** Last modification date of the job record
- **Source:** Raw_wkothsub.ModifiedDate
- **Business Purpose:** Audit trail, incremental refresh control
- **Sample Values:** 2025-06-26 14:30:15, 2025-10-29 08:15:00
- **Usage:** Incremental refresh filter, change tracking, audit reports
- **Format:** Date with time component
- **Incremental Refresh:** Records with ModifiedDate >= 2023-01-01 are loaded
- **Note:** Updated whenever any field in the source record changes

---

## 📊 Field Summary Statistics

### Field Categories

| Category | Field Count | Purpose |
|----------|-------------|---------|
| Core Identifiers | 4 | Work order and job identification |
| Financial - Labor | 3 | Labor revenue and cost tracking |
| Financial - Parts | 3 | Parts revenue and cost tracking |
| Hours | 3 | Time tracking and efficiency |
| Operational | 3 | Work categorization and status |
| Business Classification | 3 | Revenue and service type flags |
| Integration | 3 | Cross-system links and references |
| Work Order Context | 3 | Work order status and timeline |
| Calculated | 5 | Pre-computed metrics and flags |
| Data Governance | 1 | Audit and refresh control |
| **Total** | **31** | **Complete fact table** |

---

### Nullable Field Summary

**Non-Nullable Fields (19):**
- All Core Identifiers (4)
- All Financial Fields (6)
- EstimatedHours (1)
- All Calculated Fields (5)
- ModifiedDate (1)
- Plus 2 operational fields typically populated

**Nullable Fields (12):**
- ActualHoursWorked (NULL if no labor)
- InvoicedHours (NULL if no labor)
- Most Operational/Classification flags
- Work Order Context dates (if not closed)
- Integration fields (if not invoiced)

---

### Data Type Distribution

| Data Type | Count | Fields |
|-----------|-------|--------|
| Text | 15 | Identifiers, status codes, flags |
| Number (Currency) | 9 | All financial amounts and totals |
| Number (Decimal) | 4 | Hours fields and variance |
| DateTime | 3 | Date tracking fields |
| Boolean | 2 | IsInspection, IsPending |

---

## 🎯 Key Relationships

### Primary Key
**Composite Key:** `BranchCode + WorkOrderNumber + JobCode`
- Uniquely identifies each row
- Grain: One row per job per work order

### Foreign Keys

**To Dimension Tables (Future):**
- `BranchCode` → dim_Branch (Location dimension)
- `WorkOrderNumber` → dim_WorkOrder (if created)
- `JobCode` → dim_JobCode (if created)
- `InvoiceDate` → dim_Date (Date dimension)

**To Other Fact Tables:**
- `BranchCode + WorkOrderNumber + JobCode` → Fact_LaborPunches (drill to detail)
- `InvoiceNumber` → Fact_WorkOrderParts (parts detail)

---

## 💡 Usage Examples

### Example 1: Calculate Total Inspection Revenue
```dax
Total Inspection Revenue = 
CALCULATE(
    SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

---

### Example 2: Count Pending Inspections
```dax
Pending Inspections = 
CALCULATE(
    DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber]),
    Fact_LaborJobSummary[IsInspection] = TRUE,
    Fact_LaborJobSummary[IsPending] = TRUE
)
```

---

### Example 3: Calculate Labor Efficiency %
```dax
Labor Efficiency % = 
DIVIDE(
    SUM(Fact_LaborJobSummary[EstimatedHours]),
    SUM(Fact_LaborJobSummary[ActualHoursWorked]),
    BLANK()
) * 100
```

---

### Example 4: Average Hours per Inspection
```dax
Avg Hours per Inspection = 
CALCULATE(
    AVERAGE(Fact_LaborJobSummary[ActualHoursWorked]),
    Fact_LaborJobSummary[IsInspection] = TRUE,
    NOT(ISBLANK(Fact_LaborJobSummary[ActualHoursWorked]))
)
```

---

## ⚠️ Important Notes

### NULL Handling

**ActualHoursWorked and InvoicedHours:**
- Expected to be NULL for parts-only jobs
- NULL does not indicate data quality issue
- Use COALESCE(ActualHoursWorked, 0) in calculations where appropriate
- Typical NULL rate: 20-30% (parts-only or not yet worked)

**Work Order Dates:**
- WorkOrderClosedDate NULL if work order still open
- Do not treat as data quality issue
- Use for pending vs completed filtering

---

### Data Quality Validations

**Critical Validations:**
1. BranchCode, WorkOrderNumber, JobCode should never be NULL
2. IsInspection should be TRUE for all known inspection job codes
3. WorkOrderStatus should populate for 100% of rows
4. TotalInvoicedAmount should equal sum of labor + parts

**Warning Conditions:**
- ActualHoursWorked > 24 hours (likely multi-day job or data error)
- InvoicedLaborAmount > $10,000 (unusual for inspection)
- HoursVariance > 10 hours (significant estimation error)

---

## 📞 Questions or Issues?

**Data Dictionary Owner:** [Your Name]  
**Last Reviewed:** 2025-10-30  
**Next Review:** 2026-01-30 (Quarterly)

For field definition questions or data quality issues, see:
- [Validation Queries](../validation/fact-validation-queries.md)
- [Architecture Documentation](../ARCHITECTURE.md)
- Project README for contact information

---

**End of Data Dictionary**