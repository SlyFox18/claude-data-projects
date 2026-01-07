# Price Matrix - Sales Report: Calculation Documentation

**Purpose:** This document explains how each metric in the Price Matrix - Sales table is calculated, what data sources are used, and the business logic behind each measure.

**Last Updated:** November 26, 2025

---

## Data Sources Overview

### Primary Fact Tables

#### 1. Fact_Inventory

- **Built From:** jdis_Part_Information table (Lakehouse)
- **Purpose:** Current inventory snapshot with pricing and 12-month sales history
- **Key Columns Used:**
  - `PartNumber` - Part identifier
  - `ListPrice` - Manufacturer's list price (used to classify parts into price ranges)
  - `Current12MoSales` - Sales quantity over last 12 months (used to filter active parts)

#### 2. Fact_Part_Transactions

- **Built From:** InTrans table (Lakehouse)
- **Purpose:** Actual invoiced transaction records with historical pricing
- **Key Columns Used:**
  - `PartNumber` - Part identifier (links to inventory)
  - `TransactionDate` - When the sale occurred
  - `Quantity` - Units sold
  - `SaleAmount` - Actual revenue from the transaction
  - `CostAmount` - Cost of goods sold
  - `Margin` - Profit (SaleAmount - CostAmount)
  - `ListPrice` - List price at time of transaction
  - `SellPrice1` - Standard selling price at time of transaction
  - `EffectiveListSalVal` - What the sale would have been at effective list price
  - `EffectiveListMargin` - What the margin would have been at effective list price
  - `MatrixSaleGained` - Extra revenue from selling above list price

#### 3. Price_Matrix

- **Source:** OneDrive CSV file
- **Purpose:** Defines price ranges and target markup percentages
- **Key Columns:**
  - `value_from` - Start of price range (e.g., $100.00)
  - `value_to` - End of price range (e.g., $149.99)
  - `price_percent` - Target markup % for this range

---

## How Parts Are Classified Into Ranges

**Classification Logic:**

