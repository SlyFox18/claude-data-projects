# DAX Measures Reference - Open Parts Tickets

**Purpose**: Complete reference for all 39 DAX measures with updated table names
**Use**: Copy these measures into Power BI Desktop or TMDL files

---

## Table Name Mapping

| Old Name | New Name |
|----------|----------|
| `Parts_Open_Tickets` | `Fact_Parts_Open_Tickets` |
| `Parts_Open_Tickets_Details` | `Fact_Parts_Open_Tickets_Details` |
| `Dim_Branch` | `dim_BranchLocation` |
| `dimDate` | `dim_DateTable` |

---

## CORE BUSINESS METRICS

### # Parts On Order
```dax
# Parts On Order =
SUM(Fact_Parts_Open_Tickets[#_Parts_On_Order])
```
**Format**: `0`
**Folder**: Core Metrics

### Order Total
```dax
Order Total =
SUM(Fact_Parts_Open_Tickets[Order_Total_$$])
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`
**Folder**: Core Metrics

### $$ not BO
```dax
$$ not BO =
SUM(Fact_Parts_Open_Tickets[$$_Available])
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`
**Folder**: Core Metrics

### Deposit
```dax
Deposit =
SUM(Fact_Parts_Open_Tickets[Deposit])
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`
**Folder**: Core Metrics

### # on Back Order
```dax
# on Back Order =
SUM(Fact_Parts_Open_Tickets[#_On_Back_Order])
```
**Format**: `0`
**Folder**: Core Metrics

### Backordered $$
```dax
Backordered $$ =
SUM(Fact_Parts_Open_Tickets[$$_BackOrdered])
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`
**Folder**: Core Metrics

### Backordered Line Count
```dax
Backordered Line Count =
SUM(Fact_Parts_Open_Tickets_Details[BackOrdered_QTY])
```
**Format**: `0`
**Folder**: Core Metrics

### Parts Line Count
```dax
Parts Line Count =
COUNT(Fact_Parts_Open_Tickets_Details[Part_No])
```
**Format**: `0`
**Folder**: Core Metrics

### Line Count
```dax
Line Count =
COUNT(Fact_Parts_Open_Tickets_Details[Part_No])
```
**Format**: `0`
**Folder**: Core Metrics

### Order Count
```dax
Order Count =
COUNTROWS(Fact_Parts_Open_Tickets)
```
**Format**: `0`
**Folder**: Core Metrics

### Total # of Orders
```dax
Total # of Orders =
COUNTROWS(Fact_Parts_Open_Tickets)
```
**Format**: `0`
**Folder**: Core Metrics

### Orders with Backordered Parts
```dax
Orders with Backordered Parts =
CALCULATE(
    COUNTROWS(Fact_Parts_Open_Tickets),
    Fact_Parts_Open_Tickets[#_On_Back_Order] > 0
)
```
**Format**: `0`
**Folder**: Core Metrics

### Average Days Open
```dax
Average Days Open =
AVERAGE(Fact_Parts_Open_Tickets[Days_Open])
```
**Folder**: Core Metrics

### Total Backorder Impact
```dax
Total Backorder Impact =
SUM(Fact_Parts_Open_Tickets[$$_BackOrdered])
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`
**Folder**: Core Metrics

---

## PERCENTAGE CALCULATIONS

### % of Parts on Back Order
```dax
% of Parts on Back Order =
DIVIDE(
    [# on Back Order],
    [# Parts On Order],
    0
)
```
**Format**: `0.00%;-0.00%;0.00%`
**Folder**: Percentages

### % # of Parts by line count
```dax
% # of Parts by line count =
DIVIDE(
    [Parts Line Count],
    [# Parts On Order],
    0
)
```
**Format**: `0.00%;-0.00%;0.00%`
**Folder**: Percentages

### % # Backordered by Line Count
```dax
% # Backordered by Line Count =
DIVIDE(
    [Backordered Line Count],
    [# on Back Order],
    0
)
```
**Format**: `0.00%;-0.00%;0.00%`
**Folder**: Percentages

---

## BRANCH COMPARISON MEASURES

### HighestValueCount
```dax
HighestValueCount =
MAXX(
    VALUES(dim_BranchLocation[Branch]),
    [Order Count]
)
```
**Format**: `0`
**Folder**: Branch Comparison

