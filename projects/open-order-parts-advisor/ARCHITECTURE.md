# Job Code Parts Advisor — Architecture

**Report file:** `Job Code Parts Advisor.SemanticModel` / `Job Code Parts Advisor.Report`
**Workspace:** RP - Sandbox (testing) → RP - Service Reports (production)
**Audience:** After Market Sales Manager, Corp Service Manager, Branch Managers

---

## Purpose

Two related use cases in one report:

1. **Job Code Advisor (Page 1)** — For any job code, show which parts should be staged before the job starts. Parts are ranked by 3-year historical co-occurrence frequency into recommendation tiers (Always / Usually / Sometimes / Rarely). Helps the parts desk pre-pull before a work order is written.

2. **Branch Comparison (Page 2)** — For a selected job code, compare which parts different branches are actually adding vs. what the company average looks like. Surfaces inconsistencies: "Seminole adds B12 to IS-TRACTOR INSPECT 80% of the time. Tahoka never does — should they?" Drives training and standardization conversations.

---

## Data Flow

```
wkothsub (Lakehouse)         InTrans_Incremental (Lakehouse)
     │                               │
     └─────────── JOIN on ──────────┘
         wkothsub.InvoiceNumber
              = InTrans.RONumber          ← ⚠️ RONumber IS the invoice number
                    │
         ┌──────────┴──────────┐
         │                     │
Fact_JobCodePartFrequency   Fact_JobCodePartFrequency_Branch
  (company-wide)                (branch-level)
  JobCode × PartNumber          Branch × JobCode × PartNumber
         │                              │
  Fact_GapAnalysis           Fact_BranchAnalysis
  (DAX calculated)            (DAX calculated)
  Page 1 source               Page 2 source
```

---

## Critical Join Warning

`InTrans_Incremental.RONumber` (source column `REF_NO`) is the **invoice number**, not the work order number.

Joining on work order number returns ~1% of the correct row count. Always join:

```
wkothsub.InvoiceNumber = InTrans_Incremental.RONumber
```

For the branch-level query, the join key must include Branch: `{InvoiceNumber, Branch}`. The same invoice number can theoretically appear at different branches; including Branch in both join legs prevents incorrect cross-branch matching.

---

## Lakehouse Tables

### Source tables (Phase 1 raw, already exist)

| Table | Key Columns Used | Notes |
|---|---|---|
| `wkothsub` | Branch, WorkOrder, JobCode, InvoiceNumber, InvoiceDate | Invoiced work orders only (InvoiceNumber not null/empty) |
| `InTrans_Incremental` | Branch, RONumber, PartNumber | RONumber = invoice number |

### Fact tables (Phase 4, built by dataflows)

| Table | Grain | Rows (approx) | Refresh |
|---|---|---|---|
| `Fact_JobCodePartFrequency` | JobCode × PartNumber | — | Full daily, Phase 4 |
| `Fact_JobCodePartFrequency_Branch` | Branch × JobCode × PartNumber | 1.38M | Full daily, Phase 4 |

**Columns in both tables:**

| Column | Type | Description |
|---|---|---|
| JobCode | TEXT | e.g. `/IS-TRACTOR INSPECT` |
| PartNumber | TEXT | Part number |
| TimesWithPart | INT | Distinct WOs where job code + part appeared together |
| TotalOrdersWithJobCode | INT | Distinct WOs where this job code appeared |
| FrequencyPct | FLOAT | TimesWithPart / TotalOrdersWithJobCode |

`Fact_JobCodePartFrequency_Branch` adds a `Branch` column (TEXT) and all grouping keys include Branch.

**Query library:** `.claude/queries/facts/Fact_JobCodePartFrequency.pq` and `Fact_JobCodePartFrequency_Branch.pq`

---

## Semantic Model Tables

### Imported tables (from Lakehouse)

| Table | Purpose |
|---|---|
| `Fact_JobCodePartFrequency` | Company-wide base frequency data |
| `Fact_JobCodePartFrequency_Branch` | Branch-level base frequency data |
| `dim_JobCodes` | Job code dimension (JobCode, Description, FactoryCode) |
| `dim_Parts` | Parts dimension (PartNumber, Description, SellPrice1, Franchise) |
| `dim_BranchLocation` | Branch dimension (BranchID, BranchName, State, City, etc.) |
| `dim_DateTable` | Standard date dimension |
| `Data Refresh` | Report refresh timestamp |

### Calculated tables (DAX, built at model refresh)

#### `Fact_GapAnalysis` — Page 1 source

Grain: JobCode × PartNumber (company-wide)

