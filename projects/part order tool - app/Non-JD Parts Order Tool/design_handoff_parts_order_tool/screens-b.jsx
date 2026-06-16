/* Screens B: One-Time Order (Setup -> Review wizard) + App Settings */
const { Icon, Btn, Pill, Dot, Toggle, Select, TextInput, Field, Card, Stat, Segmented, money } = window;

function Stepper({ step, steps }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 0, marginBottom: 18 }}>
      {steps.map((s, i) => {
        const active = i === step, done = i < step;
        return (
          <React.Fragment key={i}>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <span style={{ width: 28, height: 28, borderRadius: 999, display: "grid", placeItems: "center",
                fontSize: 13, fontWeight: 700, flex: "none",
                background: active ? "var(--accent)" : done ? "var(--ok)" : "var(--surface-2)",
                color: active || done ? "#fff" : "var(--ink-3)",
                border: active || done ? "none" : "1px solid var(--border-strong)" }}>
                {done ? <Icon name="check" size={15} stroke={2.4} /> : i + 1}</span>
              <span style={{ fontSize: 14, fontWeight: 700, color: active || done ? "var(--ink)" : "var(--ink-3)" }}>{s}</span>
            </div>
            {i < steps.length - 1 && <div style={{ width: 48, height: 2, background: done ? "var(--ok)" : "var(--border-strong)", margin: "0 16px" }} />}
          </React.Fragment>
        );
      })}
    </div>
  );
}

/* ----------------------------- ONE-TIME ORDER ---------------------------- */
function OneTimeScreen({ go, data, route }) {
  const stepFromRoute = route.split("/")[1] === "review" ? 1 : 0;
  const [step, setStep] = React.useState(stepFromRoute);
  const [orderName, setOrderName] = React.useState("Test");
  const [franchise, setFranchise] = React.useState("MG");
  const [branch, setBranch] = React.useState("11");
  const [months, setMonths] = React.useState(() => new Set(data.months));
  const [period, setPeriod] = React.useState("Rolling 12");
  React.useEffect(() => { setStep(stepFromRoute); }, [stepFromRoute]);

  const toggleMonth = (m) => setMonths(s => { const n = new Set(s); n.has(m) ? n.delete(m) : n.add(m); return n; });

  if (step === 0) return (
    <div>
      <Stepper step={0} steps={["Set up order", "Review & calculate"]} />
      <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 18, alignItems: "start" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          <Card title="Order details">
            <div style={{ display: "grid", gridTemplateColumns: "repeat(2,1fr)", gap: "20px 24px" }}>
              <Field label="Order Name"><TextInput value={orderName} onChange={e => setOrderName(e.target.value)} /></Field>
              <Field label="Branch"><Select value={branch} options={data.branches} onChange={setBranch} /></Field>
              <Field label="Franchise"><Select value={franchise} options={data.franchises} onChange={setFranchise} /></Field>
              <Field label="Dealer Group Code"><Select value="" options={[{ value: "", label: "Find items…" }, "CRUSTBUST", "AGLINE"]} /></Field>
              <Field label="Vendor Code"><Select value="" options={[{ value: "", label: "Find items…" }, "1010", "2040"]} /></Field>
            </div>
          </Card>
          <Card title="Date range" subtitle="Pick individual months, or use a rolling window / full year.">
            <div style={{ display: "flex", gap: 24 }}>
              <div style={{ flex: "0 0 240px" }}>
                <div style={{ fontSize: 12.5, fontWeight: 700, color: "var(--ink-3)", marginBottom: 8, letterSpacing: ".03em" }}>MONTHS</div>
                <div style={{ maxHeight: 230, overflow: "auto", border: "1px solid var(--border)", borderRadius: 10 }}>
                  {data.months.map(m => {
                    const on = months.has(m);
                    return (
                      <label key={m} style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 14px",
                        borderBottom: "1px solid var(--border)", cursor: "pointer",
                        background: on ? "var(--accent-soft)" : "transparent" }}>
                        <input type="checkbox" className="cbx" checked={on} onChange={() => toggleMonth(m)} />
                        <span style={{ fontSize: 14, fontWeight: on ? 700 : 500, color: on ? "var(--accent-2)" : "var(--ink)" }}>{m}</span>
                      </label>
                    );
                  })}
                </div>
                <button onClick={() => setMonths(new Set())} style={{ marginTop: 10, background: "none", border: "none",
                  color: "var(--ink-3)", fontSize: 12.5, fontWeight: 600, cursor: "pointer", fontFamily: "inherit", padding: 0 }}>Clear selected months</button>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 12.5, fontWeight: 700, color: "var(--ink-3)", marginBottom: 10, letterSpacing: ".03em" }}>QUICK RANGES</div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 10, marginBottom: 18 }}>
                  {["Rolling 12", "Rolling 24", "Rolling 36"].map(r => (
                    <button key={r} onClick={() => { setPeriod(r); setMonths(new Set(data.months)); }} style={{
                      height: 38, padding: "0 18px", borderRadius: 9, cursor: "pointer", fontFamily: "inherit",
                      fontSize: 14, fontWeight: 700, border: "1px solid",
                      borderColor: period === r ? "var(--accent)" : "var(--border-strong)",
                      background: period === r ? "var(--accent-soft)" : "var(--surface)",
                      color: period === r ? "var(--accent-2)" : "var(--ink-2)" }}>{r}</button>
                  ))}
                </div>
                <div style={{ fontSize: 12.5, fontWeight: 700, color: "var(--ink-3)", marginBottom: 10, letterSpacing: ".03em" }}>FULL YEAR</div>
                <div style={{ display: "flex", gap: 10 }}>
                  {["2025", "2024"].map(y => (
                    <button key={y} onClick={() => setPeriod(y)} style={{
                      height: 38, padding: "0 20px", borderRadius: 9, cursor: "pointer", fontFamily: "inherit",
                      fontSize: 14, fontWeight: 700, border: "1px solid",
                      borderColor: period === y ? "var(--accent)" : "var(--border-strong)",
                      background: period === y ? "var(--accent-soft)" : "var(--surface)",
                      color: period === y ? "var(--accent-2)" : "var(--ink-2)" }}>{y}</button>
                  ))}
                </div>
              </div>
            </div>
          </Card>
        </div>

        <Card title="Order summary" style={{ position: "sticky", top: 0 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <Stat label="Order Name" value={orderName || "—"} />
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
              <Stat label="Branch" value={branch} />
              <Stat label="Franchise" value={franchise} />
            </div>
            <Stat label="Period" value={period} sub={`${months.size} months selected`} />
            <div style={{ height: 1, background: "var(--border)" }} />
            <Btn variant="primary" size="lg" iconRight="chevronR" style={{ width: "100%" }}
              disabled={!orderName || months.size === 0} onClick={() => go("onetime/review")}>Continue to review</Btn>
          </div>
        </Card>
      </div>
    </div>
  );

  // ---- Step 2: review/results ----
  return <OneTimeResults go={go} data={data} orderName={orderName} branch={branch} franchise={franchise} months={months.size} />;
}