### LowestValueCount
```dax
LowestValueCount =
MINX(
    VALUES(dim_BranchLocation[Branch]),
    [Order Count]
)
```
**Format**: `0`
**Folder**: Branch Comparison

### Bar Color Order Count
```dax
Bar Color Order Count =
VAR ThisLocation = SELECTEDVALUE(dim_BranchLocation[LocationID])
VAR ThisOrderCount = [Order Count]
VAR MaxOrderCount =
    CALCULATE(
        MAXX(VALUES(dim_BranchLocation[LocationID]), [Order Count]),
        REMOVEFILTERS(dim_BranchLocation)
    )
VAR MinOrderCount =
    CALCULATE(
        MINX(VALUES(dim_BranchLocation[LocationID]), [Order Count]),
        REMOVEFILTERS(dim_BranchLocation)
    )
RETURN
    IF(
        ThisOrderCount = MaxOrderCount || ThisOrderCount = MinOrderCount,
        1,  // Highlight
        0   // Grey
    )
```
**Format**: `0`
**Folder**: Branch Comparison

### Bar Color Hex Order Total
```dax
Bar Color Hex Order Total =
VAR ThisLocation = SELECTEDVALUE(dim_BranchLocation[LocationID])
VAR ThisOrderTotal = [Order Total]
VAR MaxOrderTotal =
    CALCULATE(
        MAXX(VALUES(dim_BranchLocation[LocationID]), [Order Total]),
        REMOVEFILTERS(dim_BranchLocation)
    )
VAR MinOrderTotal =
    CALCULATE(
        MINX(VALUES(dim_BranchLocation[LocationID]), [Order Total]),
        REMOVEFILTERS(dim_BranchLocation)
    )
RETURN
    IF(
        ThisOrderTotal = MaxOrderTotal || ThisOrderTotal = MinOrderTotal,
        1,  // Highlight
        0   // Grey
    )
```
**Format**: `0`
**Folder**: Branch Comparison

### Bar Color Hex Back Order
```dax
Bar Color Hex Back Order =
VAR ThisLocation = SELECTEDVALUE(dim_BranchLocation[LocationID])
VAR ThisBackOrderCount = [# on Back Order]
VAR MaxBackOrder =
    CALCULATE(
        MAXX(VALUES(dim_BranchLocation[LocationID]), [# on Back Order]),
        REMOVEFILTERS(dim_BranchLocation)
    )
VAR MinBackOrder =
    CALCULATE(
        MINX(VALUES(dim_BranchLocation[LocationID]), [# on Back Order]),
        REMOVEFILTERS(dim_BranchLocation)
    )
RETURN
    IF(
        ThisBackOrderCount = MaxBackOrder || ThisBackOrderCount = MinBackOrder,
        1,  // Highlight
        0   // Grey
    )
```
**Format**: `0`
**Folder**: Branch Comparison

### Bar Color Hex $$ not BO
```dax
Bar Color Hex $$ not BO =
VAR ThisLocation = SELECTEDVALUE(dim_BranchLocation[LocationID])
VAR ThisValue = [$$ not BO]
VAR MaxValue =
    CALCULATE(
        MAXX(VALUES(dim_BranchLocation[LocationID]), [$$ not BO]),
        REMOVEFILTERS(dim_BranchLocation)
    )
VAR MinValue =
    CALCULATE(
        MINX(VALUES(dim_BranchLocation[LocationID]), [$$ not BO]),
        REMOVEFILTERS(dim_BranchLocation)
    )
RETURN
    IF(
        ThisValue = MaxValue || ThisValue = MinValue,
        1,  // Highlight
        0   // Grey
    )
```
**Format**: `0`
**Folder**: Branch Comparison

### Back Order Label
```dax
Back Order Label =
VAR ThisLocation = SELECTEDVALUE(dim_BranchLocation[LocationID])
VAR ThisBackOrder = [# on Back Order]
VAR MaxBackOrder =
    CALCULATE(
        MAXX(VALUES(dim_BranchLocation[LocationID]), [# on Back Order]),
        REMOVEFILTERS(dim_BranchLocation)
    )
VAR MinBackOrder =
    CALCULATE(
        MINX(VALUES(dim_BranchLocation[LocationID]), [# on Back Order]),
        REMOVEFILTERS(dim_BranchLocation)
    )
RETURN
    SWITCH(
        TRUE(),
        ThisBackOrder = MaxBackOrder, "Highest Back Order",
        ThisBackOrder = MinBackOrder, "Lowest Back Order",
        BLANK()
    )
```
**Folder**: Branch Comparison

