/* Design tokens: 3 theme palettes + density scales, applied as CSS variables.
   Shared semantic colors (ok / low / critical) stay constant across themes so
   "needs attention" always reads the same way. */

const THEMES = {
  slate: {
    label: "Slate Pro",
    blurb: "Clean, calm, modern SaaS",
    vars: {
      "--bg": "#ECEFF3",
      "--surface": "#FFFFFF",
      "--surface-2": "#F4F6F9",
      "--border": "#E0E5EC",
      "--border-strong": "#CBD3DD",
      "--ink": "#16202B",
      "--ink-2": "#566373",
      "--ink-3": "#8794A4",
      "--nav-bg": "#14233A",
      "--nav-grad": "linear-gradient(180deg,#1A2C46 0%,#11203455 100%)",
      "--nav-ink": "#DDE5EF",
      "--nav-ink-muted": "#8295AD",
      "--nav-active-bg": "#223A5F",
      "--nav-active-bar": "#5B9BFF",
      "--accent": "#2563EB",
      "--accent-ink": "#FFFFFF",
      "--accent-soft": "#E7F0FE",
      "--accent-2": "#1D4ED8",
    },
  },
  workshop: {
    label: "Workshop",
    blurb: "Warm, industrial, friendly",
    vars: {
      "--bg": "#F3F0EA",
      "--surface": "#FFFFFF",
      "--surface-2": "#F8F5EF",
      "--border": "#E7E0D5",
      "--border-strong": "#D6CCBC",
      "--ink": "#241F19",
      "--ink-2": "#6B6157",
      "--ink-3": "#9A8E7E",
      "--nav-bg": "#2A2520",
      "--nav-grad": "linear-gradient(180deg,#332C25 0%,#241F1A55 100%)",
      "--nav-ink": "#EEE7DC",
      "--nav-ink-muted": "#AC9F8D",
      "--nav-active-bg": "#3D352C",
      "--nav-active-bar": "#F0A04B",
      "--accent": "#DE7A1C",
      "--accent-ink": "#FFFFFF",
      "--accent-soft": "#FBEEDC",
      "--accent-2": "#C26815",
    },
  },
  forest: {
    label: "Field Green",
    blurb: "Fresh, grounded, agricultural",
    vars: {
      "--bg": "#EBF0EB",
      "--surface": "#FFFFFF",
      "--surface-2": "#F2F6F2",
      "--border": "#DAE4DA",
      "--border-strong": "#C4D2C4",
      "--ink": "#172420",
      "--ink-2": "#516359",
      "--ink-3": "#869685",
      "--nav-bg": "#163A2B",
      "--nav-grad": "linear-gradient(180deg,#1D4634 0%,#163A2B55 100%)",
      "--nav-ink": "#DEEAE0",
      "--nav-ink-muted": "#93AE9C",
      "--nav-active-bg": "#205340",
      "--nav-active-bar": "#54C08A",
      "--accent": "#1E8C5B",
      "--accent-ink": "#FFFFFF",
      "--accent-soft": "#E1F1E8",
      "--accent-2": "#176E48",
    },
  },
};

// Shared, theme-independent semantic colors for status / attention.
const SEMANTIC = {
  "--ok": "#1A7D43",
  "--ok-soft": "#E5F3EA",
  "--low": "#B5630C",
  "--low-soft": "#FBEEDA",
  "--crit": "#C13328",
  "--crit-soft": "#FBE8E6",
  "--info": "#2563EB",
  "--info-soft": "#E7F0FE",
};

const DENSITY = {
  compact: { "--row-h": "46px", "--content-pad": "22px", "--card-pad": "18px", "--table-fs": "13px" },
  regular: { "--row-h": "56px", "--content-pad": "30px", "--card-pad": "22px", "--table-fs": "14px" },
  comfy:   { "--row-h": "66px", "--content-pad": "38px", "--card-pad": "26px", "--table-fs": "15px" },
};

