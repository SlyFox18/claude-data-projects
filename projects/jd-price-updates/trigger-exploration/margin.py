"""Price-bucket and margin analysis for the JD price dashboard. Reads the DuckDB copy from pull.py; writes margin.json.
Buckets are the Price Matrix list-price ranges (OneDrive 'Power BI - Vis/Data/PRICE MATRIX 7-9-25.csv', franchise D,
the same 39 ranges and markups at every branch). Margin $ = our sell price - JD dealer cost; Ben's formula
Margin $ % change = (new margin $ - old margin $) / old margin $, only where the old margin $ is above zero.
Margin outcome per change compares margin % before and after: down / held / up (0.5-point tolerance).
build_excel.py imports load_frame() from here.
Usage: python margin.py prices.duckdb margin.json"""
import duckdb, sys, json, math
import numpy as np, pandas as pd

START = "2017-08-01"
WAVE_MIN = 40000
PTS_TOL = 0.005          # margin % move smaller than half a point counts as "held"

PM = [(0.01, 0.99, 75), (1, 1.99, 40), (2, 2.99, 33), (3, 3.99, 25), (4, 4.99, 18), (5, 5.99, 16), (6, 6.99, 15), (7, 7.99, 14),
      (8, 8.99, 13), (9, 9.99, 12), (10, 14.99, 10.33), (15, 19.99, 9.83), (20, 24.99, 9.33), (25, 32.99, 8.83), (33, 40.99, 8.33),
      (41, 49.99, 7.83), (50, 74.99, 5.82), (75, 99.99, 5.32), (100, 149.99, 5.26), (150, 199.99, 5.18), (200, 249.99, 5.1),
      (250, 299.99, 5.02), (300, 349.99, 4.94), (350, 399.99, 4.91), (400, 449.99, 4.78), (450, 499.99, 4.7), (500, 599.99, 3.15),
      (600, 699.99, 3.1), (700, 799.99, 3.05), (800, 899.99, 3), (900, 999.99, 2.95), (1000, 1499.99, 1.71), (1500, 1999.99, 1.63),
      (2000, 2499.99, 1.55), (2500, 3499.99, 1.5), (3500, 4499.99, 1.45), (4500, 5499.99, 1.4), (5500, 6499.99, 1.35), (6500, 1e10, 1.3)]
LOS = np.array([lo for lo, _, _ in PM])
# Waves where a large share of the margin change was our own repricing, not JD's (checked 2026-10-23):
# on 2022-08-29 list and cost were unchanged on the biggest movers and our sell price rose from ~91% of list to list (TY parts).
WAVE_NOTES = {"2022-08-29": "Includes our own sell-price correction on some TY parts (sell raised to list); not a JD change."}


def money(v):
    return f"{v:,.0f}" if float(v).is_integer() else f"{v:,.2f}"


LABELS = [("$0.01-0.99" if lo == 0.01 else f"${money(lo)}+" if hi > 1e9 else f"${money(lo)}-{money(hi)}") for lo, hi, _ in PM]


def bucket(price):
    """Index into PM for a list price (cent-rounded); prices below $0.01 go to the first bucket."""
    return np.clip(np.searchsorted(LOS, np.round(price, 2), side="right") - 1, 0, len(PM) - 1)