1. Each part has a `ListPrice` from Fact_Inventory (manufacturer's list price)
2. Parts are assigned to a price range based on where their ListPrice falls
3. **Only parts with sales activity are included** (Current12MoSales > 0)
4. Example: A part with ListPrice of $125.00 goes into the $100.00 - $149.99 range

**Why This Matters:**

- The ListPrice determines which price range a part belongs to
- Transaction data then shows how those parts actually performed in real sales
- This allows comparison of actual performance vs. expected performance for each price tier

---

## Measure-by-Measure Breakdown

### 1. Markup (from Price_Matrix table)

**Column Name:** Markup  
**Source:** Price_Matrix CSV file  
**Logic:** This is the target markup percentage defined in your pricing strategy

**Example:** 5.26% for $100.00 - $149.99 range means parts in this range should sell at 5.26% above list price

---

### 2. Parts Count

**Measure Name:** `Unique Parts in Range`  
**Fact Table:** Fact_Inventory  
**Raw Source:** jdis_Part_Information  

**Columns Used:**

- `PartNumber` - Counted as distinct values
- `ListPrice` - Used to filter parts into price range
- `Current12MoSales` - Filtered to exclude parts with no sales (> 0)

**Business Logic:**

- For each price range: Count how many unique parts have a ListPrice in that range AND have had sales
- For Total row: Count all unique parts that have had sales
- **Why filter on Current12MoSales?** Only analyzes parts that are actively selling

**Example from your report:**

- $100.00 - $149.99 range: 1,117 unique parts with ListPrice between $100-$149.99 that had sales

---

### 3. Transaction Part Count

**Measure Name:** `Transaction Count for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (to count transactions)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber` - To identify which parts are in range
  - `ListPrice` - To determine price range
  - `Current12MoSales` - To filter active parts (> 0)
- From Fact_Part_Transactions:
  - `PartNumber` - To match transactions to parts
  - `SaleAmount` - Filtered to positive values only (> 0)

**Business Logic:**

1. First: Find all parts in the price range (based on their ListPrice from inventory)
2. Then: Count how many transaction records exist for those parts
3. **Only counts actual sales** (SaleAmount > 0, excludes returns and adjustments)

**Example from your report:**

- $100.00 - $149.99 range: 36,422 individual transaction records for the 1,117 parts in this range

---

### 4. Part Qty (Transaction Quantity)

**Measure Name:** `Transaction Quantity for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (to sum quantities)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber` - To identify which parts are in range
  - `ListPrice` - To determine price range
  - `Current12MoSales` - To filter active parts (> 0)
- From Fact_Part_Transactions:
  - `PartNumber` - To match transactions to parts
  - `Quantity` - Summed for all transactions
  - `TransactionDate` - Filtered to last 12 months
  - `SaleAmount` - Filtered to positive values (> 0)
  - `Quantity` - Also filtered to positive values (> 0, excludes returns)

**Business Logic:**

1. Find all parts in the price range
2. Look at their transactions from the **last 12 months** (TODAY() minus 12 months)
3. Sum up the Quantity field from all qualifying transactions
4. **Only counts actual sales** (positive SaleAmount and positive Quantity)

**Example from your report:**

- $100.00 - $149.99 range: 61,611 total units sold in the last 12 months

---

### 5. Avg Price

**Measure Name:** `Average Selling Price for Parts in Range`  
**Fact Tables:** Calculated measure (divides two other measures)  
**Raw Sources:** InTrans (via Fact_Part_Transactions)  

**Columns Used:**

- None directly - this is a calculation: Transaction Sales $ ÷ Transaction Quantity

**Business Logic:**
```
Average Price = Total Revenue ÷ Total Units Sold
```

**Example from your report:**

- $100.00 - $149.99 range: $8,265,550.16 ÷ 61,611 units = $134.16 average selling price

---

### 6. Transaction Sales $

**Measure Name:** `Transaction Sales $ for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (to sum revenue)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber` - To identify which parts are in range
  - `ListPrice` - To determine price range
  - `Current12MoSales` - To filter active parts (> 0)
- From Fact_Part_Transactions:
  - `PartNumber` - To match transactions to parts
  - `SaleAmount` - Summed for all transactions
  - `SaleAmount` - Also filtered to positive values (> 0)

**Business Logic:**

1. Find all parts in the price range (based on their ListPrice from inventory)
2. Sum up the SaleAmount from all their transactions
3. **Only counts actual sales** (SaleAmount > 0, excludes returns and credits)

**Example from your report:**

- $100.00 - $149.99 range: $8,265,550.16 total revenue from parts in this price tier

---

### 7. Transaction Margin $

**Measure Name:** `Transaction Margin $ for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (to sum margin)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber` - To identify which parts are in range
  - `ListPrice` - To determine price range
  - `Current12MoSales` - To filter active parts (> 0)
- From Fact_Part_Transactions:
  - `PartNumber` - To match transactions to parts
  - `Margin` - Summed for all transactions (calculated as SaleAmount - CostAmount)
  - `SaleAmount` - Filtered to positive values (> 0)

**Business Logic:**

1. Find all parts in the price range
2. Sum up the Margin field from all their transactions
3. **Margin was calculated in the fact table as:** SaleAmount - CostAmount
4. Only includes actual sales (positive SaleAmount)

**Example from your report:**

- $100.00 - $149.99 range: $2,719,380.48 total profit from parts in this price tier

---

### 8. Transaction Margin %

**Measure Name:** `Transaction Margin % for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (for calculation)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber`, `ListPrice`, `Current12MoSales` (to identify parts in range)
- From Fact_Part_Transactions:
  - `SaleAmount` - Summed for denominator
  - `Margin` - Summed for numerator
  - `SaleAmount` - Filtered to positive values (> 0)

**Business Logic:**
```
Transaction Margin % = Total Margin ÷ Total Sales
```

1. Find all parts in the price range
2. Sum up total Margin for those parts
3. Sum up total SaleAmount for those parts
4. Divide Margin by SaleAmount to get weighted average margin %

**Why weighted average?** Parts with higher sales have more influence on the overall percentage

**Example from your report:**

- $100.00 - $149.99 range: $2,719,380.48 ÷ $8,265,550.16 = 32.90% actual margin achieved

---

### 9. Effective List Sale Value

**Measure Name:** `Effective List Sale Value for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (to sum EffectiveListSalVal)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber`, `ListPrice`, `Current12MoSales` (to identify parts)
- From Fact_Part_Transactions:
  - `EffectiveListSalVal` - Pre-calculated column, summed
  - `SaleAmount` - Filtered to positive values (> 0)

**Business Logic - How EffectiveListSalVal is Calculated in the Fact Table:**
```
EffectiveListSalVal = 
  IF TransactionTradeType = "W" (warranty)
    THEN use actual SaleAmount (warranty pricing is special)
    ELSE adjust SaleAmount for discount: SaleAmount × (1 - % Change)

Where % Change = (SellPrice1SaleVal - ListSaleVal) ÷ SellPrice1SaleVal
```

**What This Means:**

- This represents what the sale **would have been** at the effective list price
- For warranty transactions: Uses actual sale amount (no adjustment)
- For regular transactions: Backs out the discount to show what revenue would be at list
- **Purpose:** Establishes baseline for comparing actual performance

**Example from your report:**

- $100.00 - $149.99 range: $8,118,825.22 is what sales would have been at effective list pricing

---

### 10. Effective List Margin $

**Measure Name:** `Effective List Margin $ for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (to sum EffectiveListMargin)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber`, `ListPrice`, `Current12MoSales` (to identify parts)
- From Fact_Part_Transactions:
  - `EffectiveListMargin` - Pre-calculated column, summed
  - `SaleAmount` - Filtered to positive values (> 0)

**Business Logic - How EffectiveListMargin is Calculated in the Fact Table:**
```
EffectiveListMargin = EffectiveListSalVal - CostAmount
```

**What This Means:**

- This is the profit you **would have made** if you had sold at effective list price
- Subtracts actual cost from the effective list sale value
- **Purpose:** Establishes baseline margin for comparison

**Example from your report:**

- $100.00 - $149.99 range: $2,572,655.54 would have been the profit at effective list pricing

---

### 11. Effective List Margin %

**Measure Name:** `Effective List Margin % for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (for calculation)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber`, `ListPrice`, `Current12MoSales` (to identify parts)
- From Fact_Part_Transactions:
  - `EffectiveListMargin` - Summed for numerator
  - `EffectiveListSalVal` - Summed for denominator
  - `SaleAmount` - Filtered to positive values (> 0)

**Business Logic:**
```
Effective List Margin % = Total EffectiveListMargin ÷ Total EffectiveListSalVal
```

**What This Means:**

- This is the margin percentage you **would have achieved** at effective list pricing
- Provides baseline for comparing actual margin % to expected margin %

**Example from your report:**

- $100.00 - $149.99 range: $2,572,655.54 ÷ $8,118,825.22 = 31.69% expected margin at list

---

### 12. Matrix Sale/Margin Gained

**Measure Name:** `Matrix Sale Gained for Parts in Range`  
**Fact Tables:** Fact_Inventory (to identify parts) + Fact_Part_Transactions (to sum MatrixSaleGained)  
**Raw Sources:** jdis_Part_Information + InTrans  

**Columns Used:**

- From Fact_Inventory:
  - `PartNumber`, `ListPrice`, `Current12MoSales` (to identify parts)
- From Fact_Part_Transactions:
  - `MatrixSaleGained` - Pre-calculated column, summed
  - `SaleAmount` - Filtered to positive values (> 0)

**Business Logic - How MatrixSaleGained is Calculated in the Fact Table:**
```
MatrixSaleGained = Actual SaleAmount - EffectiveListSalVal
```

**What This Means:**

- This is the **extra revenue** you gained by selling above the effective list price
- **Positive number:** You sold for more than effective list (good!)
- **Negative number:** You sold for less than effective list (discounted)
- **Purpose:** Measures the dollar impact of your matrix pricing strategy

**Example from your report:**

- $100.00 - $149.99 range: $146,724.94 extra revenue from selling above effective list price

---

### 13. Matrix Margin % Gained

**Measure Name:** `Matrix Margin % Gained`  
**Fact Tables:** Calculated measure (subtracts two other measures)  
**Raw Sources:** InTrans (via Fact_Part_Transactions)  

**Columns Used:**

- None directly - this is a calculation of other measures

**Business Logic:**
```
Matrix Margin % Gained = 
  Actual Transaction Margin % - Effective List Margin %
```

**What This Means:**

- This shows how many percentage points better (or worse) you did compared to list pricing
- **Positive number:** You achieved better margin than expected at list
- **Negative number:** Your margin was worse than expected at list
- **Purpose:** Measures effectiveness of pricing strategy in percentage terms

**Example from your report:**

- $100.00 - $149.99 range: 32.90% (actual) - 31.69% (list) = 1.21% margin improvement

---

## Key Insights for Stakeholder Discussion

### How the Report Works - Simple Explanation

1. **Parts are sorted into price ranges** based on their ListPrice from the inventory system
2. **Only active parts are analyzed** (parts that had sales in the last 12 months)
3. **Transaction data shows actual performance** - real sales, real prices paid, real margins earned
4. **Effective list pricing provides the baseline** - what revenue/margin would have been if parts sold at list price
5. **Matrix gained metrics show the difference** - how much better (or worse) you did than list pricing

### Critical Data Source Dependencies

**For part classification (which parts go in which range):**

- Uses **ListPrice** from Fact_Inventory (snapshot data from jdis_Part_Information)

**For actual performance (what really happened):**

- Uses **transaction records** from Fact_Part_Transactions (from InTrans)
- Includes historical pricing at time of sale: ListPrice, SellPrice1, actual SaleAmount

**For comparison/baseline:**

- Effective list calculations use the transaction's ListPrice and SellPrice1 to establish what would have happened at list pricing

### Questions to Consider for Changes

1. **Is ListPrice the right field for classification?**
   - Should we use SellPrice1 instead?
   - Should we use Cost-plus-markup instead?

2. **Are the date ranges correct?**
   - Transaction Quantity uses last 12 months
   - Other measures use all available transaction data
   - Should all measures be limited to same time period?

3. **Is the warranty adjustment correct?**
   - Currently: Warranty transactions (TradeType = "W") don't adjust the effective list value
   - Should warranty transactions be handled differently?

4. **Should we include/exclude certain transaction types?**
   - Currently: Only includes positive SaleAmount (excludes returns)
   - Should we handle returns differently?

---

**Document prepared for stakeholder review and calculation validation**