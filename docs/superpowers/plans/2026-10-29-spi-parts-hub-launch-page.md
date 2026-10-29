# SPI Parts Hub launch page Implementation Plan (Plan H, app 0.8.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax.

> **Progress:** plan written 2026-10-29 (Claude, for Brian).
> - **Starting point:** app 0.7.0 (`ff52dc3`, plus nothing since) live on Fedora. Spec approved: `docs/superpowers/specs/2026-10-29-spi-parts-hub-launch-page-design.md` (decisions H1–H7).

**Goal:** the app opens on an "SPI Parts Hub" launch page with a card per area (Non-JD ordering, Cleanup, Part Lookup live; JD ordering and Inventory management "Coming later"), and inside an area the left nav lists only that area's screens, with the logo, "‹ All areas" and an area switcher.

**Architecture:** app-only, no data change. One pure table (`src/ui/areas.ts`) maps every path to an area and lists each area's screens; the nav rail, the breadcrumb trail and the launch page all read it. The launch page takes `/`; today's Home moves to `/non-jd`; every other address stays. The launch counts reuse Home's `attentionFor` and `transferSummary` on the same `useBranchData` load.

**Tech stack:** React 19 + TypeScript + Vite + Tailwind 4, react-router 7 (data router), Vitest + Testing Library, mock source for tests and `npm run dev`.

---

## File map (nonjd-order-app)

| File | Change |
|---|---|
| `src/ui/areas.ts` (new) + `src/ui/__tests__/areas.test.ts` (new) | `AREAS` (id, label, description, icon, home path, screens, status live/coming), `areaFor(pathname)` |
| `src/ui/nav.ts` | `WORKSPACE_NAV` replaced by the areas' screens; `trailFor` starts with the area; Home crumb → `/non-jd` |
| `src/App.tsx` | `index` → `LaunchPage`; `non-jd` → `HomePage` |
| `src/ui/NavRail.tsx` | logo + "SPI Parts Hub", "‹ All areas", area switcher, the current area's screens; none on `/` (the launch page has no rail list) and on `/settings` |
| `public/spi-logo-color.png`, `public/spi-logo-white.png` (new) | copied from `transfer-app/public/SPI Logo.png` and `spi-logo.png` |
| `src/pages/LaunchPage.tsx` (new), `src/pages/launch/launchCounts.ts` (new) + tests | the launch page and its pure counts |
| `src/config.ts`, `.env.example` | `links.partsReports` from `VITE_LINK_PARTS_REPORTS` (blank = link hidden) |
| `index.html`, `src/auth/AuthPage.tsx`, `src/auth/ConfigErrorPage.tsx`, `src/pages/SettingsPage.tsx` | "SPI Parts Hub" |
| `package.json`, `README.md` | 0.8.0, description, Versions row |
| tests that assume Home at `/` or the old rail | updated to `/non-jd` / the new rail |

**data-projects:** this plan's Progress; `for-users/0.8.0-click-through.md` (new); walkthrough/guide (batched, H7 task).

---

## Tasks

### Task H1: The areas table (pure)

**Files:** create `src/ui/areas.ts`, `src/ui/__tests__/areas.test.ts`.

- [ ] **Step 1: tests first** (`areas.test.ts`):

```ts
import { describe, expect, it } from 'vitest';
import { AREAS, areaFor, liveAreas } from '../areas';

describe('areas', () => {
  it('lists five areas in launch order; two are coming later', () => {
    expect(AREAS.map((a) => a.id)).toEqual(['non-jd', 'cleanup', 'lookup', 'jd', 'inventory']);
    expect(AREAS.filter((a) => a.status === 'coming').map((a) => a.id)).toEqual(['jd', 'inventory']);
    expect(liveAreas().map((a) => a.id)).toEqual(['non-jd', 'cleanup', 'lookup']);
  });
  it.each([
    ['/non-jd', 'non-jd'], ['/reorder', 'non-jd'], ['/one-time', 'non-jd'], ['/transfers', 'non-jd'],
    ['/transfers/orders/4', 'non-jd'], ['/orders', 'non-jd'], ['/orders/12', 'non-jd'], ['/rules', 'non-jd'],
    ['/transfer-rules', 'non-jd'], ['/special', 'non-jd'], ['/cleanup', 'cleanup'], ['/lookup', 'lookup'],
    ['/part/1/BS/X-1', 'lookup'],
  ])('%s is in %s', (path, id) => {
    expect(areaFor(path)?.id).toBe(id);
  });
  it('the launch page, App Settings and unknown paths are in no area', () => {
    expect(areaFor('/')).toBeUndefined();
    expect(areaFor('/settings')).toBeUndefined();
    expect(areaFor('/nope')).toBeUndefined();
  });
  it("Non-JD ordering's screens, in rail order, start with its Home", () => {
    expect(AREAS[0].screens.map((s) => s.path)).toEqual(
      ['/non-jd', '/reorder', '/one-time', '/transfers', '/orders', '/rules', '/transfer-rules', '/special']);
    expect(AREAS[0].home).toBe('/non-jd');
  });
});
```

