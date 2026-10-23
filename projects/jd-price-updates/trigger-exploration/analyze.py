"""JD price exploration: trigger transitions (two definitions), wave calendar, group seasonality,
price index, momentum, buy-ahead sizing. Reads the local DuckDB copy of Prod Gold; writes data.json."""
import duckdb, sys, json, math
import numpy as np, pandas as pd
sys.stdout.reconfigure(encoding="utf-8")
con = duckdb.connect(sys.argv[1], read_only=True)
START = "2017-08-01"
TRIG = 0.10

df = con.sql(f"""
  SELECT f.PartNumber, f.EffectiveDate, f.OldListPrice o, f.NewListPrice n, f.OldCost oc, f.NewCost nc,
         coalesce(p.DealerGroupCode, '(none)') grp, p.CommodityCode cc,
         coalesce(p.Current12MoSales, 0) demand, coalesce(p.QuantityOnHand, 0) qoh
  FROM Fact_PartPriceChange f LEFT JOIN dim_Parts p USING (PartNumber)
  WHERE f.EffectiveDate >= DATE '{START}' AND f.OldListPrice > 0 AND f.NewListPrice > 0
  ORDER BY f.PartNumber, f.EffectiveDate""").df()
df["EffectiveDate"] = pd.to_datetime(df["EffectiveDate"])
END = df.EffectiveDate.max()  # snapshot date: follow-up windows and the 2026 index point end here
df["r"] = df["n"] / df["o"]
total_rows = len(df)
uom = (df["r"] > 5) | (df["r"] < 0.2)
sub1 = df["o"] < 1
stats = {"rows_all": int(total_rows), "rows_uom_excluded": int(uom.sum()), "rows_sub1_excluded": int((sub1 & ~uom).sum())}
df = df[~uom & ~sub1].reset_index(drop=True)
stats.update(rows=int(len(df)), parts=int(df.PartNumber.nunique()),
             first=str(df.EffectiveDate.min().date()), last=str(df.EffectiveDate.max().date()),
             pct_up=round(float((df.r > 1).mean()), 4), median_change=round(float(np.median(df.r - 1)), 4))

top_groups = (df.groupby("grp").PartNumber.nunique().sort_values(ascending=False))
GROUPS = [g for g in top_groups.index if g != "(none)"][:16]
df["g"] = np.where(df.grp.isin(GROUPS), df.grp, "Other")

def band(p):
    return pd.cut(p, [0, 10, 50, 250, 1000, 1e12], labels=["$1-10", "$10-50", "$50-250", "$250-1K", "$1K+"], right=False)

# ---------- triggers ----------
part = df.PartNumber.to_numpy(); dates = df.EffectiveDate.to_numpy(); o = df.o.to_numpy(); n = df.n.to_numpy()
grp = df.g.to_numpy()
recA, recB = [], []
i = 0; N = len(df)
while i < N:
    j = i
    while j < N and part[j] == part[i]:
        j += 1
    anchor = o[i]
    for k in range(i, j):
        ch = n[k] / o[k] - 1
        if abs(ch) >= TRIG:
            recA.append((part[k], dates[k], 1 if ch > 0 else -1, ch, o[k], grp[k]))
        drift = n[k] / anchor - 1
        if abs(drift) >= TRIG:
            recB.append((part[k], dates[k], 1 if drift > 0 else -1, drift, anchor, grp[k]))
            anchor = n[k]
    i = j

def trig_frame(rec):
    t = pd.DataFrame(rec, columns=["part", "date", "dir", "chg", "base", "g"])
    t["date"] = pd.to_datetime(t["date"])
    t = t.sort_values(["part", "date"]).reset_index(drop=True)
    same = t.part.shift(-1) == t.part
    t["next_date"] = t.date.shift(-1).where(same)
    t["next_dir"] = t.dir.shift(-1).where(same)
    t["next_chg"] = t.chg.shift(-1).where(same)
    t["days"] = (t.next_date - t.date).dt.days
    t["follow"] = (END - t.date).dt.days
    t["band"] = band(t.base)
    t["year"] = t.date.dt.year
    return t

