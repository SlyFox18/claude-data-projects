/* Shared UI primitives. All theming flows through CSS vars set by applyTheme. */
const { Icon } = window;

function Btn({ variant = "primary", size = "md", icon, iconRight, children, style, ...rest }) {
  const sizes = {
    sm: { h: 32, px: 12, fs: 13, gap: 6 },
    md: { h: 38, px: 16, fs: 14, gap: 8 },
    lg: { h: 44, px: 20, fs: 15, gap: 9 },
  }[size];
  const variants = {
    primary:   { background: "var(--accent)", color: "var(--accent-ink)", border: "1px solid var(--accent)" },
    secondary: { background: "var(--surface)", color: "var(--ink)", border: "1px solid var(--border-strong)" },
    ghost:     { background: "transparent", color: "var(--ink-2)", border: "1px solid transparent" },
    soft:      { background: "var(--accent-soft)", color: "var(--accent-2)", border: "1px solid transparent" },
    success:   { background: "var(--ok)", color: "#fff", border: "1px solid var(--ok)" },
  }[variant];
  return (
    <button {...rest} style={{
      height: sizes.h, padding: `0 ${sizes.px}px`, fontSize: sizes.fs, fontWeight: 600,
      display: "inline-flex", alignItems: "center", justifyContent: "center", gap: sizes.gap,
      borderRadius: 9, cursor: "pointer", fontFamily: "inherit", lineHeight: 1,
      letterSpacing: ".01em", whiteSpace: "nowrap", transition: "filter .12s, background .12s",
      ...variants, ...style,
    }}
      onMouseEnter={e => (e.currentTarget.style.filter = "brightness(.96)")}
      onMouseLeave={e => (e.currentTarget.style.filter = "none")}>
      {icon && <Icon name={icon} size={sizes.fs + 4} stroke={1.9} />}
      {children}
      {iconRight && <Icon name={iconRight} size={sizes.fs + 4} stroke={1.9} />}
    </button>
  );
}

const TONES = {
  ok:      { bg: "var(--ok-soft)",   fg: "var(--ok)" },
  low:     { bg: "var(--low-soft)",  fg: "var(--low)" },
  crit:    { bg: "var(--crit-soft)", fg: "var(--crit)" },
  info:    { bg: "var(--info-soft)", fg: "var(--info)" },
  accent:  { bg: "var(--accent-soft)", fg: "var(--accent-2)" },
  neutral: { bg: "var(--surface-2)", fg: "var(--ink-2)" },
};

function Pill({ tone = "neutral", icon, children, style }) {
  const c = TONES[tone];
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 5, height: 24, padding: "0 10px",
      borderRadius: 999, fontSize: 12, fontWeight: 700, letterSpacing: ".02em",
      background: c.bg, color: c.fg, whiteSpace: "nowrap", ...style,
    }}>
      {icon && <Icon name={icon} size={13} stroke={2.2} />}
      {children}
    </span>
  );
}

function Dot({ tone = "neutral", size = 8 }) {
  return <span style={{ width: size, height: size, borderRadius: 999, background: TONES[tone].fg, flex: "none" }} />;
}

function Toggle({ on, onChange, label }) {
  return (
    <button onClick={() => onChange && onChange(!on)} style={{
      display: "inline-flex", alignItems: "center", gap: 10, background: "none",
      border: "none", cursor: "pointer", padding: 0, fontFamily: "inherit",
    }}>
      <span style={{
        width: 42, height: 24, borderRadius: 999, padding: 3, flex: "none",
        background: on ? "var(--accent)" : "var(--border-strong)", transition: "background .15s",
        display: "flex", justifyContent: on ? "flex-end" : "flex-start",
      }}>
        <span style={{ width: 18, height: 18, borderRadius: 999, background: "#fff",
          boxShadow: "0 1px 2px rgba(0,0,0,.25)" }} />
      </span>
      {label && <span style={{ fontSize: 14, color: "var(--ink-2)", fontWeight: 500 }}>{label}</span>}
    </button>
  );
}

function Field({ label, hint, children, style }) {
  return (
    <label style={{ display: "flex", flexDirection: "column", gap: 7, ...style }}>
      <span style={{ fontSize: 12.5, fontWeight: 700, color: "var(--ink-2)", letterSpacing: ".03em", textTransform: "uppercase" }}>{label}</span>
      {children}
      {hint && <span style={{ fontSize: 12, color: "var(--ink-3)" }}>{hint}</span>}
    </label>
  );
}

