/* Screens C: Part Lookup (search) + Part detail (Detail / History / Settings tabs) */
const { Icon, Btn, Pill, Dot, Toggle, Select, TextInput, Field, Card, Stat, Segmented, money } = window;

/* ------------------------------ PART LOOKUP ------------------------------- */
function LookupScreen({ go, data }) {
  const [q, setQ] = React.useState("");
  const results = data.searchResults.filter(r =>
    !q || (r.part + " " + r.desc).toLowerCase().includes(q.toLowerCase()));
  return (
    <div style={{ maxWidth: 920, margin: "0 auto" }}>
      <div style={{ position: "relative", marginBottom: 8 }}>
        <span style={{ position: "absolute", left: 18, top: "50%", transform: "translateY(-50%)", color: "var(--ink-3)" }}><Icon name="lookup" size={22} /></span>
        <input autoFocus placeholder="Search by part number or description…" value={q} onChange={e => setQ(e.target.value)}
          style={{ width: "100%", boxSizing: "border-box", height: 56, padding: "0 18px 0 52px", fontSize: 17,
            borderRadius: 14, border: "1px solid var(--border-strong)", background: "var(--surface)",
            color: "var(--ink)", fontFamily: "inherit", outline: "none" }}
          onFocus={e => e.target.style.borderColor = "var(--accent)"}
          onBlur={e => e.target.style.borderColor = "var(--border-strong)"} />
      </div>
      <div style={{ fontSize: 12.5, color: "var(--ink-3)", margin: "10px 4px 14px", fontWeight: 600 }}>
        {results.length} results in Branch {data.part.branch}</div>
      <Card pad={false}>
        <table className="tbl">
          <thead><tr>
            <th style={{ textAlign: "left" }}>Part</th>
            <th style={{ textAlign: "left", width: 90 }}>Franchise</th>
            <th style={{ textAlign: "left", width: 80 }}>Bin</th>
            <th style={{ textAlign: "right", width: 110 }}>On Hand</th>
            <th style={{ width: 40 }}></th>
          </tr></thead>
          <tbody>
            {results.map(r => (
              <tr key={r.part} className="row" style={{ cursor: "pointer" }} onClick={() => go("lookup/" + r.part)}>
                <td style={{ textAlign: "left" }}>
                  <div style={{ fontWeight: 700 }}>{r.part}</div>
                  <div style={{ fontSize: 12, color: "var(--ink-3)" }}>{r.desc}</div>
                </td>
                <td style={{ textAlign: "left", color: "var(--ink-2)" }}>{r.fr}</td>
                <td style={{ textAlign: "left", color: "var(--ink-2)" }}>{r.bin}</td>
                <td className="num">
                  <span style={{ fontWeight: 700, color: r.oh === 0 ? "var(--crit)" : "var(--ink)" }}>{r.oh}</span>
                </td>
                <td style={{ textAlign: "center", color: "var(--ink-3)" }}><Icon name="chevronR" size={17} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}

/* ------------------------------ PART HEADER ------------------------------- */
function PartHeader({ p, tab, setTab }) {
  const meta = [
    ["Franchise", p.franchise], ["Dealer Group", p.dealerGroup], ["Vendor", p.vendor],
    ["Bin", p.bin], ["SLC", p.slc], ["Commodity", p.commodity],
  ];
  const status = p.onHand === 0 ? { tone: "crit", label: "Out of stock" }
    : p.onHand < p.stockingTarget ? { tone: "low", label: "Below target" }
    : { tone: "ok", label: "Stocked" };
  const tabs = [["detail", "Detail"], ["history", "History"], ["settings", "Settings"]];
  return (
    <Card pad={false} style={{ marginBottom: 18 }}>
      <div style={{ padding: "20px var(--card-pad) 0" }}>
        <div style={{ display: "flex", alignItems: "flex-start", gap: 16, flexWrap: "wrap" }}>
          <div style={{ flex: 1, minWidth: 260 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <h1 style={{ margin: 0, fontSize: 30, fontWeight: 800, letterSpacing: "-.01em", fontVariantNumeric: "tabular-nums" }}>{p.part}</h1>
              <Pill tone={status.tone} icon={status.tone === "ok" ? "check" : "alert"} style={{ height: 26 }}>{status.label}</Pill>
            </div>
            <div style={{ fontSize: 16, color: "var(--ink-2)", fontWeight: 600, marginTop: 4 }}>{p.desc} · Branch {p.branch}</div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, auto)", gap: "10px 28px" }}>
            {meta.map(([k, v]) => (
              <div key={k}>
                <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: ".04em", color: "var(--ink-3)", whiteSpace: "nowrap" }}>{k.toUpperCase()}</div>
                <div style={{ fontSize: 14, fontWeight: 600, marginTop: 1 }}>{v}</div>
              </div>
            ))}
          </div>
        </div>
        <div style={{ display: "flex", gap: 4, marginTop: 18 }}>
          {tabs.map(([k, l]) => (
            <button key={k} onClick={() => setTab(k)} style={{
              height: 42, padding: "0 18px", border: "none", background: "none", cursor: "pointer",
              fontFamily: "inherit", fontSize: 14.5, fontWeight: 700, position: "relative",
              color: tab === k ? "var(--ink)" : "var(--ink-3)" }}>
              {l}
              {tab === k && <span style={{ position: "absolute", left: 10, right: 10, bottom: 0, height: 3,
                borderRadius: 3, background: "var(--accent)" }} />}
            </button>
          ))}
        </div>
      </div>
    </Card>
  );
}

/* stock gauge: on hand vs target with ROP marker */
function StockGauge({ p }) {
  const max = Math.max(p.stockingTarget, p.onHand + p.onOrder, 1) * 1.15;
  const pct = (v) => Math.min(100, (v / max) * 100);
  const tone = p.onHand === 0 ? "crit" : p.onHand < p.stockingTarget ? "low" : "ok";
  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 10 }}>
        <span style={{ fontSize: 13, fontWeight: 700, color: "var(--ink-2)", whiteSpace: "nowrap" }}>Stock position</span>
        <span style={{ fontSize: 13, color: "var(--ink-3)", whiteSpace: "nowrap" }}><strong style={{ color: "var(--ink)", fontSize: 15 }}>{p.onHand}</strong> on hand of {p.stockingTarget} target</span>
      </div>
      <div style={{ position: "relative", height: 14, borderRadius: 8, background: "var(--surface-2)", border: "1px solid var(--border)" }}>
        <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: pct(p.onHand) + "%",
          borderRadius: 8, background: `var(--${tone})` }} />
        {p.rop > 0 && (
          <div style={{ position: "absolute", top: -4, bottom: -4, left: pct(p.rop) + "%", width: 2,
            background: "var(--ink-2)" }} title="Reorder point" />
        )}
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8, fontSize: 11.5, color: "var(--ink-3)", fontWeight: 600 }}>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 5 }}><Dot tone={tone} /> On hand {p.onHand}</span>
        <span>Reorder point {p.rop}</span>
        <span>Target {p.stockingTarget}</span>
      </div>
    </div>
  );
}