def load_frame(db_path):
    """Every JD list-price change since START with margin columns. Returns (df, WAVES, GROUPS)."""
    con = duckdb.connect(db_path, read_only=True)
    df = con.sql(f"""
      SELECT f.PartNumber, f.EffectiveDate, f.OldListPrice o, f.NewListPrice n, f.OldCost oc, f.NewCost nc,
             f.OldSellPrice os, f.NewSellPrice ns, f.OldMarginDollars om, f.NewMarginDollars nm, f.NewMarginPct nmp,
             coalesce(p.DealerGroupCode, '(none)') grp, coalesce(p.Current12MoSales, 0) demand,
             p.Description descr, p.CommodityCode cc, coalesce(p.QuantityOnHand, 0) qoh
      FROM Fact_PartPriceChange f LEFT JOIN dim_Parts p USING (PartNumber)
      WHERE f.EffectiveDate >= DATE '{START}' AND f.OldListPrice > 0 AND f.NewListPrice > 0
      ORDER BY f.PartNumber, f.EffectiveDate""").df()
    con.close()
    df["EffectiveDate"] = pd.to_datetime(df.EffectiveDate)
    r = df.n / df.o
    df = df[(r <= 5) & (r >= 0.2)].reset_index(drop=True)          # same unit-of-measure exclusion as analyze.py
    df["list_chg"] = df.n / df.o - 1
    df["cost_chg"] = np.where(df.oc > 0, df.nc / df.oc - 1, np.nan)
    df["sell_chg"] = np.where(df.os > 0, df.ns / df.os - 1, np.nan)
    df["margin_chg"] = np.where(df.om > 0, (df.nm - df.om) / df.om, np.nan)
    df["margin_gap"] = df.margin_chg - df.cost_chg
    df["ob"] = bucket(df.o.to_numpy()); df["nb"] = bucket(df.n.to_numpy())
    df["crossed_up"] = df.nb > df.ob
    df["disc_cut"] = (df.oc > 0) & (df.nc / df.n - df.oc / df.o > 0.01)
    df["margin_fell"] = df.nm < df.om
    df["omp"] = np.where(df.os > 0, (df.os - df.oc) / df.os, np.nan)
    df["nmp2"] = np.where(df.ns > 0, (df.ns - df.nc) / df.ns, np.nan)
    pts = df.nmp2 - df.omp
    df["outcome"] = np.select([pts < -PTS_TOL, pts > PTS_TOL], ["down", "up"], "held")
    # margin $ a year given up vs keeping the old margin % at the new sell price (negative = gained)
    df["lost_year"] = (df.omp * df.ns - (df.ns - df.nc)) * df.demand
    df["sells"] = df.demand > 0
    # Oil / lube: the price file's cost on these swings between ~67% and ~87% of list and something outside the file resets it
    # (checked TY26675, 2026-10-23), so their 'discount cuts' are probably not real margin losses. Flagged, kept separate.
    df["oil"] = df.grp.str.contains("OIL|LUB|GREASE|COOLANT", case=False, regex=True)
    slower = df.sell_chg < df.list_chg - 0.005
    cause = np.select([df.disc_cut & df.oil, df.disc_cut, df.crossed_up & slower, slower],
                      ["Oil/lube cost swing", "JD discount cut", "Moved into a lower-markup bucket", "Sell rose less than list"], "Other")
    df["cause"] = np.where(df.outcome == "down", cause, "")
    top = df.groupby("grp").PartNumber.nunique().sort_values(ascending=False)
    groups = [g for g in top.index if g != "(none)"][:16]
    df["g"] = np.where(df.grp.isin(groups), df.grp, "Other")
    waves = df.groupby("EffectiveDate").size()
    return df, sorted(waves[waves >= WAVE_MIN].index), groups


def med(s):
    s = s.dropna()
    return None if s.empty else round(float(s.median()), 4)


def share(mask):
    return None if len(mask) == 0 else round(float(mask.mean()), 4)