---

## CUSTOMER ANALYSIS MEASURES

### Selected Top N
```dax
Selected Top N =
SELECTEDVALUE('TopN Selector'[TopN], -1)
```
**Format**: `0`
**Folder**: Customer Analysis

### Customer Rank - Order Count
```dax
Customer Rank - Order Count =
RANKX(
    ALL(Fact_Parts_Open_Tickets[Customer]),
    CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No])),
    ,
    DESC,
    DENSE
)
```
**Format**: `0`
**Folder**: Customer Analysis

### Customer Rank - Order Total
```dax
Customer Rank - Order Total =
RANKX(
    ALL(Fact_Parts_Open_Tickets[Customer]),
    [Order Total],
    ,
    DESC,
    DENSE
)
```
**Format**: `0`
**Folder**: Customer Analysis

### Filtered Order Count
```dax
Filtered Order Count =
VAR _TopN = [Selected Top N]
RETURN
    IF(
        _TopN = -1 || [Customer Rank - Order Count] <= _TopN,
        COUNT(Fact_Parts_Open_Tickets[Order_No])
    )
```
**Format**: `0`
**Folder**: Customer Analysis

### Filtered Order Total
```dax
Filtered Order Total =
VAR _TopN = [Selected Top N]
RETURN
    IF(
        _TopN = -1 || [Customer Rank - Order Total] <= _TopN,
        [Order Total]
    )
```
**Folder**: Customer Analysis

### Order Count 1
```dax
Order Count 1 =
CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No]))
```
**Format**: `0`
**Folder**: Customer Analysis

### Customer Rank
```dax
Customer Rank =
VAR BaseTable =
    ADDCOLUMNS(
        VALUES(Fact_Parts_Open_Tickets[Customer]),
        "OrderCount", [Order Count 1]
    )
RETURN
    RANKX(BaseTable, [Order Count 1], , DESC, DENSE)
```
**Format**: `0`
**Folder**: Customer Analysis

### Is In Top N
```dax
Is In Top N =
VAR _TopN = [Selected Top N]
RETURN
    IF(
        _TopN = -1 || [Customer Rank] <= _TopN,
        TRUE(),
        FALSE()
    )
```
**Format**: `"TRUE";"TRUE";"FALSE"`
**Folder**: Customer Analysis

### Bar Color Hex - Customer Count
```dax
Bar Color Hex - Customer Count =
VAR ThisCustomer = SELECTEDVALUE(Fact_Parts_Open_Tickets[Customer])
VAR ThisValue = CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No]))
VAR MaxValue =
    CALCULATE(
        MAXX(
            VALUES(Fact_Parts_Open_Tickets[Customer]),
            CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No]))
        ),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Customer])
    )
VAR MinValue =
    CALCULATE(
        MINX(
            VALUES(Fact_Parts_Open_Tickets[Customer]),
            CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No]))
        ),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Customer])
    )
RETURN
    IF(
        ThisValue = MaxValue || ThisValue = MinValue,
        "#446FA7",  // Highlight
        "#B3B3B3"   // Default
    )
```
**Folder**: Customer Analysis

### Bar Color Hex - Customer Total
```dax
Bar Color Hex - Customer Total =
VAR ThisCustomer = SELECTEDVALUE(Fact_Parts_Open_Tickets[Customer])
VAR ThisValue = [Order Total]
VAR MaxValue =
    CALCULATE(
        MAXX(VALUES(Fact_Parts_Open_Tickets[Customer]), [Order Total]),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Customer])
    )
VAR MinValue =
    CALCULATE(
        MINX(VALUES(Fact_Parts_Open_Tickets[Customer]), [Order Total]),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Customer])
    )
RETURN
    IF(
        ThisValue = MaxValue || ThisValue = MinValue,
        1,  // Light Salmon for highlight
        0
    )
```
**Format**: `0`
**Folder**: Customer Analysis

---

## SALESMAN ANALYSIS MEASURES

### Salesman Rank - Order Count
```dax
Salesman Rank - Order Count =
RANKX(
    ALL(Fact_Parts_Open_Tickets[Salesman]),
    CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No])),
    ,
    DESC,
    DENSE
)
```
**Format**: `0`
**Folder**: Salesman Analysis