function OneTimeResults({ go, data, orderName, branch, franchise, months }) {
  const [view, setView] = React.useState("total");
  const [sel, setSel] = React.useState(() => new Set(data.oneTime.map(r => r.part)));
  const toggle = (p) => setSel(s => { const n = new Set(s); n.has(p) ? n.delete(p) : n.add(p); return n; });
  const allSel = data.oneTime.every(r => sel.has(r.part));
  const toggleAll = () => setSel(allSel ? new Set() : new Set(data.oneTime.map(r => r.part)));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 18, height: "100%" }}>
      <Stepper step={1} steps={["Set up order", "Review & calculate"]} />
      <div style={{ display: "flex", alignItems: "center", gap: 16, background: "var(--surface)",
        border: "1px solid var(--border)", borderRadius: 14, padding: "14px 18px", flexWrap: "wrap" }}>
        <Field label="Loading factor" style={{ width: 100 }}><TextInput defaultValue="1" /></Field>
        <Field label="Min demands" style={{ width: 100 }}><TextInput defaultValue="0" /></Field>
        <Field label="Min sales" style={{ width: 100 }}><TextInput defaultValue="0" /></Field>
        <div style={{ display: "flex", flexDirection: "column", gap: 7 }}>
          <span style={{ fontSize: 12.5, fontWeight: 700, color: "var(--ink-2)", letterSpacing: ".03em", textTransform: "uppercase" }}>View</span>
          <Segmented value={view} options={[{ value: "total", label: "Total" }, { value: "avg", label: "Avg / Mo" }]} onChange={setView} />
        </div>
        <div style={{ flex: 1 }} />
        <Btn variant="secondary" icon="calc" style={{ marginTop: 18 }}>Calculate</Btn>
        <Btn variant="success" icon="download" style={{ marginTop: 18 }}>Export CSV</Btn>
      </div>

      <Card pad={false} style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: 0 }}>
        <div style={{ overflow: "auto", flex: 1 }}>
          <table className="tbl">
            <thead><tr>
              <th style={{ width: 44, textAlign: "center" }}><input type="checkbox" className="cbx" checked={allSel} onChange={toggleAll} /></th>
              <th style={{ textAlign: "left" }}>Part</th>
              <th style={{ textAlign: "left", width: 100 }}>Franchise</th>
              <th style={{ textAlign: "right" }}>{view === "total" ? "Anticipated Total" : "Avg / Month"}</th>
              <th style={{ textAlign: "right" }}>On Hand</th>
              <th style={{ textAlign: "right" }}>Rec. Qty</th>
            </tr></thead>
            <tbody>
              {data.oneTime.map(r => {
                const total = view === "total" ? r.total : +(r.total / 12).toFixed(1);
                return (
                  <tr key={r.part} className="row">
                    <td style={{ textAlign: "center" }} onClick={() => toggle(r.part)}><input type="checkbox" className="cbx" checked={sel.has(r.part)} onChange={() => {}} /></td>
                    <td style={{ textAlign: "left" }}>
                      <div style={{ fontWeight: 700 }}>{r.part}</div>
                      <div style={{ fontSize: 12, color: "var(--ink-3)" }}>{r.desc}</div>
                    </td>
                    <td style={{ textAlign: "left", color: "var(--ink-2)" }}>{r.fr}</td>
                    <td className="num">{total.toFixed(1)}</td>
                    <td className="num" style={{ color: r.oh === 0 ? "var(--crit)" : "var(--ink)", fontWeight: r.oh === 0 ? 700 : 400 }}>{r.oh}</td>
                    <td className="num" style={{ fontWeight: 700, color: "var(--accent-2)", fontSize: 15 }}>{r.rec}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Card>

      <div style={{ display: "flex", alignItems: "center", gap: 16, background: "var(--surface)",
        border: "1px solid var(--border)", borderRadius: 14, padding: "12px 20px", boxShadow: "0 6px 20px rgba(20,30,45,.08)" }}>
        <div>
          <div style={{ fontSize: 15, fontWeight: 700 }}>{orderName} · {sel.size} parts</div>
          <div style={{ fontSize: 12.5, color: "var(--ink-2)" }}>Branch {branch} · {franchise} · {months} months</div>
        </div>
        <div style={{ flex: 1 }} />
        <Btn variant="ghost" icon="arrowL" onClick={() => go("onetime")}>Back to setup</Btn>
        <Btn variant="primary" icon="check">Submit order</Btn>
      </div>
    </div>
  );
}

/* ------------------------------ APP SETTINGS ------------------------------ */
function AppSettingsScreen({ data }) {
  const [autoApprove, setAutoApprove] = React.useState(true);
  const rules = [
    { name: "Auto-approve", scope: "Cost under $50", on: true },
    { name: "Manager review", scope: "Order value over $2,500", on: true },
    { name: "Vendor min", scope: "Vendor 1010 · MOQ 4", on: false },
  ];
  return (
    <div style={{ maxWidth: 980, margin: "0 auto", display: "flex", flexDirection: "column", gap: 18 }}>
      <Card title="Pipeline" subtitle="Stored in the SharePoint settings list.">
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 24 }}>
          <Field label="Daily run time"><TextInput defaultValue="7:00 AM" /></Field>
          <Field label="Last run"><div style={{ paddingTop: 8 }}><Pill tone="ok" icon="check">Jun 11 · success</Pill></div></Field>
          <Field label="Status"><div style={{ paddingTop: 8 }}><Toggle on={true} onChange={() => {}} label="Enabled" /></div></Field>
        </div>
      </Card>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 18 }}>
        <Card title="Defaults">
          <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
            <Field label="Default branch"><Select value="1" options={data.branches} /></Field>
            <Field label="Default franchise"><Select value="MC" options={data.franchises} /></Field>
            <Field label="Default loading factor"><TextInput defaultValue="1.0" /></Field>
          </div>
        </Card>
        <Card title="Reorder rule defaults">
          <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
            <Field label="Global minimum on hand"><TextInput defaultValue="0" /></Field>
            <Field label="Default EOQ"><TextInput defaultValue="—" /></Field>
            <Field label="Force non-spiking globally"><div style={{ paddingTop: 6 }}><Toggle on={autoApprove} onChange={setAutoApprove} label={autoApprove ? "On" : "Off"} /></div></Field>
          </div>
        </Card>
      </div>
      <Card title="Pre-approved rules" subtitle="Applied during the nightly pipeline run." pad={false}>
        <table className="tbl">
          <thead><tr>
            <th style={{ textAlign: "left" }}>Rule</th>
            <th style={{ textAlign: "left" }}>Scope</th>
            <th style={{ textAlign: "right", width: 120 }}>Status</th>
          </tr></thead>
          <tbody>
            {rules.map(r => (
              <tr key={r.name} className="row">
                <td style={{ textAlign: "left", fontWeight: 700 }}>{r.name}</td>
                <td style={{ textAlign: "left", color: "var(--ink-2)" }}>{r.scope}</td>
                <td style={{ textAlign: "right" }}><Pill tone={r.on ? "ok" : "neutral"}>{r.on ? "Active" : "Off"}</Pill></td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
      <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
        <Btn variant="ghost">Discard</Btn>
        <Btn variant="primary" icon="check">Save settings</Btn>
      </div>
    </div>
  );
}

Object.assign(window, { OneTimeScreen, AppSettingsScreen, Stepper });