def summary_metrics(df, WAVES, wave_inc=0.03, months=2, hold_rate=0.10, top_n=500):
    """Headline numbers for the dashboard's Summary tab. The same rules as the Excel workbooks (build_excel.py) at their
    default inputs: a +3% next wave for the Price Matrix boundaries; 2 months, 10%/yr holding cost and +3% for buy-ahead."""
    sold = df[df.sells]
    last_w = WAVES[-1]
    w = df[df.EffectiveDate == last_w]; ws = w[w.sells]
    current = df.groupby("PartNumber").EffectiveDate.transform("max") == df.EffectiveDate
    since = (df.EffectiveDate >= "2024-01-01") & current & df.sells & df.disc_cut
    cuts = df[since & ~df.oil].sort_values("lost_year", ascending=False)
    oil = df[since & df.oil]
    # Price Matrix boundaries: current price, parts we sell, crossing at +wave_inc
    last = df[current & df.sells]
    mks = np.array([mk for _, _, mk in PM]) / 100
    b0, b1 = bucket(last.n.to_numpy()), bucket((last.n * (1 + wave_inc)).round(2).to_numpy())
    cross = b1 > b0
    risk = (last.n * (1 + wave_inc)).round(2) * (mks[b0] - mks[b1]) * last.demand
    # Buy-ahead: top_n parts by yearly cost volume
    lp = last[last.nc > 0].assign(vol=lambda x: x.demand * x.nc).sort_values("vol", ascending=False).head(top_n)
    mo_val = lp.demand / 12 * lp.nc
    buy = np.floor(lp.demand / 12 * months + 0.5) * lp.nc   # Excel ROUND, half up
    m = [("last_wave", str(last_w.date())), ("wave_parts", len(w)),
         ("wave_pct_held", (w.outcome == "held").mean()), ("wave_pct_down", (w.outcome == "down").mean()),
         ("wave_pct_up", (w.outcome == "up").mean()), ("wave_sold_down", int((ws.outcome == "down").sum())),
         ("wave_lost", ws[ws.outcome == "down"].lost_year.sum()), ("wave_added", (ws.demand * (ws.nm - ws.om)).sum()),
         ("cuts_parts", len(cuts)), ("cuts_lost", cuts.lost_year.sum()), ("cuts_top25_lost", cuts.head(25).lost_year.sum()),
         ("cuts_top50_share", cuts.head(50).lost_year.sum() / cuts.lost_year.sum()),
         ("oil_parts", len(oil)), ("oil_lost", oil.lost_year.sum()),
         ("bnd_inc", wave_inc), ("bnd_parts", int(cross.sum())), ("bnd_risk", float(risk[cross].sum())),
         ("buy_top_n", top_n), ("buy_months", months), ("buy_cost", float(buy.sum())), ("buy_saving", float(buy.sum() * wave_inc)),
         ("buy_holding", float((mo_val * hold_rate / 12 * months * (months + 1) / 2).sum())),
         ("waves_june", ", ".join(str(x.date()) for x in WAVES if x.year >= 2024))]
    out = []
    for k, v in m:
        out.append({"metric": k, "value": v if isinstance(v, str) else round(float(v), 4)})
    net = [r["value"] for r in out if r["metric"] == "buy_saving"][0] - [r["value"] for r in out if r["metric"] == "buy_holding"][0]
    out.append({"metric": "buy_net", "value": round(net, 2)})
    return out


