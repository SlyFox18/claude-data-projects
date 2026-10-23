# JD price trigger exploration

Exploratory analysis of JD price changes: after a part's price moves 10%, which way does the next 10% move go, and how long does it take? Also covers JD's repricing calendar, product groups, buy-ahead sizing and how predictable changes are. Started 2026-10-16. Not a production report.

**Dashboard:** [JD Price Triggers](https://claude.ai/artifact/KD1HNGsi7TWrZfydDDCyPh), a Claude dashboard artifact. It's private until shared from its Share menu. Its data is a fixed snapshot (DP Prod, 12 Oct 2026) attached as JSON files; it does not refresh itself.

## Files

| File | What it does |
|---|---|
| `pull.py` | Copies `Fact_PartPriceChange`, `Fact_JDNationalPriceChange`, `dim_Parts` and a per-date summary of `Fact_PartPriceChange_Branch` from DP Prod into a local DuckDB file. Read-only. |
| `analyze.py` | Trigger detection (both definitions), transitions, wait histograms, wave calendar, group price index, momentum, quick reversals, buy-ahead inputs → `data.json`. |
| `margin.py` | Price Matrix buckets and margin: wave heatmap by group and bucket, margin by wave, margin by bucket, price index by bucket → `margin.json`. Bucket ranges and markups are copied from `PRICE MATRIX 7-9-25.csv` (OneDrive `Power BI - Vis/Data`); update `PM` if the matrix changes. |
| `export.py` | `data.json` + `margin.json` → one JSON row file per dashboard dataset (`out/*.json`). |
| `dashboard_page.html` | The dashboard's page (`files/index.html` in the artifact's store). |
| `build_excel.py` | Five Excel workbooks for digging in (`excel/`, git-ignored): JD Discount Cuts, Margin Changes by Wave, Price Matrix Boundary Watch, Buy-Ahead Candidates, JD Price Changes Since 2024 - Parts We Sell. Derived columns are formulas; yellow cells are inputs. |
| `recalc_excel.ps1` | Opens each workbook in Excel, recalculates, saves, and prints formula-error counts per sheet. |
| `build_standalone.py` | Builds `JD_Price_Triggers.html`: the same page with the data and d3 v7.9.0 inlined, for SharePoint (no Claude account, no internet needed). Git-ignored because it holds Prod data. |

## Refresh

```
python pull.py prices.duckdb
python analyze.py prices.duckdb data.json
python margin.py prices.duckdb margin.json
python export.py data.json out margin.json
python build_excel.py prices.duckdb excel
powershell -File recalc_excel.ps1 -Folder excel   # Excel computes the formulas and reports any errors
```

Standalone copy for SharePoint (download d3 once from `https://cdnjs.cloudflare.com/ajax/libs/d3/7.9.0/d3.min.js`):

```
python build_standalone.py dashboard_page.html out d3.v7.min.js JD_Price_Triggers.html
```

Keep `prices.duckdb`, `data.json`, `out/` and `JD_Price_Triggers.html` out of Git (Prod data, reproducible). Then ask Claude to re-upload `out/*.json` to the dashboard and point each dataset at the new file. Dataset ids: `headline`, `transitions`, `wait_hist`, `monthly`, `waves`, `wave_heat`, `margin_waves`, `margin_buckets`, `price_index`, `momentum`, `reversals`, `buyahead`.

## Method

- **Trigger A (single jump):** one update that moves JD list price 10% or more.
- **Trigger B (drift from the last trigger, a rolling trigger point):** the price at the last trigger is the anchor. The next trigger is the first update that leaves the price 10% or more from the anchor, in one jump or several. The anchor then resets.
- **Price:** JD list price (`OldListPrice` → `NewListPrice`). Our sell price is list plus the Price Matrix markup for its bucket, so it moves with list. In Aug 2017 the sell price was ~16% above list, then reset.
- **Excluded:** changes before Aug 2017, parts under $1, and 753 changes of 5x or more (unit-of-measure jumps).
- **"Within N months"** only counts triggers watched for at least N months. Parts with no next trigger yet are left out of the up/down split.
- **Groups** are `dim_Parts.DealerGroupCode`. The price index counts only parts that were priced by Aug 2018.
- **Buy-ahead:** uses today's `Current12MoSales` (units) as the demand for every wave. Holding cost = monthly value × yearly rate / 12 × m(m+1)/2. This is rough sizing, not a forecast.

## Findings (2026-10-16)

- **After a 10% increase,** the next trigger was up 88% (A) / 97% (B) of the time. The median wait was ~24 / ~12 months.
- **After a 10% decrease,** the next trigger was up 69% / 80% of the time.
- **JD reprices in waves:** late March, late May/June and late August. The main wave moved from August to June in 2024.
- **2023 had no broad wave.** The 2024 "old" prices equal the 2022 prices 98% of the time, so no price files are missing.
- **Groups follow the same dates** and differ only in size. Index (end of 2017 = 100): all parts 157, COTTON 172.
- **The last change barely predicts the next one.**
- **10% jumps reversed within 30 days** rose to 1–3% of triggers from 2024 on.
- **The JD Change Report gives no advance warning:** a change's effective date is the file date.

## Margin findings (2026-10-19)

- **Margin $** = sell − JD dealer cost. **Margin $ % change** = (new − old) ÷ old, where old > 0.
- **At waves, JD moves cost and list by the same %,** and the matrix passes it through, so margin $ grows at the cost rate and margin % holds.
- **Margin slips** where an increase crosses into a higher (lower-markup) bucket. The biggest cliff is `–9.99` → `–14.99`: typical list +8.0%, our sell +4.2%; margin $ grew +2.3% against +5.0% cost in that bucket. `–4.99` is next.
- **Discount cuts** (cost/list up 1+ point) are rare, except at the Aug 2021 wave (6,467 parts).
- **Yearly margin $ added at today's volume:** ~$1.1M (Aug 2021) and ~$1.3M (May 2022); June waves $0.2–0.6M.
- **JD discount levels vary by part:** cost/list is commonly 0.67, 0.53 or 0.63.

## Summary findings (2026-10-23, data through 2026-10-19)

- **At the Jun 2026 wave, 95.5% of parts kept their margin %** (held = moved less than half a point); 3.9% went down. On parts we sell, the wave added ~$356K/yr in margin $ against ~$104K/yr given up.
- **JD discount cuts are the real leak:** 711 parts we sell are still on a cut made since 2024, ~$233K/yr. The top 25 parts carry $145K; the top 50 carry 76%.
- **Oil/lube is kept separate:** JD's price file shows cost jumping to ~87% of list, then it is reset to ~67% outside the file (TY26675). 25 parts, ~$245K/yr on paper. Confirm the real oil cost before acting.
- **Price Matrix boundaries:** at a +3% wave, 4,994 parts cross, ~$42K/yr at risk.
- **Buy-ahead:** 2 months of the top 500 parts ahead of a +3% wave at 10%/yr holding cost nets ~$69K. Worth it only with advance notice of the wave.

## Open questions

- Does JD notify dealers of a wave ahead of time? If so, buying ahead from that notice needs no model.
- **Next step candidates:**
  - A model that ranks parts by their chance of a 10%+ increase at the next wave, backtested on the 2025 and 2026 waves.
  - Commodity-code cuts.
