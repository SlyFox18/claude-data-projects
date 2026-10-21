# Non-JD Parts Order Tool: Web App Implementation Plan (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Progress:** plan written 2026-10-21. Repo created: https://github.com/SlyFox18/nonjd-order-app (private, branches `main` and `dev`), local clone `C:\Users\bfox\Documents\Git-Projects\nonjd-order-app`.

**Goal:** A React web app where Ben, Shannon, Barry and Curt review reorder suggestions, see why each number is what it is, tune the reorder rules live, set per-part minimums and masks, and save and export orders per franchise.

**Architecture:** A static single-page app (Vite + React + TypeScript + Tailwind), signed in with Entra (MSAL). It reads the published files from the SharePoint library and reads and writes the four SharePoint lists through Microsoft Graph with the user's own token. A browser-side **rules engine** recomputes every suggestion from the published history with the **live** rules list, so a rule change shows up on the next load (spec 8.5). The morning Gold figures stay in the files as the checked baseline; the engine is tested to reproduce them exactly.

**Tech Stack:** Vite 7, React 19, TypeScript 5, Tailwind 4, react-router 7, @azure/msal-browser 4 / msal-react 3, Vitest + Testing Library, Microsoft Graph v1.0. Same stack as `parts-lookup-app` (copy its patterns).

**How this plan is written.** Plan A put complete code in every step. This plan is mostly UI, where complete code per step would be thousands of lines; instead each task gives exact files, interfaces, behaviour and the test cases to write first, and the two-stage review enforces them. The engine task (B4) is fully specified because it must match Gold exactly.

**Sources (read before any task):**
- Spec: `docs/superpowers/specs/2026-10-20-non-jd-parts-order-tool-redesign-design.md`, sections 2, 7, 8, **8.5**, 9, and **5.5** (the rules).
- File contract and the explanation text: `projects/part order tool - app/publish/README.md` (authoritative for field names, nullability, the explanation decision order and number display).
- Rules guide: `projects/part order tool - app/REORDER-RULES.md`.
- Reference rules implementation (the engine must match it): `tools/dp-migration/nonjd_reorder_check.py` (EXPECTED_SQL, RULE_CHECK_CTE, INVALID_RULES_SQL) and its 125 tests.
- Design: `projects/part order tool - app/Non-JD Parts Order Tool/design_handoff_parts_order_tool/` (README.md = screen specs and tokens; `theme.jsx`, `ui.jsx`, `layout.jsx`, `screens-*.jsx` = a working React prototype to reuse; `screenshots/`).
- Pattern app: `C:\Users\bfox\Documents\Git-Projects\parts-lookup-app` (MSAL setup, Graph file reads with gzip, mock auth, tests, Fedora/IIS deploy docs).