const inputStyle = {
  height: 40, padding: "0 12px", borderRadius: 9, border: "1px solid var(--border-strong)",
  background: "var(--surface)", color: "var(--ink)", fontSize: 14, fontFamily: "inherit",
  outline: "none", width: "100%", boxSizing: "border-box",
};

function TextInput({ style, ...rest }) {
  return <input {...rest} style={{ ...inputStyle, ...style }}
    onFocus={e => (e.target.style.borderColor = "var(--accent)")}
    onBlur={e => (e.target.style.borderColor = "var(--border-strong)")} />;
}

function Select({ value, options, onChange, style }) {
  return (
    <div style={{ position: "relative", ...style }}>
      <select value={value} onChange={e => onChange && onChange(e.target.value)} style={{
        ...inputStyle, appearance: "none", paddingRight: 34, cursor: "pointer", fontWeight: 500,
      }}>
        {options.map(o => {
          const v = typeof o === "object" ? o.value : o;
          const l = typeof o === "object" ? o.label : o;
          return <option key={v} value={v}>{l}</option>;
        })}
      </select>
      <span style={{ position: "absolute", right: 11, top: "50%", transform: "translateY(-50%)",
        pointerEvents: "none", color: "var(--ink-3)" }}><Icon name="chevronD" size={16} /></span>
    </div>
  );
}

function Segmented({ value, options, onChange }) {
  return (
    <div style={{ display: "inline-flex", padding: 3, gap: 3, background: "var(--surface-2)",
      border: "1px solid var(--border)", borderRadius: 10 }}>
      {options.map(o => {
        const v = typeof o === "object" ? o.value : o;
        const l = typeof o === "object" ? o.label : o;
        const active = v === value;
        return (
          <button key={v} onClick={() => onChange && onChange(v)} style={{
            height: 30, padding: "0 14px", borderRadius: 7, border: "none", cursor: "pointer",
            fontSize: 13, fontWeight: 600, fontFamily: "inherit",
            background: active ? "var(--surface)" : "transparent",
            color: active ? "var(--ink)" : "var(--ink-2)",
            boxShadow: active ? "0 1px 2px rgba(0,0,0,.12)" : "none",
          }}>{l}</button>
        );
      })}
    </div>
  );
}

function Card({ title, subtitle, actions, children, pad = true, style, bodyStyle }) {
  return (
    <section style={{ background: "var(--surface)", border: "1px solid var(--border)",
      borderRadius: 14, boxShadow: "0 1px 2px rgba(20,30,45,.04)", overflow: "hidden", ...style }}>
      {(title || actions) && (
        <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between",
          padding: "16px 20px", borderBottom: "1px solid var(--border)" }}>
          <div>
            {title && <h3 style={{ margin: 0, fontSize: 15, fontWeight: 700, color: "var(--ink)", whiteSpace: "nowrap" }}>{title}</h3>}
            {subtitle && <p style={{ margin: "3px 0 0", fontSize: 12.5, color: "var(--ink-3)" }}>{subtitle}</p>}
          </div>
          {actions}
        </header>
      )}
      <div style={{ padding: pad ? "var(--card-pad)" : 0, ...bodyStyle }}>{children}</div>
    </section>
  );
}

// key/value stat used in part-info grids
function Stat({ label, value, tone, sub, big }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>
      <span style={{ fontSize: 12.5, color: "var(--ink-3)", fontWeight: 600, letterSpacing: ".01em" }}>{label}</span>
      <span style={{ fontSize: big ? 26 : 18, fontWeight: 700, lineHeight: 1.1,
        color: tone ? TONES[tone].fg : "var(--ink)", fontVariantNumeric: "tabular-nums" }}>{value}</span>
      {sub && <span style={{ fontSize: 12, color: "var(--ink-3)" }}>{sub}</span>}
    </div>
  );
}

function Avatar({ initials = "AM" }) {
  return <span style={{ width: 34, height: 34, borderRadius: 999, background: "var(--accent-soft)",
    color: "var(--accent-2)", display: "flex", alignItems: "center", justifyContent: "center",
    fontSize: 13, fontWeight: 700, flex: "none" }}>{initials}</span>;
}

function money(n) { return "$" + n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }

Object.assign(window, { Btn, Pill, Dot, Toggle, Field, TextInput, Select, Segmented, Card, Stat, Avatar, TONES, money });
