/* App shell: persistent left nav rail + top bar with breadcrumb.
   This is the core fix for the "back-button-only" navigation problem. */
const { Icon, Avatar, Pill } = window;

const NAV = [
  { key: "home",     label: "Home",                icon: "home" },
  { key: "reorder",  label: "Recommended Reorder", icon: "reorder" },
  { key: "onetime",  label: "One-Time Order",      icon: "onetime" },
  { key: "lookup",   label: "Part Lookup",         icon: "lookup" },
  { key: "transfer", label: "Transfers",           icon: "transfer", soon: true },
];

function Sidebar({ route, go }) {
  const top = route.split("/")[0];
  const item = (n) => {
    const active = top === n.key;
    return (
      <button key={n.key} onClick={() => go(n.key)} style={{
        display: "flex", alignItems: "center", gap: 12, width: "100%", height: 44,
        padding: "0 14px 0 18px", border: "none", cursor: "pointer", textAlign: "left",
        fontFamily: "inherit", fontSize: 14, fontWeight: active ? 700 : 500, borderRadius: 10,
        position: "relative", transition: "background .12s, color .12s",
        background: active ? "var(--nav-active-bg)" : "transparent",
        color: active ? "#fff" : "var(--nav-ink)",
      }}
        onMouseEnter={e => { if (!active) e.currentTarget.style.background = "rgba(255,255,255,.06)"; }}
        onMouseLeave={e => { if (!active) e.currentTarget.style.background = "transparent"; }}>
        {active && <span style={{ position: "absolute", left: 4, top: 11, bottom: 11, width: 3.5,
          borderRadius: 4, background: "var(--nav-active-bar)" }} />}
        <Icon name={n.icon} size={20} stroke={active ? 2 : 1.7}
          style={{ color: active ? "var(--nav-active-bar)" : "var(--nav-ink-muted)" }} />
        <span style={{ flex: 1 }}>{n.label}</span>
        {n.soon && <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: ".06em",
          color: "var(--nav-ink-muted)", border: "1px solid currentColor", borderRadius: 5,
          padding: "1px 5px", opacity: .7 }}>SOON</span>}
      </button>
    );
  };
  return (
    <nav style={{ width: 248, flex: "none", background: "var(--nav-bg)", backgroundImage: "var(--nav-grad)",
      display: "flex", flexDirection: "column", padding: "0 12px", height: "100%", boxSizing: "border-box" }}>
      {/* brand lockup */}
      <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "20px 8px 18px" }}>
        <image-slot id="brand-mark" shape="rounded" radius="10"
          style={{ width: 40, height: 40, flex: "none" }} placeholder="Logo"></image-slot>
        <div style={{ lineHeight: 1.15 }}>
          <div style={{ color: "#fff", fontWeight: 800, fontSize: 15, letterSpacing: ".01em", whiteSpace: "nowrap" }}>Parts Order</div>
          <div style={{ color: "var(--nav-ink-muted)", fontSize: 11.5, fontWeight: 600, letterSpacing: ".04em" }}>NON-JD TOOL</div>
        </div>
      </div>
      <div style={{ height: 1, background: "rgba(255,255,255,.08)", margin: "0 6px 14px" }} />
      <div style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: ".12em", color: "var(--nav-ink-muted)",
        padding: "0 14px 8px" }}>WORKSPACE</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>{NAV.map(item)}</div>
      <div style={{ flex: 1 }} />
      <div style={{ height: 1, background: "rgba(255,255,255,.08)", margin: "0 6px 8px" }} />
      <button onClick={() => go("settings")} style={{
        display: "flex", alignItems: "center", gap: 12, width: "100%", height: 44,
        padding: "0 18px", border: "none", cursor: "pointer", textAlign: "left", borderRadius: 10,
        fontFamily: "inherit", fontSize: 14, fontWeight: top === "settings" ? 700 : 500, marginBottom: 6,
        background: top === "settings" ? "var(--nav-active-bg)" : "transparent",
        color: top === "settings" ? "#fff" : "var(--nav-ink)" }}
        onMouseEnter={e => { if (top !== "settings") e.currentTarget.style.background = "rgba(255,255,255,.06)"; }}
        onMouseLeave={e => { if (top !== "settings") e.currentTarget.style.background = "transparent"; }}>
        <Icon name="settings" size={20} style={{ color: "var(--nav-ink-muted)" }} />
        <span>App Settings</span>
      </button>
      <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 10px 18px" }}>
        <Avatar initials="AM" />
        <div style={{ lineHeight: 1.2, flex: 1, minWidth: 0 }}>
          <div style={{ color: "var(--nav-ink)", fontSize: 13, fontWeight: 600, whiteSpace: "nowrap",
            overflow: "hidden", textOverflow: "ellipsis" }}>Alex Morgan</div>
          <div style={{ color: "var(--nav-ink-muted)", fontSize: 11.5 }}>Parts Manager</div>
        </div>
      </div>
    </nav>
  );
}