function DetailTab({ p }) {
  const Grid = ({ children, cols = 4 }) => <div style={{ display: "grid", gridTemplateColumns: `repeat(${cols},1fr)`, gap: "20px 24px" }}>{children}</div>;
  return (
    <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr", gap: 18, alignItems: "start" }}>
      <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
        <Card title="Pricing & Stock">
          <div style={{ marginBottom: 22 }}><StockGauge p={p} /></div>
          <Grid>
            <Stat label="Cost" value={money(p.cost)} />
            <Stat label="Sell Price" value={money(p.sell)} />
            <Stat label="List Price" value={money(p.list)} />
            <Stat label="Stock Value" value={money(p.stockValue)} />
            <Stat label="On Hand" value={p.onHand} tone={p.onHand === 0 ? "crit" : p.onHand < p.stockingTarget ? "low" : undefined} />
            <Stat label="On Order" value={p.onOrder} />
            <Stat label="Back Order" value={p.backOrder} />
            <Stat label="Min Qty" value={p.minQty} />
          </Grid>
        </Card>
        <Card title="Reorder Recommendation">
          <Grid cols={3}>
            <Stat label="Rec. Order Qty" value={p.recOrderQty} tone="accent" big />
            <Stat label="Est. Order Value" value={money(p.estOrderValue)} big />
            <Stat label="Suggested Qty" value={p.suggestedQty} big />
            <Stat label="Stocking Target" value={p.stockingTarget} />
            <Stat label="ROP" value={p.rop.toFixed(2)} />
            <Stat label="Reorder Code" value={p.reorderCode} />
          </Grid>
        </Card>
      </div>
      <Card title="Activity">
        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          <Stat label="Date Created" value={p.dateCreated} />
          <Stat label="Date Last Requested" value={p.dateLastReq} />
          <div style={{ height: 1, background: "var(--border)" }} />
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 18 }}>
            <Stat label="Current 12M Sales" value={p.cur12Sales} sub={`Prior ${p.prev12Sales}`} />
            <Stat label="Current 12M Req." value={p.cur12Req} sub={`Prior ${p.prev12Req}`} />
          </div>
          <div style={{ display: "flex", gap: 8, marginTop: 4 }}>
            <Pill tone="ok" icon="trendUp">Sales +{Math.round((p.cur12Sales / p.prev12Sales - 1) * 100)}%</Pill>
            <Pill tone="accent" icon="trendUp">Demand +{Math.round((p.cur12Req / p.prev12Req - 1) * 100)}%</Pill>
          </div>
        </div>
      </Card>
    </div>
  );
}