- [ ] **Step 2:** `npx vitest run src/ui/__tests__/areas.test.ts` → FAIL (module missing).
- [ ] **Step 3: implement** `src/ui/areas.ts`:

```ts
// The app's areas (SPI Parts Hub, plan H): the launch page's cards and the nav rail's one-area-at-a-time list. A
// screen belongs to the area whose screens include its first path segment; extra paths (a transfer order, an order,
// a part page) are listed in `alsoUnder`. The launch page (/) and App Settings belong to no area.
import type { IconName } from './Icon';
import type { NavItem } from './nav';

export type AreaId = 'non-jd' | 'cleanup' | 'lookup' | 'jd' | 'inventory';

export interface Area {
  id: AreaId;
  label: string;
  description: string;
  icon: IconName;
  status: 'live' | 'coming';
  /** The area's first screen (the launch card and the switcher open it). */
  home: string;
  /** The rail's list inside the area, in order. */
  screens: NavItem[];
  /** First path segments of pages that sit under this area without a rail item. */
  alsoUnder?: string[];
}

export const AREAS: Area[] = [
  {
    id: 'non-jd', label: 'Non-JD ordering', description: 'Reorder, One-Time orders, transfers, rules.',
    icon: 'reorder', status: 'live', home: '/non-jd',
    screens: [
      { path: '/non-jd', label: 'Home', icon: 'home' },
      { path: '/reorder', label: 'Recommended Reorder', icon: 'reorder' },
      { path: '/one-time', label: 'One-Time Order', icon: 'onetime' },
      { path: '/transfers', label: 'Transfers', icon: 'transfer' },
      { path: '/orders', label: 'Orders', icon: 'orders' },
      { path: '/rules', label: 'Rules', icon: 'rules' },
      { path: '/transfer-rules', label: 'Transfer rules', icon: 'transfer' },
      { path: '/special', label: 'Special statuses', icon: 'flag' },
    ],
  },
  {
    id: 'cleanup', label: 'Cleanup', description: 'Things to fix in Equip.', icon: 'cleanup', status: 'live',
    home: '/cleanup', screens: [{ path: '/cleanup', label: 'Cleanup', icon: 'cleanup' }],
  },
  {
    id: 'lookup', label: 'Part Lookup', description: 'Any part: stock, prices, history, settings.', icon: 'lookup',
    status: 'live', home: '/lookup', screens: [{ path: '/lookup', label: 'Part Lookup', icon: 'lookup' }],
    alsoUnder: ['part'],
  },
  {
    id: 'jd', label: 'JD ordering', description: 'John Deere parts ordering.', icon: 'package', status: 'coming',
    home: '', screens: [],
  },
  {
    id: 'inventory', label: 'Inventory management', description: 'The Corp Parts reports, in the app.',
    icon: 'orders', status: 'coming', home: '', screens: [],
  },
];

export function liveAreas(): Area[] {
  return AREAS.filter((a) => a.status === 'live');
}

/** The area a path belongs to, by its first segment; undefined for /, /settings and unknown paths. */
export function areaFor(pathname: string): Area | undefined {
  const seg = pathname.split('/')[1] ?? '';
  if (!seg) return undefined;
  return AREAS.find((a) => a.screens.some((s) => s.path === `/${seg}`) || (a.alsoUnder ?? []).includes(seg));
}
```

  (Check `IconName` in `src/ui/Icon.tsx` has every icon used; `package` and `orders` exist today. If `nav.ts` importing `areas.ts` creates a cycle with the `NavItem` type, move `NavItem` into `areas.ts` and re-export it from `nav.ts`.)
