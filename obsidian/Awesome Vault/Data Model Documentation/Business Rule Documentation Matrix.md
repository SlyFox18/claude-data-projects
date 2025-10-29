# 🏗️ EQUIPMENT SERVICE DIMENSIONAL MODEL

## Business Rule Documentation Matrix

> **Data Governance Framework: Raw Data → Dimensions → Facts → Business Intelligence**  
> _Complete traceability of business rules across the entire data architecture_

---

## 📋 MATRIX OVERVIEW

This matrix documents how business rules cascade through your dimensional model architecture, ensuring consistency when modifying any component. Each rule shows its origin in raw data, implementation in dimensions/facts, and ultimate business intelligence output.

---

## 🔗 BUSINESS RULE CASCADE ARCHITECTURE

### **1. CUSTOMER ASSIGNMENT LOGIC CASCADE**

|**Layer**|**Component**|**Business Rule**|**Implementation**|**Validation**|
|---|---|---|---|---|
|**Raw Data**|Raw_WorkOrderFile|Customer account numbers may be null/empty|AccountNumber field optional|Check for NULL/empty values|
|**Raw Data**|Raw_wkrodesc|Job types indicate work order category|PrimaryJobType: 'i', 'w', 'f', 'e', 'p', 'b', 's'|Validate against known type codes|
|**Dimension**|dim_CustomerList|Special customers handle fallback scenarios|CustomerKey -1 to -8 for system customers|Verify negative keys exist|
|**Dimension**|dim_CustomerList|Account numbers standardized as text|AccountNumberText = UPPER(TRIM(AccountNumber))|Check text formatting consistency|
|**Fact**|Fact_WorkOrderHeader|Intelligent customer assignment with fallback|CustomerLookupKey uses Account OR JobType mapping|Ensure no NULL customer assignments|
|**Fact**|Fact_WorkOrderHeader|Customer assignment hierarchy|Account → Internal → Warranty → Fleet → Excess → Policy → Billing → Misc → Unknown|Validate fallback sequence works|
|**Business Intelligence**|Dashboards|Every work order has customer context|Customer analysis never shows orphaned work orders|Monitor customer assignment success rate|

**Special Customer Mapping:**

- **-1**: UNKNOWN (catch-all fallback)
- **-2**: INTERNAL (job type 'i')
- **-3**: WARRANTY (job type 'w')
- **-4**: FLEET (job type 'f')
- **-5**: EXCESS (job type 'e')
- **-6**: POLICY (job type 'p')
- **-7**: BILLING (job type 'b')
- **-8**: MISC (job type 's')

---

### **2. VEHICLE/EQUIPMENT IDENTIFICATION CASCADE**

|**Layer**|**Component**|**Business Rule**|**Implementation**|**Validation**|
|---|---|---|---|---|
|**Raw Data**|Raw_VehicleFleet|Fleet vehicles identified by registration|Registration field primary identifier|Check for valid registration format|
|**Raw Data**|Raw_VehicleStock|Stock vehicles identified by stock number|StockNumber field primary identifier|Verify stock number uniqueness|
|**Raw Data**|Raw_WorkOrderFile|Work orders reference vehicles two ways|Registration OR StockNumber fields|Check at least one vehicle identifier exists|
|**Dimension**|dim_Vehicle|Dual-source integration with lookup keys|Fleet: Registration, Stock: "Stk# " + StockNumber|Validate lookup key formats|
|**Dimension**|dim_Vehicle|Vehicle age calculation for maintenance|Age categories: New, Recent, Mature, Aging, Old, Legacy|Check age calculation accuracy|
|**Fact**|Fact_WorkOrderHeader|Vehicle lookup priority logic|Registration first, then "Stk# " + StockNumber|Ensure consistent lookup sequence|
|**Business Intelligence**|Analytics|Equipment maintenance patterns|Age-based maintenance priority scoring|Monitor maintenance by age category|

**Vehicle Lookup Logic:**

```
VehicleLookupKey = 
  IF Registration exists THEN UPPER(TRIM(Registration))
  ELSE IF StockNumber exists THEN "Stk# " + TRIM(StockNumber)
  ELSE NULL
```

---

### **3. WORK ORDER STATUS WORKFLOW CASCADE**