def summarize(t):
    out = {}
    for d, name in [(1, "up"), (-1, "down")]:
        s = t[t.dir == d]
        nxt = s[s.next_dir.notna()]
        def within(m):
            elig = s[(s.follow >= m * 30.4) | (s.days.notna() & (s.days <= m * 30.4))]
            return None if len(elig) < 30 else round(float((elig.days <= m * 30.4).mean()), 4)
        out[name] = {
            "n": int(len(s)),
            "with_next": int(len(nxt)),
            "next_up": int((nxt.next_dir == 1).sum()), "next_down": int((nxt.next_dir == -1).sum()),
            "pct_next_up": None if len(nxt) == 0 else round(float((nxt.next_dir == 1).mean()), 4),
            "median_days": None if len(nxt) == 0 else float(nxt.days.median()),
            "mean_days": None if len(nxt) == 0 else round(float(nxt.days.mean()), 1),
            "p25_days": None if len(nxt) == 0 else float(nxt.days.quantile(.25)),
            "p75_days": None if len(nxt) == 0 else float(nxt.days.quantile(.75)),
            "within6": within(6), "within12": within(12), "within24": within(24), "within36": within(36),
            "median_size": round(float(s.chg.median()), 4),
            "median_next_size": None if len(nxt) == 0 else round(float(nxt.next_chg.median()), 4),
        }
    return out

def days_hist(t):
    bins = list(range(0, 2913 + 91, 91))
    res = {}
    for d, name in [(1, "up"), (-1, "down")]:
        s = t[(t.dir == d) & t.next_dir.notna()]
        res[name] = {nd: np.histogram(s[s.next_dir == v].days.clip(upper=bins[-1] - 1), bins=bins)[0].tolist()
                     for v, nd in [(1, "up"), (-1, "down")]}
    res["bins"] = bins
    return res

trig = {}
reversals = []
tA = trig_frame(recA)
for y in sorted(tA.year.unique()):
    s = tA[tA.year == y]
    rv = s[(s.next_dir == -s.dir) & (s.days <= 30)]
    reversals.append({"year": int(y), "triggers": int(len(s)), "reversed30": int(len(rv)),
                      "pct": round(float(len(rv) / len(s)), 4) if len(s) else 0})
print("reversals", reversals)
for key, rec in [("A", recA), ("B", recB)]:
    t = trig_frame(rec)
    trig[key] = {
        "overall": summarize(t),
        "by_group": {g: summarize(t[t.g == g]) for g in GROUPS + ["Other"]},
        "by_band": {str(b): summarize(t[t.band == b]) for b in t.band.cat.categories},
        "by_year": {int(y): summarize(t[t.year == y]) for y in sorted(t.year.unique())},
        "hist": {"All": days_hist(t),
                 **{f"Group: {g}": days_hist(t[t.g == g]) for g in GROUPS + ["Other"]},
                 **{f"Price band: {b}": days_hist(t[t.band == b]) for b in t.band.cat.categories},
                 **{f"Trigger year: {y}": days_hist(t[t.year == y]) for y in sorted(t.year.unique())}},
        "n_triggers": int(len(t)), "n_parts": int(t.part.nunique()),
        "parts_one_trigger": int((t.groupby("part").size() == 1).sum()),
    }
    print(key, json.dumps(trig[key]["overall"], indent=1))

# ---------- waves & monthly timeline ----------
df["lr"] = np.log(df.r)
by_date = df.groupby("EffectiveDate").agg(n=("r", "size"), med=("r", "median"), up=("r", lambda x: float((x > 1).mean())),
                                         big=("r", lambda x: float(((x - 1).abs() >= TRIG).mean())))
waves = by_date[by_date.n >= 5000].reset_index()
bw = con.sql("SELECT * FROM branch_wave").df(); bw["EffectiveDate"] = pd.to_datetime(bw.EffectiveDate)
# buy-ahead sizing: one month of current demand bought at old cost before the wave
df["mo_val_old"] = df.demand / 12 * df.oc.clip(lower=0)
df["mo_save"] = df.demand / 12 * (df.nc - df.oc)
wave_rows = []
for _, w in waves.iterrows():
    s = df[df.EffectiveDate == w.EffectiveDate]
    b = bw[bw.EffectiveDate == w.EffectiveDate]
    gmed = s.groupby("g").r.median()
    wave_rows.append({
        "date": str(w.EffectiveDate.date()), "parts": int(w.n), "median_pct": round(float(w.med - 1), 4),
        "pct_up": round(w.up, 4), "pct_big": round(w.big, 4),
        "onhand_old_cost": None if b.empty else round(float(b.onhand_old_cost.iloc[0] or 0)),
        "onhand_gain": None if b.empty else round(float(b.cost_impact.iloc[0] or 0)),
        "mo_val_old": round(float(s.mo_val_old.sum())), "mo_save": round(float(s.mo_save.sum())),
        "by_group": {g: round(float(v - 1), 4) for g, v in gmed.items()},
    })
