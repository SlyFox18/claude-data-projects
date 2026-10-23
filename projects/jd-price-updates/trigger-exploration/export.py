"""data.json + margin.json -> flat row-object JSON files for the dashboard datasets (out/*.json).
Usage: python export.py data.json out margin.json"""
import json, os, sys
d = json.load(open(sys.argv[1]))
out = sys.argv[2]; os.makedirs(out, exist_ok=True)
def w(name, rows):
    json.dump(rows, open(os.path.join(out, name + ".json"), "w"), separators=(",", ":"))
    print(name, len(rows), os.path.getsize(os.path.join(out, name + ".json")))
mo = lambda x: None if x is None else round(x / 30.44, 1)

DEFS = {"A": "Single jump", "B": "Drift from anchor"}
tr, hist = [], []
for k in "AB":
    T = d["trig"][k]
    segs = [("All", T["overall"])] + [(f"Group: {g}", s) for g, s in T["by_group"].items()] \
         + [(f"Price band: {b}", s) for b, s in T["by_band"].items()] + [(f"Trigger year: {y}", s) for y, s in T["by_year"].items()]
    for seg, s in segs:
        for fd in ("up", "down"):
            r = s[fd]
            tr.append({"definition": k, "segment": seg, "from_dir": fd, "triggers": r["n"], "with_next": r["with_next"],
                       "next_up": r["next_up"], "next_down": r["next_down"], "pct_next_up": r["pct_next_up"],
                       "pct_next_down": None if r["pct_next_up"] is None else round(1 - r["pct_next_up"], 4),
                       "median_months": mo(r["median_days"]), "p25_months": mo(r["p25_days"]), "p75_months": mo(r["p75_days"]),
                       "within12": r["within12"], "within24": r["within24"], "within36": r["within36"],
                       "median_size": r["median_size"], "median_next_size": r["median_next_size"]})
    for seg, h in T["hist"].items():
        for fd in ("up", "down"):
            for i, b in enumerate(h["bins"][:-1]):
                hist.append({"definition": k, "segment": seg, "from_dir": fd, "months_from": round(b / 30.44, 1),
                             "next_up": h[fd]["up"][i], "next_down": h[fd]["down"][i]})
w("transitions", tr); w("wait_hist", hist)
w("headline", [{"price_changes": d["stats"]["rows"], "parts": d["stats"]["parts"], "pct_increases": d["stats"]["pct_up"],
                "median_change": d["stats"]["median_change"], "first_date": d["stats"]["first"], "last_date": d["stats"]["last"],
                "triggers_A": d["trig"]["A"]["n_triggers"], "triggers_B": d["trig"]["B"]["n_triggers"]}])
w("monthly", [{"month": m["ym"], "parts_changed": m["n"], "median_change": m["med"], "moves_10pct": m["big"]} for m in d["monthly"]])
w("waves", [{"wave_date": x["date"], "parts_changed": x["parts"], "median_change": x["median_pct"], "pct_increases": x["pct_up"],
             "pct_moved_10": x["pct_big"], "onhand_cost_before": x["onhand_old_cost"], "onhand_value_gain": x["onhand_gain"],
             "month_demand_cost": x["mo_val_old"], "month_demand_saving": x["mo_save"]} for x in d["waves"]])
mg = json.load(open(sys.argv[3]))  # margin.json from margin.py
w("wave_heat", mg["wave_heat"])
w("margin_waves", mg["margin_waves"])
w("margin_buckets", mg["margin_buckets"])
w("summary", mg["summary"])
idx = []
names = list(d["index"]["series"])
for g, s in d["index"]["series"].items():
    for y, v in zip(d["index"]["years"], s["vals"]):
        idx.append({"dim": "All" if g == "All" else "Product group", "group": g, "member_sort": names.index(g),
                    "year": y, "index": v, "parts": s["parts"]})
w("price_index", idx + mg["bucket_index"])
w("momentum", [{"previous_change": m["bucket"], "pairs": m["n"], "median_next_change": m["med_next"], "pct_next_up": m["p_next_up"],
                "pct_next_up10": m["p_next_up10"], "pct_next_down10": m["p_next_down10"],
                "median_months_to_next": mo(m["med_days"])} for m in d["momentum"]])
w("reversals", [{"year": r["year"], "triggers": r["triggers"], "reversed_30d": r["reversed30"], "pct_reversed": r["pct"]} for r in d["reversals"]])
ba = []
for x in d["waves"]:
    if x["parts"] < 40000:
        continue
    for m in (1, 2, 3, 4):
        for rate in (0.06, 0.10, 0.15, 0.20):
            save = m * x["mo_save"]
            carry = x["mo_val_old"] * rate / 12 * m * (m + 1) / 2
            ba.append({"wave_date": x["date"], "months_ahead": m, "carry_rate": rate, "bought_ahead": round(m * x["mo_val_old"]),
                       "price_saving": round(save), "carrying_cost": round(carry), "net": round(save - carry)})
w("buyahead", ba)