### Salesman Rank - Order Total
```dax
Salesman Rank - Order Total =
RANKX(
    ALL(Fact_Parts_Open_Tickets[Salesman]),
    [Order Total],
    ,
    DESC,
    DENSE
)
```
**Format**: `0`
**Folder**: Salesman Analysis

### Filtered Order Count - Salesman
```dax
Filtered Order Count - Salesman =
VAR _TopN = [Selected Top N]
RETURN
    IF(
        _TopN = -1 || [Salesman Rank - Order Count] <= _TopN,
        COUNT(Fact_Parts_Open_Tickets[Order_No])
    )
```
**Format**: `0`
**Folder**: Salesman Analysis

### Filtered Order Total - Salesman
```dax
Filtered Order Total - Salesman =
VAR _TopN = [Selected Top N]
RETURN
    IF(
        _TopN = -1 || [Salesman Rank - Order Total] <= _TopN,
        [Order Total]
    )
```
**Folder**: Salesman Analysis

### Bar Color Hex - Salesman Count
```dax
Bar Color Hex - Salesman Count =
VAR ThisSalesman = SELECTEDVALUE(Fact_Parts_Open_Tickets[Salesman])
VAR ThisValue = COUNT(Fact_Parts_Open_Tickets[Order_No])
VAR MaxValue =
    CALCULATE(
        MAXX(
            VALUES(Fact_Parts_Open_Tickets[Salesman]),
            CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No]))
        ),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Salesman])
    )
VAR MinValue =
    CALCULATE(
        MINX(
            VALUES(Fact_Parts_Open_Tickets[Salesman]),
            CALCULATE(COUNT(Fact_Parts_Open_Tickets[Order_No]))
        ),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Salesman])
    )
RETURN
    IF(
        ThisValue = MaxValue || ThisValue = MinValue,
        1,  // Lime Green
        0
    )
```
**Format**: `0`
**Folder**: Salesman Analysis

### Bar Color Hex - Salesman Total
```dax
Bar Color Hex - Salesman Total =
VAR ThisSalesman = SELECTEDVALUE(Fact_Parts_Open_Tickets[Salesman])
VAR ThisValue = [Order Total]
VAR MaxValue =
    CALCULATE(
        MAXX(VALUES(Fact_Parts_Open_Tickets[Salesman]), [Order Total]),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Salesman])
    )
VAR MinValue =
    CALCULATE(
        MINX(VALUES(Fact_Parts_Open_Tickets[Salesman]), [Order Total]),
        REMOVEFILTERS(Fact_Parts_Open_Tickets[Salesman])
    )
RETURN
    IF(
        ThisValue = MaxValue || ThisValue = MinValue,
        1,  // Medium Purple
        0
    )
```
**Format**: `0`
**Folder**: Salesman Analysis

---

## TIME INTELLIGENCE

### Order Total Same Period Last Year
```dax
Order Total Same Period Last Year =
CALCULATE(
    [Order Total],
    SAMEPERIODLASTYEAR(Fact_Parts_Open_Tickets[Order_Date])
)
```
**Folder**: Time Intelligence

---

## NOTES

### TopN Selector Table
You'll need to create a disconnected table for the Top N selector:

```dax
TopN Selector =
DATATABLE(
    "TopN", INTEGER,
    "Label", STRING,
    "SortOrder", INTEGER,
    {
        {5, "Top 5", 1},
        {10, "Top 10", 2},
        {15, "Top 15", 3},
        {20, "Top 20", 4},
        {-1, "All", 5}
    }
)
```

This table is used for the customer and salesman ranking filters.

---

## SVG MEASURES

**Note**: The 8 SVG KPI measures are very long (300+ lines each). They create visual bar charts directly in DAX.

I recommend:
1. Copy from `info-exports/old report/Model Measures.csv`
2. Update table references using find/replace
3. Test one at a time in Power BI

**SVG Measures to add**:
- `KPI SVG - Not Backordered vs Backordered (Conditional Color)`
- `KPI SVG - Parts On Order vs Back Order (Conditional Color)`
- `KPI SVG - Line Count vs Backordered Line (Conditional Color)`
- `KPI SVG - Orders vs Orders with BO Parts (Conditional Color)`
- Plus 4 "compact" versions

These create the visual cards in the Overview page.