|**Layer**|**Component**|**Business Rule**|**Implementation**|**Validation**|
|---|---|---|---|---|
|**Raw Data**|Raw_WorkOrderFile|Status codes track workflow progression|ProgressStatus field with standard codes|Verify status codes in approved list|
|**Dimension**|dim_WorkOrderStatus|7-stage workflow progression|bi → va → wip → wf → iv → ca → vp|Check workflow sequence logic|
|**Dimension**|dim_WorkOrderStatus|Business status indicators|IsActive, IsCompleted, IsBillable flags|Validate flag logic against status codes|
|**Fact**|Fact_WorkOrderHeader|Status-based business metrics|IsOverdue, PriorityScore calculations|Check priority calculation consistency|
|**Business Intelligence**|Dashboards|Workflow bottleneck identification|Status distribution and progression analysis|Monitor workflow efficiency metrics|

**Status Progression Rules:**

- **bi** (Booked-In): Stage 1, Active=True, Completed=False, Billable=False
- **va** (Vehicle Arrived): Stage 2, Active=True, Completed=False, Billable=False
- **wip** (Work In Progress): Stage 3, Active=True, Completed=False, Billable=False
- **wf** (Work Finished): Stage 4, Active=True, Completed=False, Billable=False
- **iv** (Invoiced): Stage 5, Active=True, Completed=True, Billable=True
- **ca** (Customer Advised): Stage 6, Active=True, Completed=True, Billable=True
- **vp** (Vehicle Picked-up): Stage 7, Active=False, Completed=True, Billable=True

---

### **4. TECHNICIAN PERFORMANCE METRICS CASCADE**

|**Layer**|**Component**|**Business Rule**|**Implementation**|**Validation**|
|---|---|---|---|---|
|**Raw Data**|Raw_TechnicianDetail|Labor hours tracked by technician/job|HoursWorked, HoursRework, InvoiceHours|Check for negative or excessive hours|
|**Raw Data**|Raw_Technician|Technician master with name components|FirstName, LastName for name construction|Validate name completeness|
|**Dimension**|dim_Technician|Multiple name format options|Full, Display, Short, Preferred name formats|Check name format consistency|
|**Fact**|Fact_WorkOrderLabor|Labor efficiency calculation|LaborEfficiency = InvoiceHours / HoursWorked|Validate efficiency calculation|
|**Fact**|Fact_WorkOrderLabor|Quality indicators|HasRework, ReworkPercentage calculations|Check rework logic accuracy|
|**Business Intelligence**|Performance Analytics|Productivity classification|High/Medium/Low productivity scoring|Monitor productivity distribution|

**Labor Efficiency Rules:**

```
LaborEfficiency = 
  IF HoursWorked > 0 THEN InvoiceHours / HoursWorked
  ELSE NULL

ProductivityScore = 
  IF LaborEfficiency >= 1.1 THEN "High Productivity"
  ELSE IF LaborEfficiency >= 0.9 THEN "Medium Productivity"  
  ELSE "Low Productivity"
```

---

### **5. CUSTOMER PERFORMANCE INTELLIGENCE CASCADE**

|**Layer**|**Component**|**Business Rule**|**Implementation**|**Validation**|
|---|---|---|---|---|
|**Raw Data**|Raw_CustomerPerformance|Monthly customer metrics by business line|One row per customer/month/business line|Check for data completeness|
|**Fact**|Fact_CustomerPerformance|YTD vs PYTD comparison logic|Current year 2025 vs Prior year 2024|Validate year comparison accuracy|
|**Fact**|Fact_CustomerPerformance|Customer health scoring algorithm|0-100 scale with 4 components|Check health score calculation|
|**Fact**|Fact_CustomerPerformance|Performance trend categorization|New, Lost, Strong Growth, Growth, Stable, Decline|Validate trend logic|
|**Business Intelligence**|Executive Dashboards|Strategic account identification|StrategicValue, RequiresAttention, RecommendedAction|Monitor strategic account accuracy|

**Customer Health Score Components (0-100):**

- **Growth Component (0-40)**: Based on SalesGrowthPercent
- **Volume Component (0-25)**: Based on TotalSales thresholds
- **Margin Component (0-20)**: Based on MarginPercentYTD
- **Consistency Component (0-15)**: Based on prior year history

---

### **6. PARTS TRANSACTION INTEGRATION CASCADE**