**Fixed facts:**
- Tenant: SPI. Report Site ID `spitractor.sharepoint.com,dc84cab5-e496-4929-a599-3123cbb823e1,65b43472-28c3-45c7-9c74-f7a57f2c839c`. Library "NonJD Order Data" drive ID `b!tcqE3JbkKUmlmTEjy7gj4XI0tGXDKMdFnHT3pX8sg5zaEz5s8TLPQp8PXM6Qhndu`.
- Lists (GUIDs): `NonJD_OrderRules` 6938ff15-48e0-4773-9ce7-e8a37187bf80; `NonJD_PartSettings` a4b26767-2c26-40b9-b5a0-22126a503e89; `NonJD_Orders` 88a77417-729b-4ba3-b096-51ca7f351385; `NonJD_OrderLines` 33897c6d-501d-4736-bacf-93703b938038. Column names are in plan A Task 1 and Task 16 (`docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md`).
- Users: Ben, Shannon, Barry, Curt (Edit through the site's Members group), plus Brian. Desktop browsers.
- Test hosting: the Fedora server `spi10sr2041l` (`10.110.100.13`), a second Apache site on port **8443** (Parts Availability's test copy owns 443 and its service worker's scope is `/`, so a separate origin avoids clashes). Never a tunnel from Brian's PC.

## File structure (app repo `nonjd-order-app`)

| Path | Responsibility |
|---|---|
| `src/config.ts` | Reads `VITE_*` settings (tenant, client id, site, drive, list GUIDs, data mode) |
| `src/auth/` | `msalConfig.ts`, `IAuthService.ts`, `EntraAuthService.ts`, `MockAuthService.ts`, `AuthContext.tsx` (copied from parts-lookup-app, scopes changed) |
| `src/data/types.ts` | TypeScript types for every file and list row (from the contract) |
| `src/data/graph.ts` | Token + Graph calls: file download (gzip/plain), list item read with paging, create, update |
| `src/data/files.ts` | `loadMeta`, `loadReorder(branch)`, `loadHistory(branch)`, `loadSurplus`, `loadTransfers`, `loadRulesSnapshot` |
| `src/data/lists.ts` | Rules, part settings, orders, order lines: read and write, field mapping |
| `src/data/mock/` | Mock data source for `VITE_DATA_MODE=mock` (local dev without Graph; used by UI tests) |
| `src/engine/` | `trim.ts`, `rules.ts` (validate, pick), `calc.ts` (compute one part), `explain.ts` (sentence), `format.ts` (number display), `oneTime.ts` (one-time order calc), `parity.ts` (compare to Gold) |
| `src/state/` | `useBranchData.ts` (load + recompute a branch), `useLists.ts` (rules/settings/orders cache with refresh after writes) |
| `src/ui/` | Design tokens + shared components ported from the handoff (`theme.ts`, `Pill`, `Button`, `Card`, `Table`, `Stepper`, `Toggle`, `NavRail`, `TopBar`) |
| `src/pages/` | `HomePage`, `ReorderPage`, `PartLookupPage`, `PartPage` (Detail/History/Settings tabs), `OrdersPage`, `OrderPage`, `OneTimeOrderPage`, `RulesPage` (with Try-it panel), `CleanupPage`, `SettingsPage` |
| `src/export/csv.ts` | CSV per franchise |
| `scripts/` | `deploy-fedora.md` notes and a build-and-copy script |

---

### Task B1: Entra app registration (Brian, verified step by step)

The app writes to SharePoint lists, so it needs its own registration with write permission (Parts Availability's has read only).

1. Entra admin center → App registrations → New registration: name **Non-JD Order Tool**, single tenant, platform **Single-page application**, redirect URIs `http://localhost:5173` and `https://10.110.100.13:8443`.
2. API permissions → Microsoft Graph → Delegated: `User.Read`, `Sites.ReadWrite.All`. Grant admin consent if the tenant requires it (Brian handles).
3. Enterprise applications → Non-JD Order Tool → Properties: **Assignment required = Yes**; Users and groups: assign Ben, Shannon, Barry, Curt and Brian.
4. Record the Application (client) ID and Directory (tenant) ID in this plan's progress note (they're not secrets).

Verification (controller): read the registration with `az ad app show --id <clientId>` (redirect URIs, `requiredResourceAccess`), and the service principal's `appRoleAssignmentRequired` and assignments with `az rest`.

### Task B2: Publish a rules snapshot (data-projects)

So the app can prove its engine matches Gold, publish the rules Gold used.

- `publish/extract.py`: add `rules(con)` reading DP_Presentation `NonJD_OrderRules` (all columns except Modified; Id as int) ordered by Id.
- `publish/build_files.py`: write `rules.json.gz` = `{"dataAsOf", "rules": [...]}` (camelCase keys: id, ruleName, priority, active, franchise, dealerGroupCode, branch, startMonth, endMonth, historyMonths, minActiveMonths, weeksOfCover, demandBasis).
- `run_publish.py`: include it in the build; it's re-uploaded every run like reorder files.
- README contract: add the `rules.json.gz` section ("the rules list as the DP run read it; the app uses it only to check its engine against Gold").
- Tests first in `test_build_files.py` (file written, keys, ordering, determinism) and `test_run_publish.py` (uploaded with the others, before `_meta.json`).
- Caveat to document: the dataflow and Gold run in the same DP run, so the table read at publish time is what Gold used unless the rules dataflow is re-run in between; the parity check reports, it doesn't block.

### Task B3: Scaffold the app (app repo)

- Copy from parts-lookup-app: `package.json` (rename; same versions; drop `vite-plugin-pwa` for now), `tsconfig.json`, `vite.config.ts` (no PWA), `vitest.config.ts`, `eslint.config.js`, `index.html`, `src/main.tsx`, `src/main.css`, the auth services, `AuthContext`, `AuthPage`, `bootstrap.ts`, test setup and the auth tests.
- Scopes: `['User.Read', 'Sites.ReadWrite.All']` with a comment (writes to lists).
- `src/config.ts` and `.env.example` with every `VITE_*` value from the fixed facts (`VITE_DATA_MODE=graph|mock`).
- Design tokens from `theme.jsx` "Slate Pro" into Tailwind theme variables in `main.css` (`--color-nav`, `--color-accent`, … and the three status colour pairs, unthemed).
- App shell: `NavRail` (Home, Recommended Reorder, One-Time Order, Part Lookup, Orders, Rules, App Settings; no Transfers) and `TopBar` (breadcrumb, branch chip, data-as-of chip with the stale flag), routes to placeholder pages.
- Tests: the copied auth tests pass; a shell test renders the rail and navigates; `npm run lint`, `npm test`, `npm run build` all clean.

### Task B4: Rules engine (test first; must match Gold)

Port spec 5.5 and the reference SQL exactly. All functions are pure.

```ts
// src/engine/types.ts
export interface Rule { id: number; ruleName: string | null; priority: number | null; active: boolean | null;
  franchise: string | null; dealerGroupCode: string | null; branch: string | null;
  startMonth: number | null; endMonth: number | null; historyMonths: number | null;
  minActiveMonths: number | null; weeksOfCover: number | null; demandBasis: string | null; }
export interface PartInputs { branch: string; franchise: string; partNumber: string; dealerGroupCode: string;
  onHand: number; onOrder: number; minimumQty: number | null; minOverride: number | null; isMasked: boolean;
  sales: number[]; requests: number[]; }            // 60 values, index 0 = current month
export interface PartResult { ruleId: number | null; ruleName: string; demandBasis: 'UnitsSold' | 'Requests';
  historyMonths: number; minActiveMonths: number; weeksOfCover: number; windowDemand: number; activeMonths: number;
  monthlyRate: number; calcTarget: number; effectiveMin: number; minimumIgnored: boolean; target: number;
  recommendedQty: number; surplusQty: number;
  status: 'Masked' | 'NoRecentActivity' | 'NotStocked' | 'OutOfStock' | 'Reorder' | 'OK'; }
```

- `trim.ts`: `ztrim(s)` = strip leading/trailing Unicode `\p{Zs}` (`/^\p{Zs}+|\p{Zs}+$/gu`), same as Gold's and DuckDB's trim; `norm(s)` = `ztrim(s).toUpperCase()`, blank → null.
- `rules.ts`:
  - `ruleProblems(rule): string[]` with the reference's exact messages, checked only for active rules: Priority/HistoryMonths/MinActiveMonths/WeeksOfCover missing; HistoryMonths whole 1-59; MinActiveMonths whole 0-59; WeeksOfCover 0-104 (NaN/±Infinity invalid); exactly one month set; months whole 1-12; DemandBasis UnitsSold/Requests (trimmed, case-insensitive). Read the exact strings from `INVALID_RULES_SQL` / `RULE_CHECK_CTE`.
  - `ruleLabel(rule)` = `ztrim(ruleName)` or `Rule <id>` when blank.
  - `usableRules(rules, month)`: active, no problems, in season (both months blank = all year; start ≤ end: start ≤ m ≤ end; start > end: m ≥ start or m ≤ end).
  - `pickRule(part, usable)`: criteria blank = any, else `norm(rule.x) === norm(part.x)` for franchise, dealerGroupCode, branch; highest priority, then more non-blank criteria, then lowest id; none → built-in default `{ruleId: null, ruleName: 'Built-in default', historyMonths: 12, minActiveMonths: 3, weeksOfCover: 6, demandBasis: 'UnitsSold'}`.
- `calc.ts`: `computePart(part, usable, month): PartResult` — window = indices `1..historyMonths` of the chosen basis array (current month index 0 excluded); windowDemand = max(0, sum); activeMonths = count > 0; monthlyRate = windowDemand / historyMonths; calcTarget = activeMonths ≥ minActiveMonths ? ceil(round9(monthlyRate × weeksOfCover × 12 / 52)) : 0 with `round9(x) = Math.round(x * 1e9) / 1e9` evaluated left to right; effectiveMin = minOverride ?? (activeMonths > 0 ? minimumQty : null) ?? 0; minimumIgnored = minOverride == null && (minimumQty ?? 0) > 0 && activeMonths === 0; target = max(calcTarget, ceil(effectiveMin)); oh = trunc(onHand), oo = trunc(onOrder); recommendedQty = isMasked ? 0 : max(0, target − oh − oo); surplusQty = max(0, oh − target); status in the order Masked, (target 0: activeMonths 0 → NoRecentActivity else NotStocked), OutOfStock (rec > 0 and onHand ≤ 0), Reorder, OK.
- `explain.ts`: `explain(part row incl. result): string` following the README decision order exactly, with plurals and `format.ts` (monthlyRate ≤ 2 decimals, "< 0.01" rule, 1 decimal for weeksOfCover/windowDemand).
- Tests (write first, `src/engine/__tests__/`): port the reference test cases one for one (scope rules are applied upstream, so skip scope tests): defaults, priority, ties (criteria count, lowest id), inactive, trim/case including NBSP, season inside/outside/wrap (Jan/Jun/Nov/Feb), every invalid-rule message, window boundaries (index 0 excluded, index historyMonths included, historyMonths+1 excluded), negative demand → 0, monthly rate by historyMonths, Requests basis, rounding noise ((5/3)×5.2×12/52 → 2), below-min with minimum, Equip minimum ignored without demand, override always applies, masked, NotStocked vs NoRecentActivity, negative on hand truncation, OK. Explanation: every README worked example reproduced verbatim, plus each NotStocked variant and the negative-stock sentence.
- Masking live: `isMaskedLive(setting, todayCentral)` = Masked && (MaskExpires null || MaskExpires ≥ today) (today in America/Chicago).

### Task B5: Data access

- `graph.ts`: `getToken()` (silent, falls back to popup on `InteractionRequiredAuthError`), `downloadFile(name)` (gzip via `DecompressionStream` for `.gz`, plain JSON otherwise), `listItems(listId, select)` (follows `@odata.nextLink`, `$top=999`, `$expand=fields($select=...)`), `createItem(listId, fields)`, `updateItem(listId, itemId, fields)`. Errors carry status and Graph's message.
- `files.ts` and `lists.ts` map raw shapes to `types.ts`. Settings map by key `branch|franchise|partNumber` (raw part number, exact); duplicates resolved like Gold (latest Modified, then highest Id).
- Mock mode: `src/data/mock/` serves small fixture files (2 branches, ~40 parts covering every status) and in-memory lists; writes update memory. Used by `npm run dev` with `VITE_DATA_MODE=mock` and by page tests.
- Tests with `fetch` mocked: gzip decode, paging across two pages, field mapping, error surfacing, settings duplicate rule.

### Task B6: Engine parity with Gold

- `parity.ts`: `compareToGold(goldRow, result)` → list of differing fields (exact for ints/strings/booleans, 1e-6 for windowDemand, monthlyRate, weeksOfCover, effectiveMin).
- Fixture generator (data-projects `publish/make_engine_fixture.py`): after a build, sample ~400 parts across all branches (every status, every rule, minimumIgnored true/false, masked, overrides), write `{"rules", "month", "parts": [{inputs, gold}]}` to the app repo `src/engine/__fixtures__/gold-sample.json` (inputs from the reorder + history files and settings as Gold saw them: minOverride/isMasked from the part rows).
- Test: every fixture part's engine result equals Gold (0 differences).
- Runtime: the reorder page computes with the **rules snapshot** too when the live rules equal the snapshot; if any part differs from Gold, show a banner "the app's calculation disagrees with this morning's run on N parts" (a bug signal, not a user error). When live rules differ from the snapshot, show "rules changed since this morning" and mark parts whose result differs from Gold.

### Task B7: Recommended Reorder page

Per the handoff "Recommended Reorder" spec and screenshot 02, with:
- Branch and franchise pickers (branches from `_meta`), "reorder needed only" toggle (default on: status OutOfStock/Reorder), search (part number or description), sortable columns: Part (+description), Bin, Cost, Sold 12 mo, Rate/mo, On hand (status-coloured), On order, Inbound (transfers), Target, Order, Est. value, Status pill, Rule.
- Row expand or popover: the explanation sentence, the rule settings, the surplus hint ("Branch 92 has 10 over target") from `surplus.json`, inbound transfer lines from `transfers.json`, and a "differs from this morning" marker when applicable.
- Selection with a pinned action bar (count, total value), "Create order" → Task B10.
- Data: `useBranchData(branch)` loads reorder + history (+ surplus/transfers once), live rules and settings, computes every part with the engine, merges live overrides/masks. Loading and error states; data-as-of with the stale flag (older than one business day).
- Tests (mock mode): filtering, sorting, totals, explanation shown, surplus hint, inbound column, live rule change alters a row.

### Task B8: Part lookup and Part page

- Lookup: search across the loaded branch (and "all branches" mode that loads each branch's reorder file on demand); results table; row → Part page.
- Part page tabs per the handoff: **Detail** (stock gauge, prices, recommendation with the explanation, rule), **History** (12-month bar chart from the history arrays, 60-month table, summary stats), **Settings** (MinOverride, Masked + MaskExpires, EOQ, ForceNonSpiking, PreApprovedRule, Notes → `NonJD_PartSettings` create/update; Title `branch|franchise|partNumber`; banner "applies immediately in this app; the morning run picks it up tomorrow").
- Other branches: on-hand/target/surplus for the same franchise+part from `surplus.json` and on-demand reorder files.
- Tests: tabs, chart data mapping, settings save calls `createItem`/`updateItem` with exact fields and the page recomputes.

### Task B9: Rules page with the "Try it" panel

- Table of all rules (name, priority, active, criteria, season, settings, problems from `ruleProblems`), plus the built-in default row (read-only).
- Edit/new rule form with validation identical to `ruleProblems` (can't save an invalid rule).
- **Try it:** pick a branch; edit a draft of any rule; the page recomputes the branch with the draft in place and shows before/after: order lines, total value, count by status, and the parts whose order changed most. Nothing is saved until **Save rule** (create/update in `NonJD_OrderRules`).
- Who can edit: everyone with list Edit (spec 8.5 item 5); show who last changed each rule (`Editor`/`Modified` from Graph).
- Tests: draft changes recompute totals without writing; save writes exact fields; invalid draft blocked with the reference's message.

### Task B10: Orders, CSV export

- Create from a selection: one order per franchise (`NonJD_Orders`: Title "<Branch>-<Franchise>-<yyyymmdd-hhmm>", Branch, Franchise, OrderType Recommended, Parameters JSON {rules snapshot names, dataAsOf}, Status Draft) and its lines (`NonJD_OrderLines`: OrderId, Branch, Franchise, PartNumber, RecommendedQty, OrderQty (editable before saving), Cost, LineValue).
- Orders page: list (filters by branch/status), order page with lines, edit quantities while Draft, **Export CSV** (one file per order = per franchise: `PartNumber,Description,OrderQty,Cost,LineValue,Bin` + header, filename `<Title>.csv`), increments ExportCount and sets Status Exported; **Mark placed** → Placed.
- Tests: split by franchise, line fields, CSV content and escaping, status transitions, Graph calls batched sensibly (lines created sequentially with retry on 429).

### Task B11: One-Time Order

Per the handoff steps 3-4 (screenshots 03-04): setup (order name, branch, franchise, dealer group, months checklist with quick ranges Rolling 12/24/36 and full calendar years from the history labels) → review (loading factor, min demands, min sales, view Total | Avg/mo, calculate in the browser from the history arrays: anticipated = sum (or average) of selected months × loading factor; rec qty = max(0, ceil(anticipated) − trunc(onHand) − trunc(onOrder)); parts below min demands/sales excluded), select, save as order (OrderType OneTime, Parameters JSON) and export CSV via Task B10.
- `engine/oneTime.ts` pure with tests (sum vs average, loading factor, minimums, months selection).

### Task B12: Cleanup list and Home

- Cleanup page: all branches' parts with `minimumIgnored` (Equip minimum, cost, minimum × cost, last requested), sortable, CSV export — Ben's stale-minimum list.
- Home: greeting, data-as-of pill (stale flag), attention banner (parts to order at the selected branch, total value), cards to Reorder, One-Time Order, Part Lookup, Orders, Rules, Cleanup.
- App Settings: default branch and franchise (per-user, `localStorage`, wrapped in try/catch).

### Task B13: Fedora test hosting (Brian, verified step by step)

- Build with `.env.production` (graph mode, real IDs), copy `dist/` to the Fedora server, Apache vhost on 8443 (self-signed cert like Parts Availability's test copy; notes in `parts-lookup-app/docs/FEDORA-SERVER-DEPLOYMENT.md`), firewall port, SPA fallback to `index.html`.
- Verify sign-in, a branch loads, a settings save round-trips, a rule draft recomputes, an order saves and exports.
- Document in the app repo `docs/FEDORA-TEST-DEPLOYMENT.md`.

### Task B14: Walkthrough with Brian, then Ben and Shannon

Brian checks every page against the README's explanation examples on real parts; collect feedback in this plan's progress note. Then share the test URL with the four users.

## Self-review notes

- Spec 8 (screens), 8.5 (live rules, try-it, Gold as baseline, parity, who edits), 7 (lists), the publish README's explanation and display rules, and the handoff screens each map to a task above. Transfers (driver app) is out of scope; the Transfers nav item is dropped.
- Known limits carried over: transfers match on part number only; settings keys are raw part numbers (SharePoint may trim trailing spaces); stock levels are the morning snapshot.
