## **🚀 ROLLING PERIOD INTELLIGENCE 

### **🎯 NEW ROLLING PERIOD FLAGS ADDED**

#### **Monthly Rolling Periods (Your Core Request):**

- `IsRolling6Months` - Short-term operational trends
- `IsRolling12Months` - **Most requested** - annual rolling analysis
- `IsRolling24Months` - Two-year strategic planning
- `IsRolling36Months` - Three-year pattern identification
- `IsRolling48Months` - Four-year comprehensive analysis

#### **Quarter & Week Aligned Periods:**

- `IsRolling4Quarters` - Quarter-aligned 12-month analysis
- `IsRolling8Quarters` - Quarter-aligned 24-month analysis
- `IsRolling52Weeks` - Week-aligned annual metrics

## **💡 REAL-WORLD BUSINESS EXAMPLES**

### **🔥 Executive Dashboard Examples**

#### **Rolling 12-Month KPIs (Most Common Request):**

dax

```dax
Revenue_Rolling12 = 
CALCULATE(
    [Total Revenue],
    dim_DateTable[IsRolling12Months] = TRUE
)

Customer_Count_Rolling12 = 
CALCULATE(
    DISTINCTCOUNT(Fact_WorkOrderHeader[CustomerKey]),
    dim_DateTable[IsRolling12Months] = TRUE
)
```

#### **Multi-Period Trend Analysis:**

dax

```dax
// Compare different rolling periods on same chart
Rolling_12_Month_Parts = CALCULATE([Parts Sales], dim_DateTable[IsRolling12Months] = TRUE)
Rolling_24_Month_Parts = CALCULATE([Parts Sales], dim_DateTable[IsRolling24Months] = TRUE)
Rolling_36_Month_Parts = CALCULATE([Parts Sales], dim_DateTable[IsRolling36Months] = TRUE)
```

### **📊 Advanced Analytics Examples**

#### **Rolling Average Calculations:**

dax

```dax
Rolling12_AvgMonthlyRevenue = 
DIVIDE(
    CALCULATE([Total Revenue], dim_DateTable[IsRolling12Months] = TRUE),
    12  // 12 months
)

Rolling24_AvgQuarterlyGrowth = 
DIVIDE(
    CALCULATE([Revenue Growth], dim_DateTable[IsRolling24Months] = TRUE),
    8   // 8 quarters
)
```

#### **Seasonal Pattern Analysis:**

dax

```dax
Peak_Season_Rolling12 = 
CALCULATE(
    [Service Revenue],
    dim_DateTable[IsRolling12Months] = TRUE,
    dim_DateTable[IsPeakSeason] = TRUE
)
```

### **⚙️ Operational Dashboard Examples**

#### **Equipment Service Trends:**

dax

```dax
Equipment_Service_Rolling6 = 
CALCULATE(
    COUNTROWS(Fact_WorkOrderHeader),
    dim_DateTable[IsRolling6Months] = TRUE,
    dim_Vehicle[VehicleCategory] = "Heavy Equipment"
)
```

#### **Technician Productivity (52-Week Analysis):**

dax

```dax
Technician_Efficiency_Rolling52 = 
CALCULATE(
    AVERAGE(Fact_WorkOrderLabor[LaborEfficiency]),
    dim_DateTable[IsRolling52Weeks] = TRUE
)
```

## **🎯 DASHBOARD FILTER STRATEGIES**

### **Single Rolling Period Dashboards:**

```
Page Filter: dim_DateTable[IsRolling12Months] = TRUE
Result: All visuals automatically show rolling 12-month data
```

### **Comparative Rolling Period Analysis:**

```
Matrix Visual:
Rows: Metrics (Revenue, Parts Sales, Service Hours)
Columns: Rolling6Months, Rolling12Months, Rolling24Months
Values: Calculated measures
```

### **Trend Acceleration Analysis:**

dax

```dax
Trend_Acceleration = 
VAR Rolling12 = CALCULATE([Revenue], dim_DateTable[IsRolling12Months] = TRUE)
VAR Rolling24 = CALCULATE([Revenue], dim_DateTable[IsRolling24Months] = TRUE)
VAR Rolling24_Monthly = DIVIDE(Rolling24, 24)
VAR Rolling12_Monthly = DIVIDE(Rolling12, 12)
RETURN Rolling12_Monthly - Rolling24_Monthly  // Positive = accelerating
```

## **📈 STRATEGIC PLANNING APPLICATIONS**

### **1. Budget Planning with Historical Rolling Patterns:**

dax

```dax
Budget_Baseline_Rolling36 = 
CALCULATE(
    AVERAGE([Monthly Revenue]),
    dim_DateTable[IsRolling36Months] = TRUE
) * 1.05  // 5% growth assumption
```

### **2. Customer Retention Analysis:**

dax

```dax
Customer_Retention_Rolling24 = 
VAR CustomersRolling24 = CALCULATE(DISTINCTCOUNT([CustomerKey]), dim_DateTable[IsRolling24Months] = TRUE)
VAR CustomersRolling12 = CALCULATE(DISTINCTCOUNT([CustomerKey]), dim_DateTable[IsRolling12Months] = TRUE)
RETURN DIVIDE(CustomersRolling12, CustomersRolling24)
```

### **3. Equipment Reliability Scoring:**

dax

```dax
Equipment_Reliability_Rolling48 = 
CALCULATE(
    DIVIDE([Total Service Hours], [Equipment Count]),
    dim_DateTable[IsRolling48Months] = TRUE
)
```

## **⚡ PERFORMANCE BENEFITS**

### **Before (Complex DAX):**

dax

```dax
// Complex, slow, error-prone
Rolling12Revenue = 
CALCULATE(
    [Revenue],
    DATESINPERIOD(
        dim_DateTable[Date],
        LASTDATE(dim_DateTable[Date]),
        -12,
        MONTH
    )
)
```

### **After (Simple Filter):**

dax

```dax
// Simple, fast, reliable
Rolling12Revenue = 
CALCULATE(
    [Revenue],
    dim_DateTable[IsRolling12Months] = TRUE
)
```

## **🔄 BUSINESS PROCESS INTEGRATION**

### **Monthly Business Reviews:**

- Filter dashboards by `IsRolling12Months` for consistent 12-month trend analysis
- Use `IsRolling6Months` for short-term operational adjustments

### **Quarterly Strategic Planning:**

- `IsRolling8Quarters` for two-year strategic planning cycles
- `IsRolling4Quarters` for annual performance evaluation

### **Annual Board Presentations:**

- `IsRolling48Months` for comprehensive four-year performance analysis
- `IsRolling36Months` for three-year trend identification