function Breadcrumb({ trail, go }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, minWidth: 0 }}>
      {trail.map((c, i) => {
        const last = i === trail.length - 1;
        return (
          <React.Fragment key={i}>
            {i > 0 && <span style={{ color: "var(--ink-3)", opacity: .6 }}><Icon name="chevronR" size={15} /></span>}
            {last
              ? <span style={{ fontSize: 19, fontWeight: 800, color: "var(--ink)", letterSpacing: "-.01em",
                  whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{c.label}</span>
              : <button onClick={() => c.to && go(c.to)} style={{ background: "none", border: "none",
                  cursor: c.to ? "pointer" : "default", fontFamily: "inherit", fontSize: 14, fontWeight: 600,
                  color: "var(--ink-3)", padding: 0, whiteSpace: "nowrap" }}>{c.label}</button>}
          </React.Fragment>
        );
      })}
    </div>
  );
}

function TopBar({ trail, go, context, right }) {
  return (
    <header style={{ height: 66, flex: "none", background: "var(--surface)", borderBottom: "1px solid var(--border)",
      display: "flex", alignItems: "center", gap: 18, padding: "0 var(--content-pad)" }}>
      <Breadcrumb trail={trail} go={go} />
      <div style={{ flex: 1 }} />
      {context && context.map((c, i) => (
        <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", lineHeight: 1.2 }}>
          <span style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: ".06em", color: "var(--ink-3)" }}>{c.label}</span>
          <span style={{ fontSize: 14, fontWeight: 700, color: "var(--ink)" }}>{c.value}</span>
        </div>
      ))}
      {right}
      <div style={{ display: "flex", alignItems: "center", gap: 4, paddingLeft: 4 }}>
        <button style={{ width: 38, height: 38, borderRadius: 10, border: "1px solid var(--border)",
          background: "var(--surface)", color: "var(--ink-2)", cursor: "pointer", display: "grid",
          placeItems: "center", position: "relative" }}>
          <Icon name="bell" size={19} />
          <span style={{ position: "absolute", top: 8, right: 9, width: 7, height: 7, borderRadius: 999,
            background: "var(--crit)", border: "1.5px solid var(--surface)" }} />
        </button>
      </div>
    </header>
  );
}

function AppFrame({ route, go, trail, context, right, children }) {
  return (
    <div style={{ display: "flex", height: "100%", width: "100%", background: "var(--bg)",
      color: "var(--ink)", overflow: "hidden" }}>
      <Sidebar route={route} go={go} />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
        <TopBar trail={trail} go={go} context={context} right={right} />
        <main style={{ flex: 1, overflow: "auto", padding: "var(--content-pad)" }}>{children}</main>
      </div>
    </div>
  );
}

Object.assign(window, { Sidebar, TopBar, AppFrame, Breadcrumb, NAV });
