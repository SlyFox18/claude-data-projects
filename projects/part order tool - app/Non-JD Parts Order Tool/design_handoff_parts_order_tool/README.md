# Handoff: Parts Order Tool — Visual & UX Redesign

## Overview
This package redesigns the **Non-JD Parts Order Tool** (a Power Apps canvas app backed by a
Fabric Lakehouse + a SharePoint settings list). The goals of the redesign:

1. **Replace back-button-only navigation** with a persistent left nav rail + breadcrumb.
2. **Reduce cognitive load in the data tables** — make "needs attention" (low stock / reorder)
   readable at a glance via color, status pills, and a computed "Need" column.
3. **A friendlier, more professional look** with a single coherent design system.

The app covers: Home, Recommended Reorder, One-Time Order (Setup → Review), Part Information
(Detail / History / Settings), Part Lookup, and App Settings.

## About the Design Files
The files in this bundle are **design references built in HTML/React** — interactive prototypes
that show the intended look, layout, and behavior. **They are not code to ship.** Your task is to
**recreate these designs inside the existing Power Apps canvas app** using native canvas controls
(containers, galleries, labels, buttons, icons) and the Power Apps MCP server — matching the
existing data wiring to the Lakehouse and SharePoint.

Open `Parts Order Tool.html` to explore the live prototype (it has a Tweaks panel to switch
palette/density/font). `Design Spec.html` is a printable reference of every token. The `.jsx`/`.js`
files are the prototype's source if you want to inspect exact style values.

## Fidelity
**High-fidelity.** Colors, typography, spacing, and interactions are final. Recreate the UI faithfully
in Power Apps. Where a pixel value doesn't map cleanly to a canvas control, preserve the *intent*
(hierarchy, grouping, attention-coding) using the established tokens below.

---

## Power Apps implementation strategy (read this first)

**1. Define tokens once.** Put the palette + scale into **`App.Formulas`** (named formulas — they're
constants, so this is cleaner than `Set` in `OnStart`):

```powerfx
// App.Formulas  — Slate Pro palette (swap hex to change theme app-wide)
clrNav        = ColorValue("#14233A");
clrNavActive  = ColorValue("#223A5F");
clrAccent     = ColorValue("#2563EB");
clrAccent2    = ColorValue("#1D4ED8");
clrAccentSoft = ColorValue("#E7F0FE");
clrBg         = ColorValue("#ECEFF3");
clrSurface    = ColorValue("#FFFFFF");
clrBorder     = ColorValue("#E0E5EC");
clrInk        = ColorValue("#16202B");
clrInk2       = ColorValue("#566373");
clrInk3       = ColorValue("#8794A4");
// shared status colors — DO NOT theme these
clrOk = ColorValue("#1A7D43");   clrOkSoft = ColorValue("#E5F3EA");
clrLow = ColorValue("#B5630C");  clrLowSoft = ColorValue("#FBEEDA");
clrCrit = ColorValue("#C13328"); clrCritSoft = ColorValue("#FBE8E6");
```

Reference `clrAccent` etc. everywhere instead of hard-coding hex — re-theming becomes a one-block edit.

**2. Build the shell as components.** Create a reusable **`cmpNavRail`** component (left rail) and put it
on every screen, plus a **`cmpTopBar`** (breadcrumb + context chips). Track location in a global:
`Set(gblNav, "reorder")` and `Navigate(scrReorder)`.

**3. Use modern containers for layout.** Horizontal/Vertical containers give you flex-like behavior
(the prototype is built on flexbox). Rail = fixed 248 wide vertical container; content = flexible.

**4. Tables = Galleries.** Each list is a Gallery with `TemplateSize` 56. Build the row as a horizontal
container of labels. Compute status per row and drive cell colors from it (formulas below).

**5. Status logic** (the heart of the redesign):

```powerfx
// per row (ThisItem): deficit and status
Need:   Max(0, ThisItem.Target - ThisItem.OnHand - ThisItem.OnOrder)
Status: If(ThisItem.OnHand = 0 && ThisItem.Target > 0, "critical",
           ThisItem.Target - ThisItem.OnHand - ThisItem.OnOrder > 0, "low", "ok")
// On Hand label Color:
If(ThisItem.OnHand = 0, clrCrit, Self.Status = "low", clrLow, clrInk)
// Status pill Fill / Color:
Switch(status, "critical", clrCritSoft, "low", clrLowSoft, clrOkSoft)   // Fill
Switch(status, "critical", clrCrit,     "low", clrLow,     clrOk)       // Color
```

---

## Screens / Views

### 1. Home (landing)
- **Purpose:** entry point — choose where to go; surface the day's key action.
- **Layout:** content max-width ~1080, centered. Greeting row (title + "pipeline ran" pill), an
  **attention banner** (left accent border, count of parts below target → links to Reorder), then a
  2×2 grid of nav cards.
