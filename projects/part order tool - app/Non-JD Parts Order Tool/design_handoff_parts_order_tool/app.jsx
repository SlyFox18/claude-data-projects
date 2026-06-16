/* App router + Tweaks (theme / density / font) + mount */
const { AppFrame, HomeScreen, ReorderScreen, OneTimeScreen, LookupScreen, PartScreen,
        AppSettingsScreen, applyTheme, Icon, Btn, Pill } = window;

const FONTS = {
  Lato: "'Lato', 'Segoe UI', sans-serif",
  "Open Sans": "'Open Sans', 'Segoe UI', sans-serif",
  "Segoe UI": "'Segoe UI', system-ui, sans-serif",
};

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "slate",
  "density": "regular",
  "font": "Lato"
}/*EDITMODE-END*/;

function TransferScreen() {
  return (
    <div style={{ display: "grid", placeItems: "center", height: "100%" }}>
      <div style={{ textAlign: "center", maxWidth: 420 }}>
        <span style={{ width: 72, height: 72, borderRadius: 20, background: "var(--accent-soft)", color: "var(--accent-2)",
          display: "grid", placeItems: "center", margin: "0 auto 18px" }}><Icon name="transfer" size={36} stroke={1.6} /></span>
        <h2 style={{ margin: 0, fontSize: 24, fontWeight: 800 }}>Transfers are coming soon</h2>
        <p style={{ margin: "10px 0 0", fontSize: 15, color: "var(--ink-2)", lineHeight: 1.6 }}>
          This is where you'll move stock between branches before placing new orders —
          likely the first step in the ordering flow.</p>
        <div style={{ marginTop: 18 }}><Pill tone="neutral">In design</Pill></div>
      </div>
    </div>
  );
}

function trailFor(route, go) {
  const seg = route.split("/");
  const map = {
    home: [{ label: "Home" }],
    reorder: [{ label: "Recommended Reorder" }],
    onetime: seg[1] === "review"
      ? [{ label: "One-Time Order", to: "onetime" }, { label: "Review & calculate" }]
      : [{ label: "One-Time Order" }],
    lookup: seg[1]
      ? [{ label: "Part Lookup", to: "lookup" }, { label: seg[1] }]
      : [{ label: "Part Lookup" }],
    settings: [{ label: "App Settings" }],
    transfer: [{ label: "Transfers" }],
  };
  return map[seg[0]] || [{ label: "Home" }];
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [route, setRoute] = React.useState(() => localStorage.getItem("pot-route") || "home");
  const [ctx, setCtx] = React.useState({ branch: "1", franchise: "MC" });
  const rootRef = React.useRef(null);
  const data = window.APP_DATA;

  const go = (r) => { setRoute(r); localStorage.setItem("pot-route", r);
    const main = rootRef.current && rootRef.current.querySelector("main"); if (main) main.scrollTop = 0; };

  React.useEffect(() => { if (rootRef.current) applyTheme(rootRef.current, t.theme, t.density); }, [t.theme, t.density]);
  React.useEffect(() => { if (rootRef.current) rootRef.current.style.setProperty("--font", FONTS[t.font] || FONTS.Lato); }, [t.font]);

  const seg = route.split("/")[0];
  const showCtx = seg === "reorder" || (seg === "lookup" && route.split("/")[1]);
  const context = showCtx ? [{ label: "BRANCH", value: ctx.branch }, { label: "FRANCHISE", value: ctx.franchise }] : null;

  let screen;
  if (seg === "home") screen = <HomeScreen go={go} data={data} />;
  else if (seg === "reorder") screen = <ReorderScreen go={go} data={data} ctx={ctx} setCtx={setCtx} />;
  else if (seg === "onetime") screen = <OneTimeScreen go={go} data={data} route={route} />;
  else if (seg === "lookup") screen = route.split("/")[1] ? <PartScreen go={go} data={data} route={route} /> : <LookupScreen go={go} data={data} />;
  else if (seg === "settings") screen = <AppSettingsScreen data={data} />;
  else if (seg === "transfer") screen = <TransferScreen />;

  return (
    <div ref={rootRef} style={{ height: "100%", width: "100%", fontFamily: "var(--font)" }}>
      <AppFrame route={route} go={go} trail={trailFor(route, go)} context={context}>
        {screen}
      </AppFrame>

      <TweaksPanel>
        <TweakSection label="Look & feel" />
        <TweakRadio label="Theme" value={t.theme}
          options={[{ value: "slate", label: "Slate" }, { value: "workshop", label: "Workshop" }, { value: "forest", label: "Field" }]}
          onChange={v => setTweak("theme", v)} />
        <div style={{ fontSize: 12, color: "var(--ink-3, #888)", margin: "-2px 2px 10px", lineHeight: 1.4 }}>
          {window.THEMES[t.theme] && window.THEMES[t.theme].blurb}</div>
        <TweakRadio label="Density" value={t.density}
          options={[{ value: "compact", label: "Compact" }, { value: "regular", label: "Regular" }, { value: "comfy", label: "Comfy" }]}
          onChange={v => setTweak("density", v)} />
        <TweakSection label="Typography" />
        <TweakSelect label="Font (Power Apps-native)" value={t.font}
          options={["Lato", "Open Sans", "Segoe UI"]} onChange={v => setTweak("font", v)} />
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
