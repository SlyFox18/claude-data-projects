/* Screens A: Home landing + Recommended Reorder */
const { Icon, Btn, Pill, Dot, Toggle, Select, TextInput, Card, money } = window;

/* ---------------------------------- HOME ---------------------------------- */
function HomeScreen({ go, data }) {
  const needCount = data.reorder.filter(r => r.status !== "ok").length;
  const cards = [
    { key: "reorder", icon: "reorder", title: "Recommended Reorder",
      desc: "Review pipeline-suggested quantities and build a reorder.",
      foot: <Pill tone="low" icon="alert">{needCount} need attention</Pill> },
    { key: "onetime", icon: "onetime", title: "One-Time Order",
      desc: "Build a custom order from historical demand over any period.",
      foot: <span style={{ fontSize: 12.5, color: "var(--ink-3)", fontWeight: 600 }}>Custom date range</span> },
    { key: "lookup", icon: "lookup", title: "Part Lookup",
      desc: "Search any part for stock, pricing, history and settings.",
      foot: <span style={{ fontSize: 12.5, color: "var(--ink-3)", fontWeight: 600 }}>Detail · History · Settings</span> },
    { key: "transfer", icon: "transfer", title: "Transfers", soon: true,
      desc: "Move stock between branches before ordering new parts.",
      foot: <Pill tone="neutral">Coming soon</Pill> },
  ];
  return (
    <div style={{ maxWidth: 1080, margin: "0 auto" }}>
      <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", marginBottom: 24, flexWrap: "wrap", gap: 16 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 30, fontWeight: 800, letterSpacing: "-.02em", whiteSpace: "nowrap" }}>Good morning, Alex</h1>
          <p style={{ margin: "6px 0 0", fontSize: 15, color: "var(--ink-2)" }}>Here's where things stand for Branch 1 today.</p>
        </div>
        <Pill tone="ok" icon="check" style={{ height: 30, fontSize: 13 }}>Pipeline ran 7:00 AM · Jun 11</Pill>
      </div>

      {/* attention banner */}
      <button onClick={() => go("reorder")} style={{ all: "unset", display: "block", width: "100%", cursor: "pointer", marginBottom: 28 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 18, background: "var(--surface)",
          border: "1px solid var(--border)", borderLeft: "4px solid var(--low)", borderRadius: 14,
          padding: "18px 22px", boxShadow: "0 1px 2px rgba(20,30,45,.04)" }}>
          <span style={{ width: 46, height: 46, borderRadius: 12, background: "var(--low-soft)", color: "var(--low)",
            display: "grid", placeItems: "center", flex: "none" }}><Icon name="alert" size={24} /></span>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{needCount} parts are at or below their stocking target</div>
            <div style={{ fontSize: 13.5, color: "var(--ink-2)", marginTop: 2 }}>Review the recommended reorder and approve quantities for the next pipeline run.</div>
          </div>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "var(--accent-2)", fontWeight: 700, fontSize: 14 }}>
            Review now <Icon name="chevronR" size={17} /></span>
        </div>
      </button>

      <div style={{ fontSize: 12.5, fontWeight: 700, letterSpacing: ".08em", color: "var(--ink-3)", marginBottom: 12 }}>WHAT WOULD YOU LIKE TO DO?</div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 18 }}>
        {cards.map(c => (
          <button key={c.key} disabled={c.soon} onClick={() => !c.soon && go(c.key)} style={{
            all: "unset", boxSizing: "border-box", cursor: c.soon ? "default" : "pointer",
            background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 16,
            padding: 24, display: "flex", flexDirection: "column", gap: 14, minHeight: 168,
            opacity: c.soon ? .62 : 1, transition: "box-shadow .15s, transform .15s, border-color .15s",
            boxShadow: "0 1px 2px rgba(20,30,45,.04)" }}
            onMouseEnter={e => { if (!c.soon) { e.currentTarget.style.boxShadow = "0 10px 26px rgba(20,30,45,.10)"; e.currentTarget.style.transform = "translateY(-2px)"; e.currentTarget.style.borderColor = "var(--border-strong)"; } }}
            onMouseLeave={e => { e.currentTarget.style.boxShadow = "0 1px 2px rgba(20,30,45,.04)"; e.currentTarget.style.transform = "none"; e.currentTarget.style.borderColor = "var(--border)"; }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <span style={{ width: 50, height: 50, borderRadius: 14, background: "var(--accent-soft)", color: "var(--accent-2)",
                display: "grid", placeItems: "center" }}><Icon name={c.icon} size={26} stroke={1.8} /></span>
              {!c.soon && <Icon name="chevronR" size={20} style={{ color: "var(--ink-3)" }} />}
            </div>
            <div style={{ flex: 1 }}>
              <h3 style={{ margin: 0, fontSize: 18, fontWeight: 700 }}>{c.title}</h3>
              <p style={{ margin: "6px 0 0", fontSize: 13.5, color: "var(--ink-2)", lineHeight: 1.5 }}>{c.desc}</p>
            </div>
            <div>{c.foot}</div>
          </button>
        ))}
      </div>
    </div>
  );
}