def main(db_path, out_path):
    df, WAVES, GROUPS = load_frame(db_path)
    END = df.EffectiveDate.max()  # snapshot date
    wv = df[df.EffectiveDate.isin(WAVES)]

    # ---------- heatmap: wave x (group | bucket) ----------
    heat = []
    for dim, key, order in [("Product group", "g", GROUPS + ["Other"]), ("Price bucket", "ob", list(range(len(PM))))]:
        for (d, k), s in wv.groupby(["EffectiveDate", key]):
            heat.append({"dim": dim, "member": LABELS[k] if dim == "Price bucket" else k,
                         "member_sort": int(k) if dim == "Price bucket" else order.index(k),
                         "wave_date": str(d.date()), "parts": int(len(s)),
                         "list_chg": med(s.list_chg), "cost_chg": med(s.cost_chg), "sell_chg": med(s.sell_chg),
                         "margin_chg": med(s.margin_chg), "margin_gap": med(s.margin_gap)})

    # ---------- per wave margin summary ----------
    margin_waves = []
    for d in WAVES:
        s = wv[wv.EffectiveDate == d]
        dm = s[s.sells]
        down = dm[dm.outcome == "down"]
        margin_waves.append({
            "wave_date": str(d.date()), "parts": int(len(s)),
            "cost_chg": med(s.cost_chg), "sell_chg": med(s.sell_chg), "margin_chg": med(s.margin_chg),
            "parts_held": int((s.outcome == "held").sum()), "parts_down": int((s.outcome == "down").sum()),
            "parts_up": int((s.outcome == "up").sum()),
            "pct_held": share(s.outcome == "held"), "pct_down": share(s.outcome == "down"), "pct_up": share(s.outcome == "up"),
            "sold_parts": int(len(dm)), "sold_down": int(len(down)), "sold_pct_down": share(dm.outcome == "down"),
            "sold_up": int((dm.outcome == "up").sum()),
            "yearly_margin_lost_down": round(float(down.lost_year.sum())),
            "discount_cut_lost": round(float(down[down.cause == "JD discount cut"].lost_year.sum())),
            "bucket_lost": round(float(down[down.cause == "Moved into a lower-markup bucket"].lost_year.sum())),
            "oil_lost": round(float(down[down.cause == "Oil/lube cost swing"].lost_year.sum())),
            "pct_margin_lagged": share((s.margin_gap < -0.01)[s.margin_gap.notna()]),
            "pct_margin_fell": share(s.margin_fell),
            "crossed_up": int(s.crossed_up.sum()), "discount_cuts": int(s.disc_cut.sum()),
            "yearly_cost_impact": round(float((dm.demand * (dm.nc - dm.oc)).sum())),
            "yearly_sales_impact": round(float((dm.demand * (dm.ns - dm.os)).sum())),
            "yearly_margin_impact": round(float((dm.demand * (dm.nm - dm.om)).sum())),
            "note": WAVE_NOTES.get(str(d.date()), ""),
        })

    # ---------- per bucket summary (bucket at the time of the change, all changes since Aug 2017) ----------
    last = df.groupby("PartNumber").tail(1)
    last_b = last.assign(b=bucket(last.n.to_numpy()))
    margin_buckets = []
    for i, (lo, hi, mk) in enumerate(PM):
        s = df[df.ob == i]
        up = s[s.list_chg > 0]
        cr = up[up.crossed_up]
        cur = last_b[last_b.b == i]
        margin_buckets.append({
            "bucket": LABELS[i], "bucket_sort": i, "matrix_markup": mk / 100,
            "changes": int(len(s)), "cost_chg": med(s.cost_chg), "margin_chg": med(s.margin_chg),
            "pct_margin_lagged": share((s.margin_gap < -0.01)[s.margin_gap.notna()]),
            "pct_crossed_up": share(up.crossed_up) if len(up) else None,
            "list_chg_crossed": med(cr.list_chg), "sell_chg_crossed": med(cr.sell_chg),
            "parts_now": int(len(cur)), "margin_pct_now": med(cur.nmp),
        })

    # ---------- price index by bucket (bucket from the part's end-2017 price) ----------
    first = df.groupby("PartNumber").EffectiveDate.min()
    old_parts = first[first <= "2018-08-31"].index
    d2 = df[df.PartNumber.isin(old_parts)]
    years = list(range(2017, 2027))
    asof = {y: d2[d2.EffectiveDate <= (pd.Timestamp(f"{y}-12-31") if y < 2026 else END)].groupby("PartNumber").n.last() for y in years}
    base = asof[2017].reindex(old_parts).fillna(d2.groupby("PartNumber").o.first())
    bb = pd.Series(bucket(base.to_numpy()), index=base.index)
    bucket_index = []
    for i in range(len(PM)):
        ps = bb[bb == i].index
        if len(ps) < 50:
            continue
        for y in years:
            cur = asof[y].reindex(ps).fillna(base.reindex(ps))
            bucket_index.append({"dim": "Price bucket", "group": LABELS[i], "member_sort": i, "year": y,
                                 "index": round(float(np.median(cur / base.reindex(ps))) * 100, 1), "parts": int(len(ps))})

    out = {"wave_heat": heat, "margin_waves": margin_waves, "margin_buckets": margin_buckets, "bucket_index": bucket_index,
           "summary": summary_metrics(df, WAVES)}
    json.dump(out, open(out_path, "w"), default=lambda x: None if (isinstance(x, float) and math.isnan(x)) else str(x))
    for k, v in out.items():
        print(k, len(v))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(sys.argv[1], sys.argv[2])