**Filters applied:**
- `TotalOrdersWithJobCode >= 10` (minimum statistical sample)
- `FrequencyPct >= 0.05` (5% minimum co-occurrence)
- `LEFT(PartNumber, 1) <> "*"` (excludes labor/misc lines)
- `dim_Parts[Franchise] <> "ZP"` (excludes ZP franchise parts)

**Added columns:**

| Column | Source |
|---|---|
| PartDescription | `LOOKUPVALUE(dim_Parts[Description], ...)` |
| SellPrice | `LOOKUPVALUE(dim_Parts[SellPrice1], ...)` |
| JobDescription | `LOOKUPVALUE(dim_JobCodes[Description], ...)` |
| FactoryCode | `LOOKUPVALUE(dim_JobCodes[FactoryCode], ...)` |
| RecommendationTier | `IF(FrequencyPct >= 0.50, "Always", IF(>= 0.25, "Usually", IF(>= 0.10, "Sometimes", "Rarely")))` |
| TierSortOrder | 1 / 2 / 3 / 4 corresponding to the tier above |

#### `Fact_BranchAnalysis` — Page 2 source

Grain: Branch × JobCode × PartNumber

**Filters applied:**
- `TotalOrdersWithJobCode >= 3` (lower threshold because branch-level volume is smaller)
- `FrequencyPct >= 0.05`
- `LEFT(PartNumber, 1) <> "*"`
- `dim_Parts[Franchise] <> "ZP"`

**Added columns:** same as Fact_GapAnalysis, plus:

| Column | Source | Notes |
|---|---|---|
| CompanyFrequencyPct | `MAXX(FILTER(Fact_JobCodePartFrequency, ...))` | Company-wide freq for the same JobCode × PartNumber. Uses MAXX/FILTER instead of LOOKUPVALUE to handle potential duplicate rows in the source table gracefully. |

### Disconnected parameter table

#### `dim_FrequencyFilter` — frequency threshold slicer

4 rows, no relationship to any other table. Powers the button slicer on Page 2.

| FilterLabel | FilterThreshold | SortOrder |
|---|---|---|
| Show All | 0.00 | 0 |
| ≥ 10% | 0.10 | 1 |
| ≥ 25% | 0.25 | 2 |
| ≥ 50% | 0.50 | 3 |

---

## Relationships

| From | To | Direction | Notes |
|---|---|---|---|
| `Fact_GapAnalysis[JobCode]` | `dim_JobCodes[JobCode]` | Single | Enables JobCode slicer to drive Page 1 |
| `Fact_BranchAnalysis[JobCode]` | `dim_JobCodes[JobCode]` | Single | Enables JobCode slicer to drive Page 2 |
| `Fact_BranchAnalysis[Branch]` | `dim_BranchLocation[BranchID]` | Single | Enables Branch slicer / filtering |

`dim_FrequencyFilter` has no relationship — it is intentionally disconnected. The `Show Part (Freq Filter)` measure reads it via `SELECTEDVALUE`.

---

## Key Measures

### Page 1 — Job Code Advisor

| Measure | Description |
|---|---|
| `Home - Header` | HTML gradient banner with greeting, user name, date |
| `Job Code Banner` | HTML banner for selected job code: shows job code, order count, tier counts, staging value (Always + Usually sell prices) |
| `KPI Cards - Summary` | HTML card row: Job Codes Analyzed, Always Stage, Usually Needed, Top Recommendations |
| `Total Job Codes Analyzed` | `DISTINCTCOUNT(Fact_GapAnalysis[FactoryCode])` |
| `Always Recommend` | COUNTROWS filtered to tier = "Always" |
| `Usually Recommend` | COUNTROWS filtered to tier = "Usually" |
| `Top Recommendations` | Always + Usually combined |

### Page 2 — Branch Comparison