function applyTheme(el, themeKey, density) {
  const t = THEMES[themeKey] || THEMES.slate;
  const all = { ...t.vars, ...SEMANTIC, ...(DENSITY[density] || DENSITY.regular) };
  for (const k in all) el.style.setProperty(k, all[k]);
}

// ---------------------------------------------------------------------------
// Icon set — 1.6px stroke, 22px grid, inherits currentColor.
const ICON_PATHS = {
  home:     '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V20h14V9.5"/><path d="M9.5 20v-6h5v6"/>',
  reorder:  '<path d="M20 7a8 8 0 1 0 .9 6"/><path d="M20 3v4h-4"/>',
  onetime:  '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 3.5h6v3H9z"/><path d="M12 11v6M9 14h6"/>',
  lookup:   '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-3.6-3.6"/>',
  transfer: '<path d="M4 8h13M14 5l3 3-3 3"/><path d="M20 16H7m3-3-3 3 3 3"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M21.5 12h-3M5.5 12h-3M18 6l-2 2M8 16l-2 2M18 18l-2-2M8 8 6 6"/>',
  chevronR: '<path d="m9 5 7 7-7 7"/>',
  chevronD: '<path d="m5 9 7 7 7-7"/>',
  arrowL:   '<path d="M19 12H5m6-6-6 6 6 6"/>',
  download: '<path d="M12 3v12m0 0 4-4m-4 4-4-4"/><path d="M4 19.5h16"/>',
  check:    '<path d="m4 12 5 5L20 6"/>',
  alert:    '<path d="M12 3 2.5 20h19L12 3z"/><path d="M12 10v4M12 17h.01"/>',
  trendUp:  '<path d="M3 17 10 10l4 4 7-7"/><path d="M21 7v5h-5"/>',
  package:  '<path d="M3 7.5 12 3l9 4.5v9L12 21l-9-4.5z"/><path d="M3 7.5 12 12l9-4.5M12 12v9"/>',
  filter:   '<path d="M3 5h18l-7 8v6l-4 2v-8z"/>',
  calendar: '<rect x="3.5" y="5" width="17" height="16" rx="2"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>',
  plus:     '<path d="M12 5v14M5 12h14"/>',
  x:        '<path d="M6 6l12 12M18 6 6 18"/>',
  calc:     '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 11h.01M12 11h.01M16 11h.01M8 15h.01M12 15h.01M16 15v4"/>',
  bell:     '<path d="M6 9a6 6 0 1 1 12 0c0 5 2 6 2 6H4s2-1 2-6z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
  dot:      '<circle cx="12" cy="12" r="3.5"/>',
  user:     '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.5 3-6 7-6s7 2.5 7 6"/>',
};

// Render icons via CSS mask + background-color:currentColor. This keeps icons
// theme-aware (they inherit `color`) AND makes them serialize reliably in
// html-to-image captures / PPTX / PDF exports, where inline <svg> children can
// be dropped intermittently.
const _maskCache = {};
function iconMask(name, stroke) {
  const key = name + ":" + stroke;
  if (_maskCache[key]) return _maskCache[key];
  const svg = "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'"
    + " fill='none' stroke='black' stroke-width='" + stroke + "' stroke-linecap='round'"
    + " stroke-linejoin='round'>" + (ICON_PATHS[name] || "") + "</svg>";
  const uri = "url(\"data:image/svg+xml;utf8," + encodeURIComponent(svg) + "\")";
  _maskCache[key] = uri;
  return uri;
}

function Icon({ name, size = 20, stroke = 1.7, style, ...rest }) {
  const m = iconMask(name, stroke);
  return (
    <span role="img" aria-label={name} style={{
      display: "inline-block", flex: "none", width: size, height: size,
      backgroundColor: "currentColor",
      WebkitMaskImage: m, maskImage: m,
      WebkitMaskRepeat: "no-repeat", maskRepeat: "no-repeat",
      WebkitMaskSize: "contain", maskSize: "contain",
      WebkitMaskPosition: "center", maskPosition: "center",
      ...style,
    }} {...rest} />
  );
}

Object.assign(window, { THEMES, SEMANTIC, DENSITY, applyTheme, Icon });