|**Layer**|**Component**|**Business Rule**|**Implementation**|**Validation**|
|---|---|---|---|---|
|**Raw Data**|Raw_InTrans|Parts transactions link to work orders|Branch + RONumber + JobCode + JobType|Check join key completeness|
|**Raw Data**|Raw_wkothsub|Work order job details for linking|Branch + InvoiceNo + JobCode + Type|Validate linking logic accuracy|
|**Fact**|Fact_WorkOrderParts|Parts-to-work-order linkage|InTrans → wkothsub → WorkOrders data lineage|Ensure correct join sequence|
|**Fact**|Fact_WorkOrderParts|Parts margin calculation|PartsMargin = SaleValue - CostValue|Check margin calculation|
|**Business Intelligence**|Profitability Analysis|Service episode profitability|Labor + Parts + Warranty combined analysis|Monitor complete service profitability|

**Parts Linkage Logic:**

```
InTrans.BRANCH = wkothsub.ro_branch
InTrans.REF_NO = wkothsub.invoice_no (RONumber = Invoice Number!)
InTrans.JOB_CODE = wkothsub.job_code  
InTrans.TYPE = wkothsub.type
```

---

### **7. PRIORITY SCORING ALGORITHM CASCADE**

|**Layer**|**Component**|**Business Rule**|**Implementation**|**Validation**|
|---|---|---|---|---|
|**Raw Data**|Raw_WorkOrderFile|Work order dates track timing|CreatedOn, ExpectedDate for age calculation|Check date field validity|
|**Fact**|Fact_WorkOrderHeader|Work order age calculation|WorkOrderAge = Today - CreatedOn|Validate age calculation|
|**Fact**|Fact_WorkOrderHeader|Priority scoring algorithm|0-100 scale with 4 components|Check priority calculation|
|**Business Intelligence**|Operations Dashboard|Critical work order identification|PriorityCategory: Critical/High/Medium/Low|Monitor priority distribution|

**Priority Score Components (0-100):**

- **Age Component (0-40)**: Based on WorkOrderAge thresholds
- **Overdue Component (0-25)**: Based on days past ExpectedDate
- **Customer Component (0-20)**: Based on customer tier/type
- **Value Component (0-15)**: Based on TotalJobValue thresholds

---

## 🛠️ BUSINESS RULE MAINTENANCE PROCEDURES

### **When Modifying Raw Data Sources:**

1. **Impact Assessment**: Check which dimensions and facts use the raw data
2. **Business Rule Review**: Verify existing business logic still applies
3. **Validation Update**: Update validation queries for new data patterns
4. **Documentation Update**: Revise this matrix with any rule changes

### **When Modifying Dimensions:**

1. **Fact Table Impact**: Check which facts reference the dimension
2. **Special Records**: Ensure special records still handle all scenarios
3. **Business Intelligence**: Verify calculated fields still work correctly
4. **Cross-Dimension**: Check for impacts on related dimensions

### **When Modifying Facts:**

1. **Business Intelligence**: Verify all calculated fields and categorizations
2. **Cross-Fact Integration**: Check impacts on related fact tables
3. **Dashboard Dependencies**: Ensure existing dashboards still function
4. **Performance Impact**: Monitor refresh times after changes

### **Quarterly Review Process:**

1. **Business Rule Validation**: Run all validation queries
2. **Performance Monitoring**: Check refresh times and data quality
3. **Business Stakeholder Review**: Confirm rules still meet business needs
4. **Documentation Updates**: Keep this matrix current with any changes

---

## 📊 SUCCESS METRICS FOR BUSINESS RULES

|**Business Rule Category**|**Success Metric**|**Target**|**Monitoring Method**|
|---|---|---|---|
|Customer Assignment|Customer assignment success rate|>99%|Count work orders with CustomerKey <> -1|
|Vehicle Identification|Vehicle linkage success rate|>95%|Count work orders with valid VehicleKey|
|Status Workflow|Status progression accuracy|>98%|Validate status sequence logic|
|Labor Efficiency|Calculation accuracy|100%|Check efficiency formula consistency|
|Customer Health Scoring|Score distribution|Normal curve|Monitor score component calculations|
|Parts Integration|Parts-to-WO linkage rate|>90%|Validate parts transaction matching|
|Priority Scoring|Priority distribution|70% Low/Medium, 30% High/Critical|Monitor priority algorithm results|

---

_Business Rule Matrix Version 1.0 | Last Updated: August 20, 2025 | Next Review: November 20, 2025_