- **Components:**
  - *Greeting:* "Good morning, Alex" — 30px/800. Subtitle 15px/`clrInk2`.
  - *Pipeline pill:* `clrOkSoft` fill, `clrOk` text, check icon.
  - *Attention banner:* surface card, 4px left border `clrLow`, 46px low-soft icon tile, bold count,
    sub-text, "Review now ›" in `clrAccent2`. Whole banner navigates to Reorder.
  - *Nav cards (×4):* surface, radius 16, padding 24, min-height 168. Each: 50px accent-soft icon tile,
    title 18/700, one-line description 13.5/`clrInk2`, a footer pill/caption. Hover: lift + shadow.
    Transfers card is disabled with a "Coming soon" pill.

### 2. Recommended Reorder
- **Purpose:** review pipeline suggestions, select parts, build a reorder.
- **Layout:** filter toolbar card → full-width table card (flex-1, scrolls) → pinned selection action bar.
- **Components:**
  - *Filter toolbar:* Branch + Franchise dropdowns, "Reorder needed only" toggle, search box, Export button.
  - *Table (Gallery):* columns — checkbox · **Part** (number 14/700 + desc 12/`clrInk3`) · Bin · Cost ·
    Sales · Demand · **On Hand** (color-coded, status dot) · On Ord. · Target · **Need** (`+N`, bold) ·
    Est. Value · **Status pill**. Right-align all numbers. Sortable headers (active header in `clrAccent2`).
    Row hover = `clrBg`. Row click → Part detail.
  - *Selection action bar:* pinned card, package icon, "N parts selected · Est. $X", Clear (ghost) +
    "Create Order (N)" (primary). Keep the total live off the selected set.

### 3. One-Time Order — Setup (step 1 of 2)
- **Purpose:** configure a custom order from historical demand.
- **Layout:** **Stepper** at top (Set up → Review). Two columns: left = config + date range cards;
  right = sticky "Order summary" card with the Continue button.
- **Components:**
  - *Order details card:* Order Name (text), Branch / Franchise / Dealer Group / Vendor (dropdowns).
  - *Date range card:* scrollable month checklist (selected rows tinted accent-soft) + "Clear" link;
    Quick Ranges (Rolling 12/24/36) and Full Year (2025/2024) as toggle-buttons (selected = accent-soft
    fill, `clrAccent2` text/border).
  - *Order summary:* Order Name, Branch, Franchise, Period + months-selected count, primary
    "Continue to review" (disabled until valid).

### 4. One-Time Order — Review (step 2 of 2)
- **Purpose:** tune parameters, calculate, export/submit.
- **Layout:** Stepper (step 1 shown done/green) → parameter toolbar → results table → pinned footer bar.
- **Components:**
  - *Parameter toolbar:* Loading factor / Min demands / Min sales (number fields), View **Total | Avg/Mo**
    segmented control, Calculate (secondary), Export CSV (green/success button).
  - *Results table (Gallery):* checkbox · Part (+desc) · Franchise · Anticipated Total (or Avg/Mo per
    toggle) · On Hand (red at 0) · **Rec. Qty** (15px/700 `clrAccent2`).
  - *Footer bar:* order name + part count + context, "Back to setup" (ghost) + "Submit order" (primary).

### 5. Part Information (one screen, 3 tabs)
- **Purpose:** everything about a part. Replaces the old top-button screens.
- **Header card:** part number 30/800 + status pill (Stocked/Below target/Out of stock); desc + branch;
  a 3-column meta grid (Franchise, Dealer Group, Vendor, Bin, SLC, Commodity — labels 11/700 uppercase
  `clrInk3`). Inline tab bar: **Detail · History · Settings** (active tab underlined 3px `clrAccent`).
- **Detail tab:** 2-col. Left: *Pricing & Stock* card (a **stock-position gauge** — horizontal bar of
  On Hand vs Target with a reorder-point marker, colored by status — then an 8-cell stat grid: Cost,
  Sell, List, Stock Value, On Hand, On Order, Back Order, Min Qty) and *Reorder Recommendation* card
  (Rec Order Qty in `clrAccent2`, Est Order Value, Suggested Qty, Stocking Target, ROP, Reorder Code).
  Right: *Activity* card (Date Created, Last Requested, 12M Sales/Req with prior + trend pills).
- **History tab:** 6 summary stat cards (Avg Monthly Sales, Avg Demand, Active Months, Last 12M Sales,
  Last 12M Req, Super To/From) → a **12-month sales bar chart** (accent bars, value labels; empty months
  dashed) → a monthly history table (Month, Sales Qty, Demand, inline mini bar).
- **Settings tab:** low-soft warning banner ("Per-part overrides for Branch N. Changes apply to
  tomorrow's run."), a 3-col form (Group Override, Min Override, EOQ; Force Non-Spiking + Masking toggles;
  Pre-Approved Rule dropdown), Reset + Save overrides buttons.

### 6. Part Lookup (search)
- **Purpose:** find any part → open its detail.
- **Layout:** big centered search field (56px) → "N results" caption → results gallery (Part+desc,
  Franchise, Bin, On Hand colored, chevron). Row click → Part detail.

### 7. App Settings
- **Purpose:** the SharePoint-backed settings, surfaced in one place.
- **Components:** *Pipeline* card (daily run time, last-run pill, enabled toggle); *Defaults* card
  (default branch/franchise/loading factor); *Reorder rule defaults* card (global min, default EOQ,
  force non-spiking toggle); *Pre-approved rules* table (Rule, Scope, Active/Off pill); Save settings.