function HistoryTab({ p, history }) {
  const maxS = Math.max(...history.map(h => h.sales), 1);
  const chron = [...history].reverse();
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(6,1fr)", gap: 18 }}>
        <Card><Stat label="Avg Monthly Sales" value={p.avgMonthlySales} big /></Card>
        <Card><Stat label="Avg Monthly Demand" value={p.avgMonthlyDemand} big /></Card>
        <Card><Stat label="Active Months" value={p.activeMonths} big /></Card>
        <Card><Stat label="Last 12M Sales" value={p.cur12Sales} sub={`Prior ${p.prev12Sales}`} tone="ok" /></Card>
        <Card><Stat label="Last 12M Req." value={p.cur12Req} sub={`Prior ${p.prev12Req}`} tone="ok" /></Card>
        <Card><Stat label="Super To / From" value={p.superTo} sub={`From ${p.superFrom}`} /></Card>
      </div>
      <Card title="Sales & demand — trailing 12 months">
        <div style={{ display: "flex", alignItems: "flex-end", gap: 10, height: 150, padding: "0 4px" }}>
          {chron.map(h => (
            <div key={h.m} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 8, height: "100%", justifyContent: "flex-end" }}>
              <span style={{ fontSize: 11, fontWeight: 700, color: "var(--ink-2)", fontVariantNumeric: "tabular-nums" }}>{h.sales || ""}</span>
              <div style={{ width: "100%", maxWidth: 30, height: `${(h.sales / maxS) * 100}%`, minHeight: h.sales ? 4 : 0,
                background: h.sales ? "var(--accent)" : "transparent", borderRadius: "5px 5px 0 0",
                border: h.sales ? "none" : "1px dashed var(--border-strong)" }} title={`${h.sales} sold`} />
              <span style={{ fontSize: 10.5, color: "var(--ink-3)", whiteSpace: "nowrap" }}>{h.m.split(" ")[0]}</span>
            </div>
          ))}
        </div>
      </Card>
      <Card title="Monthly history" pad={false}>
        <table className="tbl">
          <thead><tr>
            <th style={{ textAlign: "left" }}>Month</th>
            <th style={{ textAlign: "right" }}>Sales Qty</th>
            <th style={{ textAlign: "right" }}>Demand</th>
            <th style={{ textAlign: "left", width: "45%" }}>Sales</th>
          </tr></thead>
          <tbody>
            {history.map(h => (
              <tr key={h.m} className="row">
                <td style={{ textAlign: "left", fontWeight: 600 }}>{h.m}</td>
                <td className="num" style={{ fontWeight: h.sales ? 700 : 400, color: h.sales ? "var(--ink)" : "var(--ink-3)" }}>{h.sales}</td>
                <td className="num" style={{ color: h.demand ? "var(--ink)" : "var(--ink-3)" }}>{h.demand}</td>
                <td style={{ textAlign: "left" }}>
                  <div style={{ height: 8, borderRadius: 4, width: `${(h.sales / maxS) * 100}%`, minWidth: h.sales ? 6 : 0,
                    background: "var(--accent)", opacity: .85 }} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}

function SettingsTab({ p }) {
  const [forceNS, setForceNS] = React.useState(false);
  const [mask, setMask] = React.useState(false);
  return (
    <Card>
      <div style={{ display: "flex", alignItems: "center", gap: 10, background: "var(--low-soft)", color: "var(--low)",
        borderRadius: 10, padding: "12px 16px", marginBottom: 24, fontSize: 13.5, fontWeight: 600 }}>
        <Icon name="alert" size={18} /> <span>Per-part overrides for Branch {p.branch}. Changes apply to tomorrow's pipeline run.</span>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: "26px 28px", maxWidth: 760 }}>
        <Field label="Group Override"><TextInput placeholder="—" /></Field>
        <Field label="Min Override"><TextInput placeholder="—" /></Field>
        <Field label="EOQ"><TextInput placeholder="—" /></Field>
        <Field label="Force Non-Spiking"><div style={{ paddingTop: 6 }}><Toggle on={forceNS} onChange={setForceNS} label={forceNS ? "On" : "Off"} /></div></Field>
        <Field label="Masking"><div style={{ paddingTop: 6 }}><Toggle on={mask} onChange={setMask} label={mask ? "On" : "Off"} /></div></Field>
        <Field label="Pre-Approved Rule"><Select value="None" options={["None", "Auto-approve", "Manager review", "Vendor min"]} /></Field>
      </div>
      <div style={{ display: "flex", gap: 10, marginTop: 30, maxWidth: 760, justifyContent: "flex-end" }}>
        <Btn variant="ghost">Reset</Btn>
        <Btn variant="primary" icon="check">Save overrides</Btn>
      </div>
    </Card>
  );
}

function PartScreen({ go, data, route }) {
  const tabFromRoute = route.split("/")[2];
  const [tab, setTab] = React.useState(tabFromRoute || "detail");
  React.useEffect(() => { if (tabFromRoute) setTab(tabFromRoute); }, [tabFromRoute]);
  const p = data.part;
  return (
    <div>
      <PartHeader p={p} tab={tab} setTab={setTab} />
      {tab === "detail" && <DetailTab p={p} />}
      {tab === "history" && <HistoryTab p={p} history={data.history} />}
      {tab === "settings" && <SettingsTab p={p} />}
    </div>
  );
}

Object.assign(window, { LookupScreen, PartScreen });