| Measure | Description |
|---|---|
| `Branch Analysis Banner` | HTML gradient banner: branch count, company order count, unique parts for selected job code |
| `Branch Analysis Key Finding` | HTML card: auto-identifies the most variable part (max branch spread) for the selected job code. Shows Branch Spread (yellow), Highest Branch (green), Lowest Branch (red), Company Avg (blue). |
| `Branch Frequency %` | `MAX(Fact_BranchAnalysis[FrequencyPct])` — branch-specific rate for a given Part × Branch cell |
| `Branch Freq Display` | `"67% (12)"` — frequency + raw TimesWithPart count in one string. Used as the matrix value to surface small sample sizes (prevents false confidence on "100% (2)" type cells). |
| `Branch Order Count` | `MAX(Fact_BranchAnalysis[TotalOrdersWithJobCode])` |
| `Company Frequency %` | `MAX(Fact_BranchAnalysis[CompanyFrequencyPct])` — company-wide rate for comparison |
| `Branch vs Company Difference` | `[Branch Frequency %] - [Company Frequency %]` — signed delta, formatted `+0.0%` |
| `Branch vs Company Difference (Abs)` | Absolute value of the above |
| `Divergence Direction` | `"▲ Above Average"` / `"▼ Below Average"` / `"≈ Near Average"` based on ±10% threshold |
| `Branch Freq Background Color` | Returns hex color string for conditional formatting: `#F59E0B` (gold, ≥50%), `#16A34A` (green, ≥25%), `#3B82F6` (blue, ≥10%), `#9CA3AF` (gray, <10%) |
| `Divergence Font Color` | Returns hex: green `#94CE9D` (above avg), red `#F99C9C` (below avg), gray (near avg) |
| `Is Significant Divergence` | 1 if absolute difference ≥ 10%, else 0 |
| `Show Part (Freq Filter)` | Returns 1 if `[Company Frequency %] >= SELECTEDVALUE(dim_FrequencyFilter[FilterThreshold], 0)`. Used as visual-level filter (= 1) on the matrix. |

---

## Page 2 Matrix Design

**Structure:**
- Rows: PartNumber, Description (from `Fact_BranchAnalysis`)
- Columns: Branch names (from `dim_BranchLocation`)
- Values: `Branch Freq Display` (text, e.g. "67% (12)")
- Row sort: Company Frequency % descending (most commonly used parts at top)
- Background color CF: `Branch Freq Background Color` (applied to the display measure cells)

**Known limitation:** Power BI matrix row sort by a value measure does not work via column header click when row hierarchy has its own default sort. Workaround: sort is applied via Power BI's "Sort by" pane, not column header interaction.

**Frequency filter slicer:** Tile/button slicer on `dim_FrequencyFilter[FilterLabel]` (sorted by `SortOrder`). When a threshold is selected, the `Show Part (Freq Filter)` visual-level filter removes parts below that company frequency. Default selection: "Show All".

---

## Recommendation Tier Logic

Tiers apply to both `Fact_GapAnalysis` (company-wide) and `Fact_BranchAnalysis` (branch-level):

| Tier | FrequencyPct | Interpretation |
|---|---|---|
| Always | ≥ 50% | Part used in more than half of all orders for this job code |
| Usually | 25–49% | Part used in roughly 1-in-4 to 1-in-2 orders |
| Sometimes | 10–24% | Worth knowing about; may be conditional on other factors |
| Rarely | 5–9% | Low frequency; retained for completeness |

Tiers below 5% are excluded by the `FrequencyPct >= 0.05` filter in both calculated tables.

---

## Design Decisions

**MAXX/FILTER instead of LOOKUPVALUE for CompanyFrequencyPct**

`Fact_JobCodePartFrequency` can contain duplicate JobCode × PartNumber rows due to the aggregation logic in the Fabric dataflow. `LOOKUPVALUE` throws "table of multiple values" when duplicates exist. `MAXX(FILTER(...))` returns the maximum value gracefully and produces correct results since FrequencyPct is the same across any duplicates.

**Lower order threshold for branch analysis (3 vs 10)**

Branch-level order counts are naturally smaller than company-wide counts. Using the same threshold of 10 would exclude most branches for most job codes. The threshold of 3 retains meaningful branch data while still requiring at least a minimal sample.

**Branch Freq Display instead of Branch Frequency %**

Showing only a percentage in the matrix creates "false positives" — a branch with 2 orders shows "100%", which looks like strong evidence but isn't. The combined `"100% (2)"` format surfaces the sample size without adding a separate column, allowing users to make their own confidence judgments.

**Disconnected slicer for frequency threshold**

`dim_FrequencyFilter` has no model relationship. This is intentional — a relationship would create bidirectional filter issues with the fact tables. The measure reads the selected value via `SELECTEDVALUE` instead.

---

## Refresh Pipeline

| Table | Phase | Wave | Notes |
|---|---|---|---|
| `Fact_JobCodePartFrequency` | Phase 4 | Last wave | Compute-intensive; keep in final wave |
| `Fact_JobCodePartFrequency_Branch` | Phase 4 | Last wave | Same wave as sibling, slightly longer runtime due to Branch dimension |
| Semantic model refresh | Phase 5 | — | Calculated tables built here |

Calculated tables (`Fact_GapAnalysis`, `Fact_BranchAnalysis`, `dim_FrequencyFilter`) are computed at semantic model refresh time, not in the dataflows.