df["ym"] = df.EffectiveDate.dt.strftime("%Y-%m")
monthly = df.groupby("ym").agg(n=("r", "size"), med=("r", "median"), big=("r", lambda x: int(((x - 1).abs() >= TRIG).sum()))).reset_index()
monthly = [{"ym": r.ym, "n": int(r.n), "med": round(float(r.med - 1), 4), "big": int(r.big)} for r in monthly.itertuples()]

# ---------- group seasonality: avg log increase per part, by month, 2018-2025 full years ----------
full = df[(df.EffectiveDate.dt.year >= 2018) & (df.EffectiveDate.dt.year <= 2025)]
parts_per_g = df.groupby("g").PartNumber.nunique()
season = {}
for g in GROUPS + ["Other"]:
    s = full[full.g == g]
    tot = s.lr.sum()
    bym = s.groupby(s.EffectiveDate.dt.month).lr.sum()
    season[g] = {"share": [round(float(bym.get(m, 0) / tot), 4) if tot else 0 for m in range(1, 13)],
                 "parts": int(parts_per_g.get(g, 0))}

# ---------- price index by group: median price ratio vs end-2017, parts priced by 2018-08 ----------
first = df.groupby("PartNumber").EffectiveDate.min()
old_parts = set(first[first <= "2018-08-31"].index)
d2 = df[df.PartNumber.isin(old_parts)]
years = list(range(2017, 2027))
asof = {}
for y in years:
    cut = pd.Timestamp(f"{y}-12-31") if y < 2026 else END
    last = d2[d2.EffectiveDate <= cut].groupby("PartNumber").n.last()
    asof[y] = last
base = asof[2017].reindex(list(old_parts))
fo = d2.groupby("PartNumber").o.first()
base = base.fillna(fo)
gmap = df.groupby("PartNumber").g.first()
index = {}
for g in ["All"] + GROUPS:
    ps = list(old_parts) if g == "All" else [p for p in old_parts if gmap.get(p) == g]
    row = []
    for y in years:
        cur = asof[y].reindex(ps).fillna(base.reindex(ps))
        row.append(round(float(np.median(cur / base.reindex(ps))) * 100, 1))
    index[g] = {"vals": row, "parts": len(ps)}

# ---------- momentum: previous change size -> next change (consecutive changes, same part) ----------
same = df.PartNumber.shift(-1) == df.PartNumber
m = pd.DataFrame({"prev": df.r - 1, "next": (df.r.shift(-1) - 1).where(same),
                  "days": (df.EffectiveDate.shift(-1) - df.EffectiveDate).dt.days.where(same)}).dropna()
edges = [-1, -0.10, -0.0001, 0.03, 0.06, 0.10, 0.20, 10]
labels = ["Down 10%+", "Down <10%", "Up 0-3%", "Up 3-6%", "Up 6-10%", "Up 10-20%", "Up 20%+"]
m["b"] = pd.cut(m.prev, edges, labels=labels)
momentum = []
for b in labels:
    s = m[m.b == b]
    momentum.append({"bucket": b, "n": int(len(s)), "med_next": round(float(s.next.median()), 4),
                     "p_next_up": round(float((s.next > 0).mean()), 4),
                     "p_next_up10": round(float((s.next >= TRIG).mean()), 4),
                     "p_next_down10": round(float((s.next <= -TRIG).mean()), 4),
                     "med_days": float(s.days.median())})

json.dump({"stats": stats, "groups": GROUPS + ["Other"], "trig": trig, "waves": wave_rows, "monthly": monthly,
           "season": season, "reversals": reversals, "index": {"years": years, "series": index}, "momentum": momentum},
          open(sys.argv[2], "w"), default=lambda x: None if (isinstance(x, float) and math.isnan(x)) else str(x))
print(json.dumps(stats)); print(json.dumps(momentum, indent=0)); print(json.dumps(wave_rows[-6:], indent=0)[:3000])
print({g: index[g]["vals"] for g in ["All"] + GROUPS[:6]})
print({g: season[g] for g in ["COTTON", "TRACTOR", "TURF", "STRIPPER"] if g in season})