- [ ] **Step 4:** run the test → PASS; `npm run lint`, `npx tsc -b`.
- [ ] **Step 5:** commit `H1: areas table (SPI Parts Hub)`.

### Task H2: Routes, nav items and breadcrumbs

**Files:** `src/App.tsx`, `src/ui/nav.ts`, tests (`src/__tests__/navTrail.test.ts`, `deepLinks.test.tsx`, any test rendering Home at `/`).

- [ ] **Step 1: tests first.** `navTrail.test.ts`: `trailFor('/non-jd')` → `[{ label: 'Non-JD ordering' }]`; `trailFor('/reorder')` → `[{ label: 'Non-JD ordering', to: '/non-jd' }, { label: 'Recommended Reorder' }]`; `trailFor('/transfers/orders/4')` → `[Non-JD ordering → /non-jd, Transfers → /transfers?tab=orders, Transfer order]`; `trailFor('/part/1/BS/X-1')` → `[Part Lookup → /lookup, X-1]`; `trailFor('/cleanup')` → `[{ label: 'Cleanup' }]`; `trailFor('/')` → `[{ label: 'SPI Parts Hub' }]`; `trailFor('/settings')` → `[{ label: 'SPI Parts Hub', to: '/' }, { label: 'App Settings' }]`; unknown → `[{ label: 'SPI Parts Hub', to: '/' }, { label: 'Page not found' }]`. `deepLinks.test.tsx`: `/` shows the launch page heading "SPI Parts Hub", `/non-jd` shows today's Home greeting.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: implement.**
  - `App.tsx`: `{ index: true, element: <LaunchPage /> }` (a placeholder `LaunchPage` exporting `<h1>SPI Parts Hub</h1>` until H4) and `{ path: 'non-jd', element: <HomePage /> }`.
  - `nav.ts`: `WORKSPACE_NAV` = `AREAS.flatMap((a) => a.screens)` (kept for anything that lists every screen); `navItemFor` looks in that list plus `SETTINGS_NAV`; `trailFor`: the part and transfer-order special cases start with their area crumb; otherwise `const area = areaFor(pathname)`; an area's home path → `[{ label: area.label }]`; a screen with an area whose label equals the area's (Cleanup, Part Lookup) → `[{ label: area.label }]`; else `[{ label: area.label, to: area.home }, { label: item.label }]`; no area → the "SPI Parts Hub" forms above.
  - Every test that renders the app at `/` expecting Home (grep `initialEntries={['/']}`, `pushState({}, '', '/')`, `'Home'` breadcrumb, "Good morning") moves to `/non-jd` or expects the launch page.
- [ ] **Step 4:** `npm test` (full; ~90 s) → all pass; lint; tsc.
- [ ] **Step 5:** commit `H2: launch route at /, Home at /non-jd, area breadcrumbs`.

### Task H3: The nav rail, one area at a time

**Files:** `src/ui/NavRail.tsx`, `public/spi-logo-color.png`, `public/spi-logo-white.png`, `src/ui/__tests__/NavRail.test.tsx` (new or extend `src/__tests__/shell.test.tsx`).

- [ ] **Step 1:** copy the logos: `cp "../transfer-app/public/SPI Logo.png" public/spi-logo-color.png` and `cp ../transfer-app/public/spi-logo.png public/spi-logo-white.png`.
- [ ] **Step 2: tests first** (render the shell at a path, as `shell.test.tsx` does):
  - at `/reorder`: an `img` with alt "South Plains Implement" and text "SPI Parts Hub"; a link "‹ All areas" to `/`; a select labelled "Area" with value `non-jd` and options Non-JD ordering, Cleanup, Part Lookup only; rail links exactly Home (`/non-jd`), Recommended Reorder, One-Time Order, Transfers, Orders, Rules, Transfer rules, Special statuses, then App Settings; "Recommended Reorder" is current.
  - at `/cleanup`: rail links Cleanup and App Settings only; the select shows Cleanup.
  - choosing "Part Lookup" in the select navigates to `/lookup`.
  - at `/settings`: "‹ All areas", the select with no area chosen ("Choose an area…"), no screen links but App Settings.
  - at `/`: the rail shows the logo, name and App Settings only (no "‹ All areas", no select).
  - leaving `/reorder` with ticked parts through "‹ All areas" or the select asks the leave question (LeaveTicksGuard already blocks in-app navigation; one test proves it for the select).