---

## Interactions & Behavior
- **Navigation:** left rail item → `Set(gblNav, key)` + `Navigate(screen)`. Breadcrumb crumbs navigate
  up the chain (replaces all Back buttons). Active rail item: `clrNavActive` fill + 3.5px left accent bar.
- **Tabs (Part Info):** local variable `varPartTab` ("detail"/"history"/"settings"); underline the active.
- **Wizard:** `varOtoStep` 0/1; Continue validates Order Name + ≥1 month before enabling.
- **Selection:** track a collection/Set of selected part numbers; checkbox toggles membership; action-bar
  total = `Sum(Filter(parts, partNo in selected), Cost*Target)`.
- **Sorting:** Reorder table headers set `varSortKey`/`varSortDir`; `SortByColumns`/`Sort` the gallery.
- **Filtering:** Branch + Franchise + "reorder needed only" should filter at the **data source** where
  possible (see Data Notes). Search box filters by part number or description.
- **Hover/disabled:** cards lift on hover; primary buttons darken ~4%; Transfers nav/card show "Soon".

## State Management
- `gblNav` (string) — current top-level section, for rail highlighting.
- `gblBranch`, `gblFranchise` — current context (shown as chips in the top bar).
- `varPartTab` — active tab on Part Information.
- `varOtoStep` + setup fields (order name, branch, franchise, selected months, period).
- `colSelectedReorder` / `colSelectedOto` — selected part numbers per list.
- `varSortKey`, `varSortDir` — Reorder table sort.

## Design Tokens
See **`Design Spec.html`** for the full set rendered with swatches. Summary:
- **Colors:** three palettes (Slate Pro = default) + shared status colors (OK `#1A7D43`/`#E5F3EA`,
  Low `#B5630C`/`#FBEEDA`, Critical `#C13328`/`#FBE8E6`, Info/Accent `#2563EB`/`#E7F0FE`).
- **Font:** Lato (native to Power Apps; fallbacks Open Sans, Segoe UI).
- **Type scale (px):** page 30/800 · section 20/700 · card 15/700 · body 14 · stat 18–26/700 ·
  label 11–12.5/700 uppercase · caption 12.
- **Spacing:** 4 · 8 · 12 · 16 · 20 · 24 · 32. Screen padding 30; card padding 20–22.
- **Radius:** card 14 · button/input 9 · pill 999.
- **Sizing:** row height 56 (46 compact / 66 comfy) · nav rail 248 · top bar 66.

## Assets
- **Logo:** drops into the slot at the top-left of the nav rail. Use your branded logo as an Image control;
  size ~40×40 (mark) or a wider lockup.
- **Icons:** the prototype uses inline stroke SVGs (home, reorder, document, search, transfer, gear,
  chevrons, alert triangle, download, check, bell, package, calculator). In Power Apps use the built-in
  **Icon** controls or import matching 1.5–2px stroke SVGs; tint with `clrInk2` / `clrNavMuted` / status colors.
- No raster imagery is required.

## Screenshots
Visual targets for each screen are in `screenshots/` (Slate Pro palette, Regular density):
- `01-home.png` — landing page with nav rail + attention banner + action cards
- `02-recommended-reorder.png` — attention-coded table + selection action bar
- `03-one-time-order-setup.png` — wizard step 1 (config + date range + summary)
- `04-one-time-order-review.png` — wizard step 2 (params + results table)
- `05-part-detail.png` — part header + tabs + stock gauge + stat grids
- `06-part-history.png` — summary stats + 12-month sales chart + monthly table
- `07-part-settings.png` — per-part overrides form
- `08-part-lookup.png` — search + results
- `09-app-settings.png` — SharePoint-backed settings

To see the other two palettes (Workshop, Field Green) and density options, open
`Parts Order Tool.html` and use the Tweaks panel.

## Files in this bundle
- `Parts Order Tool.html` — the interactive prototype (open this first).
- `Design Spec.html` — printable token + component reference.
- `data.js` — mock data shape (mirrors your real fields: Part, Bin, Cost, Sales, Demands, OnHand,
  OnOrder, Target, etc.) — useful for confirming column mapping.
- `theme.jsx` — exact palette tokens + density scales + the icon set (path data).
- `ui.jsx` — component styles (buttons, pills, fields, cards, stats) with precise values.
- `layout.jsx` — nav rail + top bar + breadcrumb structure.
- `screens-a.jsx` / `screens-b.jsx` / `screens-c.jsx` — per-screen layout & styling.
- `app.jsx` — routing + state model (mirror this in `gblNav` / Navigate).

## Suggested order of work
1. Tokens in `App.Formulas` → 2. `cmpNavRail` + `cmpTopBar` + wire `gblNav`/Navigate (retire Back
buttons) → 3. Recommended Reorder (gallery + status logic) → 4. Part Information (tabs) →
5. One-Time Order wizard → 6. App Settings → 7. Home → 8. Part Lookup. Keep Branch/Franchise filters
server-side throughout.
