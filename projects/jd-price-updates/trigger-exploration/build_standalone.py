"""Build a single self-contained HTML copy of the dashboard (data + d3 inlined) for SharePoint.
Usage: python build_standalone.py dashboard_page.html out d3.v7.min.js JD_Price_Triggers.html
The page's `dash` calls are served by a small shim over the embedded data."""
import json, os, sys

page, out_dir, d3_path, target = sys.argv[1:5]
DATASETS = ["headline", "transitions", "wait_hist", "monthly", "waves", "wave_heat", "margin_waves", "margin_buckets", "summary", "price_index",
            "momentum", "reversals", "buyahead"]
data = {d: json.load(open(os.path.join(out_dir, d + ".json"))) for d in DATASETS}
body = open(page, encoding="utf-8").read()
d3 = open(d3_path, encoding="utf-8").read()
data_js = json.dumps(data, separators=(",", ":")).replace("</", "<\\/")

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>JD Price Triggers</title>
<style>
:root {
  --color-bg: #f7f8f6; --color-panel: #ffffff; --color-fg: #1d2420; --color-fg-muted: #5d6862;
  --color-border-line: #dde2de; --color-ok: #1f7a43; --color-warn: #a76200; --color-bad: #b3261e;
  --cds-chart-grid: #e9ece9; --cds-chart-axis: #b7beb9; --cds-chart-muted: #c3cac5; --cds-chart-reference: #8d958f;
  --cds-chart-status-critical: #c8463d; --cds-surface-popover: #ffffff; --cds-border: #d3d9d4; --cds-text-secondary: #5d6862;
  --cds-shadow-popover: 0 4px 16px rgba(20, 30, 25, .12);
  --cds-radius: 8px; --cds-pad-xs: 4px; --cds-pad-sm: 8px; --cds-pad-md: 12px; --cds-pad-lg: 18px;
  --cds-gap-xs: 4px; --cds-gap-sm: 8px; --cds-gap-md: 14px; --cds-gap-lg: 24px;
  --cds-font-size-caption: 12px; --cds-font-size-body: 14px; --cds-font-size-heading: 16px; --cds-font-size-title: 30px;
  --cds-font-weight-medium: 600; --cds-dur-slow: .3s;
  --font-anthropic-sans: system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  --font-anthropic-serif: Georgia, "Times New Roman", serif;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: #151917; --color-panel: #1e2421; --color-fg: #e8ece9; --color-fg-muted: #9aa49e;
    --color-border-line: #333b37; --color-ok: #5cc184; --color-warn: #e0a243; --color-bad: #f07a70;
    --cds-chart-grid: #2a312d; --cds-chart-axis: #4a534e; --cds-chart-muted: #4c5550; --cds-chart-reference: #7d8781;
    --cds-chart-status-critical: #e5675d; --cds-surface-popover: #262d29; --cds-border: #3c4540; --cds-text-secondary: #9aa49e;
    --cds-shadow-popover: 0 4px 16px rgba(0, 0, 0, .45);
    color-scheme: dark;
  }
}
html, body { margin: 0; background: var(--color-bg); color: var(--color-fg); font-family: var(--font-anthropic-sans); font-size: 14px; }
.sa-wrap { max-width: 1180px; margin-inline: auto; padding-block: 24px 48px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
.sa-banner { font-size: 12px; color: var(--color-fg-muted); border: 1px dashed var(--color-border-line); border-radius: 8px; padding: 8px 12px; margin-bottom: 20px; }
[hidden] { display: none !important; }
.dash-skeleton { color: transparent; background: var(--cds-chart-grid); border-radius: 4px; }
</style>
<script>__D3__</script>
<script>
window.__JP_DATA__ = __DATA__;
(function () {
  var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)');
  var LIGHT = ['#2f6f9f', '#d07a2a', '#3f8f5b', '#8a5aa8', '#b3456b', '#5b7a8c', '#a08a2c', '#6b6b6b'];
  var DARK = ['#6fa8d6', '#f0a35e', '#71c08c', '#b993d6', '#e07a9c', '#8fb0c2', '#d1b95a', '#a9a9a9'];
  var fns = [];
  window.dash = {
    get colors() { return dark && dark.matches ? DARK : LIGHT; },
    data: function (id) {
      var d = window.__JP_DATA__[id];
      return d ? { status: 'ok', data: d, rows: d, refreshing: false, meta: [] } : { status: 'missing', data: [] };
    },
    onData: function (fn) { fns.push(fn); fn(); },
    setLink: function (name) { try { history.replaceState(null, '', '#' + name); } catch (e) {} },
    params: function () { return {}; }, setParams: function () {}, resetParams: function () {}, refresh: function () {},
  };
  var t;
  var redraw = function () { clearTimeout(t); t = setTimeout(function () { fns.forEach(function (f) { f(); }); }, 120); };
  window.addEventListener('resize', redraw);
  if (dark && dark.addEventListener) dark.addEventListener('change', redraw);
})();
</script>
</head>
<body>
<div class="sa-wrap">
<div class="sa-banner">Draft for discussion. Snapshot of JD price data through __SNAP__; it does not update. Prepared by Brian Fox.</div>
<div id="dash-root">
"""
TAIL = """
</div>
</div>
</body>
</html>
"""
snap = data["headline"][0]["last_date"]
html = HEAD.replace("__SNAP__", snap).replace("__D3__", d3.replace("</script", "<\\/script")).replace("__DATA__", data_js) + body + TAIL
open(target, "w", encoding="utf-8").write(html)
print(target, os.path.getsize(target))