/* ---------------------------- RECOMMENDED REORDER ------------------------- */
const STATUS_META = {
  critical: { tone: "crit", label: "Out of stock" },
  low:      { tone: "low",  label: "Reorder" },
  ok:       { tone: "ok",   label: "Stocked" },
};

function ReorderScreen({ go, data, ctx, setCtx }) {
  const [needOnly, setNeedOnly] = React.useState(true);
  const [sel, setSel] = React.useState(() => new Set(data.reorder.filter(r => r.status !== "ok").map(r => r.part)));
  const [sort, setSort] = React.useState({ key: "deficit", dir: "desc" });
  const [q, setQ] = React.useState("");

  let rows = data.reorder.filter(r => (!needOnly || r.status !== "ok") &&
    (!q || (r.part + " " + r.desc).toLowerCase().includes(q.toLowerCase())));
  rows = [...rows].sort((a, b) => {
    const d = sort.dir === "asc" ? 1 : -1;
    const va = a[sort.key], vb = b[sort.key];
    return (typeof va === "string" ? va.localeCompare(vb) : va - vb) * d;
  });

  const toggle = (p) => setSel(s => { const n = new Set(s); n.has(p) ? n.delete(p) : n.add(p); return n; });
  const allSel = rows.length > 0 && rows.every(r => sel.has(r.part));
  const toggleAll = () => setSel(s => { const n = new Set(s); allSel ? rows.forEach(r => n.delete(r.part)) : rows.forEach(r => n.add(r.part)); return n; });
  const selRows = data.reorder.filter(r => sel.has(r.part));
  const selValue = selRows.reduce((t, r) => t + r.value, 0);

  const SortTh = ({ k, children, align = "right" }) => (
    <th onClick={() => setSort(s => ({ key: k, dir: s.key === k && s.dir === "desc" ? "asc" : "desc" }))}
      style={{ textAlign: align, cursor: "pointer", userSelect: "none" }}>
      <span style={{ display: "inline-flex", alignItems: "center", gap: 4, color: sort.key === k ? "var(--accent-2)" : "inherit" }}>
        {align === "right" && sort.key === k && <Icon name="chevronD" size={13} style={{ transform: sort.dir === "asc" ? "rotate(180deg)" : "none" }} />}
        {children}
        {align !== "right" && sort.key === k && <Icon name="chevronD" size={13} style={{ transform: sort.dir === "asc" ? "rotate(180deg)" : "none" }} />}
      </span>
    </th>
  );

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 18, height: "100%" }}>
      {/* filter toolbar */}
      <div style={{ display: "flex", alignItems: "center", gap: 16, background: "var(--surface)",
        border: "1px solid var(--border)", borderRadius: 14, padding: "14px 18px", flexWrap: "wrap" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ fontSize: 12.5, fontWeight: 700, color: "var(--ink-3)", letterSpacing: ".03em" }}>BRANCH</span>
          <Select value={ctx.branch} options={data.branches} onChange={v => setCtx({ ...ctx, branch: v })} style={{ width: 92 }} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ fontSize: 12.5, fontWeight: 700, color: "var(--ink-3)", letterSpacing: ".03em" }}>FRANCHISE</span>
          <Select value={ctx.franchise} options={data.franchises} onChange={v => setCtx({ ...ctx, franchise: v })} style={{ width: 92 }} />
        </div>
        <div style={{ width: 1, height: 26, background: "var(--border)" }} />
        <Toggle on={needOnly} onChange={setNeedOnly} label="Reorder needed only" />
        <div style={{ flex: 1 }} />
        <div style={{ position: "relative", width: 220 }}>
          <span style={{ position: "absolute", left: 11, top: "50%", transform: "translateY(-50%)", color: "var(--ink-3)" }}><Icon name="lookup" size={16} /></span>
          <TextInput placeholder="Filter parts…" value={q} onChange={e => setQ(e.target.value)} style={{ paddingLeft: 34 }} />
        </div>
        <Btn variant="secondary" icon="download">Export</Btn>
      </div>

      {/* table */}
      <Card pad={false} style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: 0 }}>
        <div style={{ overflow: "auto", flex: 1 }}>
          <table className="tbl">
            <thead>
              <tr>
                <th style={{ width: 44, textAlign: "center" }}>
                  <input type="checkbox" checked={allSel} onChange={toggleAll} className="cbx" />
                </th>
                <SortTh k="part" align="left">Part</SortTh>
                <th style={{ textAlign: "left", width: 70 }}>Bin</th>
                <SortTh k="cost">Cost</SortTh>
                <SortTh k="sales">Sales</SortTh>
                <SortTh k="demands">Demand</SortTh>
                <SortTh k="oh">On Hand</SortTh>
                <SortTh k="oo">On Ord.</SortTh>
                <SortTh k="target">Target</SortTh>
                <SortTh k="deficit">Need</SortTh>
                <SortTh k="value">Est. Value</SortTh>
                <th style={{ textAlign: "left", width: 116 }}>Status</th>
              </tr>
            </thead>
            <tbody>
              {rows.map(r => {
                const m = STATUS_META[r.status];
                const checked = sel.has(r.part);
                return (
                  <tr key={r.part} className="row" onClick={() => go("lookup/859090")} style={{ cursor: "pointer" }}>
                    <td style={{ textAlign: "center" }} onClick={e => { e.stopPropagation(); toggle(r.part); }}>
                      <input type="checkbox" checked={checked} onChange={() => {}} className="cbx" />
                    </td>
                    <td style={{ textAlign: "left" }}>
                      <div style={{ fontWeight: 700, fontSize: 14 }}>{r.part}</div>
                      <div style={{ fontSize: 12, color: "var(--ink-3)", maxWidth: 150, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r.desc}</div>
                    </td>
                    <td style={{ textAlign: "left", color: "var(--ink-2)" }}>{r.bin || "—"}</td>
                    <td className="num">{money(r.cost)}</td>
                    <td className="num">{r.sales}</td>
                    <td className="num">{r.demands}</td>
                    <td className="num">
                      <span style={{ display: "inline-flex", alignItems: "center", gap: 6, justifyContent: "flex-end",
                        fontWeight: r.status !== "ok" ? 700 : 500,
                        color: r.oh === 0 ? "var(--crit)" : (r.status === "low" ? "var(--low)" : "var(--ink)") }}>
                        {r.status !== "ok" && <Dot tone={r.status === "critical" ? "crit" : "low"} />}{r.oh}
                      </span>
                    </td>
                    <td className="num" style={{ color: r.oo > 0 ? "var(--ink)" : "var(--ink-3)" }}>{r.oo}</td>
                    <td className="num">{r.target}</td>
                    <td className="num" style={{ fontWeight: 700, color: r.deficit > 0 ? "var(--ink)" : "var(--ink-3)" }}>{r.deficit > 0 ? "+" + r.deficit : "—"}</td>
                    <td className="num" style={{ fontWeight: 600 }}>{money(r.value)}</td>
                    <td style={{ textAlign: "left" }}><Pill tone={m.tone}>{m.label}</Pill></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Card>

      {/* sticky selection action bar */}
      <div style={{ display: "flex", alignItems: "center", gap: 16, background: "var(--surface)",
        border: "1px solid var(--border)", borderRadius: 14, padding: "12px 20px",
        boxShadow: "0 6px 20px rgba(20,30,45,.08)" }}>
        <span style={{ width: 40, height: 40, borderRadius: 11, background: "var(--accent-soft)", color: "var(--accent-2)",
          display: "grid", placeItems: "center", flex: "none" }}><Icon name="package" size={21} /></span>
        <div>
          <div style={{ fontSize: 15, fontWeight: 700, whiteSpace: "nowrap" }}>{sel.size} parts selected for reorder</div>
          <div style={{ fontSize: 12.5, color: "var(--ink-2)" }}>Estimated order value <strong style={{ color: "var(--ink)" }}>{money(selValue)}</strong></div>
        </div>
        <div style={{ flex: 1 }} />
        <Btn variant="ghost">Clear</Btn>
        <Btn variant="primary" icon="check" disabled={sel.size === 0}>Create Order ({sel.size})</Btn>
      </div>
    </div>
  );
}

Object.assign(window, { HomeScreen, ReorderScreen, STATUS_META });