- [ ] **Step 3:** run → FAIL.
- [ ] **Step 4: implement** in `NavRail.tsx`: replace the "Parts Order / NON-JD TOOL" block with `<img src="/spi-logo-white.png" alt="South Plains Implement" className="mx-auto w-[150px]" />` and `<div className="text-center text-[14px] font-black text-white">SPI Parts Hub</div>`; `const area = areaFor(useLocation().pathname)`; unless on `/`, render `<Link to="/">‹ All areas</Link>` and `<select aria-label="Area" value={area?.id ?? ''} onChange={(e) => navigate(AREAS.find((a) => a.id === e.target.value)!.home)}>` with a disabled "Choose an area…" option when `area` is undefined and one option per `liveAreas()`; the list is `area?.screens ?? []` through the existing `RailLink` (set `end` for `/non-jd` so it isn't current on other screens). Keep App Settings and the user block as they are. Style the select like the mockup (dark field, white bold text, `border-white/20`).
- [ ] **Step 5:** run → PASS; full `npm test`; lint; tsc.
- [ ] **Step 6:** commit `H3: nav rail shows one area, with logo, All areas and the area switcher`.

### Task H4: The launch page

**Files:** create `src/pages/launch/launchCounts.ts`, `src/pages/launch/__tests__/launchCounts.test.ts`, `src/pages/LaunchPage.tsx`, `src/pages/__tests__/LaunchPage.test.tsx`; modify `src/config.ts`, `.env.example`.

- [ ] **Step 1: pure counts, tests first.** `launchCounts(computed, franchise, suggestionLines, branch)` returns `{ toOrder: { parts, value } | null, transferParts: number | null, noDemandMinimums: number | null }`:
  - `toOrder` = `attentionFor(computed, franchise)` parts and value (exactly Home's top card);
  - `transferParts` = the count Home's transfers card shows (`transferSummary(suggestionLines, branch)`, the field `branchTransferLine` reads for "N parts could come by transfer");
  - `noDemandMinimums` = `computed.rows.filter((r) => r.gold.minimumNoDemand).length` (every franchise: Cleanup's list, for this branch);
  - `computed` null → all null. Tests on the mock source's branch 1 data: the three numbers equal what HomePage shows for branch 1 (render Home in the test and read its numbers, or compute with the same helpers), and the no-demand count equals Cleanup's rows for branch 1.
- [ ] **Step 2: links config.** `config.ts`: `links: { partsAvailability: 'https://go-parts.spitractor.com', partsReports: env.VITE_LINK_PARTS_REPORTS?.trim() || PARTS_REPORTS_URL }` with `PARTS_REPORTS_URL = 'https://app.powerbi.com/groups/4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7/orgapps/f2e05677-7aed-47fe-8c54-6544bcdde160/overview/7ce62da4-f635-4bd4-b463-e54ed0c2c468?experience=power-bi'` (Brian 2026-10-29: the Parts Reports org app); `.env.example`: `VITE_LINK_PARTS_REPORTS=` with a comment "overrides the built-in Parts Reports org app address". The link always shows (the test for "hidden when blank" becomes "the built-in address unless overridden").
- [ ] **Step 3: page tests first** (`LaunchPage.test.tsx`, mock source, `TestRouter` at `/`):
  - the colour logo (alt "South Plains Implement") and heading "SPI Parts Hub"; the greeting; the Branch select (default branch from App Settings, as Home); "Data as of …";
  - five cards in order with their descriptions; Non-JD ordering, Cleanup and Part Lookup are links to `/non-jd`, `/cleanup`, `/lookup`; JD ordering and Inventory management are not links and show "Coming later";
  - Non-JD ordering shows "N parts to order · $X" and "N could come by transfer" with Home's numbers; Cleanup shows "N minimums with no demand at Branch 1"; a 0 count shows no line; switching the branch changes them;
  - while loading, no counts and no errors; a failed branch read shows the cards without counts;
  - links row: "Parts Availability" → `https://go-parts.spitractor.com` with `target="_blank"` and `rel="noreferrer"`; "Parts reports" only when `VITE_LINK_PARTS_REPORTS` is set (`vi.stubEnv`); "App Settings" → `/settings`.
- [ ] **Step 4: implement** `LaunchPage.tsx` from HomePage's patterns (`useBranchData(requestedBranch, …)`, the greeting helpers `greetingFor` / `firstName`, the Branch select, the Data-as-of pill) with the header `<img src="/spi-logo-color.png" alt="South Plains Implement" className="h-12" />` + `<h1>SPI Parts Hub</h1>`, a 3-column card grid (`grid-cols-1 sm:grid-cols-2 lg:grid-cols-3`), live cards as `<Link>` styled like Home's cards with the amber / purple count lines (`text-low` / `text-xfer` tokens as Home uses), coming cards as a `<div aria-disabled="true">` with dashed border and the `Pill` "Coming later", and the links row. Replace H2's placeholder.
- [ ] **Step 5:** run → PASS; full `npm test`; lint; tsc.
- [ ] **Step 6:** commit `H4: SPI Parts Hub launch page with area cards and counts`.

### Task H5: Names, version, click-through, review, build

- [ ] **Step 1:** "SPI Parts Hub" in `index.html` `<title>`, `AuthPage.tsx` (heading; small line "South Plains Implement"), `ConfigErrorPage.tsx`, the About card's app line, `package.json` `"description"`, README title line and intro ("SPI Parts Hub (repo `nonjd-order-app`)"). `"version": "0.8.0"`; README Versions row "0.8.0: SPI Parts Hub: launch page with an area per tool (Non-JD ordering, Cleanup, Part Lookup; JD ordering and Inventory management coming later), one area at a time in the nav, the logo; Home moved to /non-jd, every other address unchanged".
- [ ] **Step 2:** `src/__tests__/clickThrough080.test.tsx`: `/` → the launch cards → Non-JD ordering → Home at `/non-jd` → Recommended Reorder through the rail → switcher to Cleanup → "‹ All areas" → Part Lookup card. And `data-projects/projects/part order tool - app/for-users/0.8.0-click-through.md` (8–10 steps, same table style as 0.7.0's).
- [ ] **Step 3:** `typescript-reviewer` over everything since `ff52dc3`, focused on: no old address broken, the leave question on area changes, the launch counts equalling Home's. Fix; re-run.
- [ ] **Step 4:** `npm test`, `npm run lint`, `npm run build`, dist check (list and site IDs present, no mock strings, `spi-logo-*.png` in `dist/`, About 0.8.0). Commit and push dev.

### Task H6 (Brian): mock click-through, then Fedora

- [ ] **Step 1 (Brian):** the 0.8.0 click-through in mock mode (`npm run dev`); fixes if any.
- [ ] **Step 2 (Brian):** deploy to Fedora (same steps as 0.7.0); About shows 0.8.0; the launch page shows real counts for Branch 1 equal to `/non-jd`'s Home.
- [ ] **Step 3 (Brian, optional):** send the Parts Reports app address for `VITE_LINK_PARTS_REPORTS` (then a rebuild adds the link).

### Task H7: Documents (batched) and progress

- [ ] **Step 1:** walkthrough "New in 0.8.0" (the launch page, areas, the switcher, All areas, Home moved) and the guide's opening section; regenerate .docx (check for hand edits first).
- [ ] **Step 2:** FUTURE-IDEAS: F2 done in 0.8.0 (the open questions it listed are answered in the spec). This plan's Progress; memory note.

---

## Self-review against the spec

- H1 own launch page + links out: H4 (links row, `config.links`).
- H2 launch page in front, Home becomes Non-JD's Home: H2 (routes), H4.
- H3 one area at a time, All areas, switcher: H3.
- H4 five areas, two coming later: H1 (`AREAS`), H4 (cards).
- H5 cards say what's waiting, for the picked branch: H4 (`launchCounts`, Branch select).
- H6 name and logo: H3 (white), H4 (colour), H5 (names).
- H7 addresses kept: H2 (only `/` and `/non-jd` change), H5 review focus, H5 click-through.
- Defaults: opens on the launch page (H2); everyone sees every area (no filtering anywhere); App Settings at the rail bottom and on the launch page (H3, H4).
- Testing section: H1–H4 tests, H5 click-through and review.
