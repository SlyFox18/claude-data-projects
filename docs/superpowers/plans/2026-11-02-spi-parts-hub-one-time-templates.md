# SPI Parts Hub round 3 phase 2: One-Time templates (Plan J, app 0.10.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a
> review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax.

> **Progress:** plan written 2026-11-02 (Claude, for Brian). Decisions J-D1–J-D10 approved by Brian 2026-11-02.
> - **J0 done 2026-11-02:** lists created by Brian and checked through Graph: NonJD_OneTimeTemplates
>   `d13a45c7-fac0-4f37-8fcb-6c85c0ab0fb1` (Title, Description, Setup plain multi-line, Archived default No),
>   NonJD_TemplateChanges `2b4bbe11-99c7-46fa-a542-c89b14b849b2` (Title, TemplateId indexed, Summary plain
>   multi-line). Brian added `VITE_LIST_ONETIME_TEMPLATES` / `VITE_LIST_TEMPLATE_CHANGES` to `.env.production` and
>   `.env.example`.

**Goal:** One-Time Order set-ups can be saved as shared, editable templates with a who-changed-what history, so a
season's order (e.g. "Cotton pre-season, all branches, KU + AM, Rolling 12, factor 1.5") is one click to start.

**Architecture:** app only, no Fabric or publish change. Two new SharePoint lists (templates, change entries). A pure
module turns the Set up into a template and back (periods stored relative) and diffs two templates into readable
change text; the One-Time Set up gets a Template card; a small Templates page lists them with history and archive.

**Tech stack:** nonjd-order-app (React 19, TypeScript, Vite, Tailwind 4, react-router 7, Vitest), Graph lists via
`src/data/lists.ts`, mock source `src/data/mock`.

**Spec:** `docs/superpowers/specs/2026-10-30-spi-parts-hub-round-3-design.md`, "Phase 2 (0.10.0)" and R11.

---

## How we run this plan

- App repo `C:\Users\bfox\Documents\Git-Projects\nonjd-order-app`, branch `dev`. Commit per task; push at the end of
  each task after review. Stage named files only; `.env*` files are never read or committed (Brian edits
  `.env.production`).
- Tests in two halves (Brian's PC is short of memory):
  `npx vitest run --exclude "src/pages/__tests__/**"`, then `npx vitest run src/pages/__tests__`. Plus `npm run lint`
  and `npx tsc -b`. `npm run build` only in J6.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Decisions made in this plan (Brian can overrule any of them)

| # | Decision | Why |
|---|---|---|
| J-D1 | **What a template holds:** branches, franchises, dealer groups (none = every group), the period, method, loading factor, min demands, min sales, min / max line value; plus name and description. **Not** the order name (a template fills the order name only when it's blank, with the template's name). | Spec phase 2; an order name is per order. |
| J-D2 | **Periods stored relative:** `rolling` (N latest complete months), `year` (a calendar year, e.g. 2025), or `fixed` (exact months). Picked automatically from the months ticked when saving: Rolling 12/24/36 (any N from the latest month) → rolling; a full calendar year → year; anything else → fixed. | Spec: "a Rolling template stays current". |
| J-D3 | **Starting from a template whose values aren't in today's data** (a branch or franchise gone, a fixed month or year outside the 59 months): fill what exists and say what was left out ("Branch 97 isn't in today's data, so it was left out."). | Never silently change a template; never block. |
| J-D4 | **Update template** writes the whole set-up (one JSON column). Before writing it re-reads the template; if someone else saved it since you loaded it, it asks: "Shannon changed this template at 10:14 AM (loading factor 1.5 → 2). Replace it with yours?" **Replace** / **Cancel**. | No etags in the app; same "re-read first" rule as rules and transfers. |
| J-D5 | **History:** every save writes one change entry (who and when come from SharePoint's Created / Created By). Text: "Created", or the diff joined with "; " ("loading factor 1.5 → 2; added franchise KU; period Rolling 12 → Rolling 24"), "Renamed X → Y", "Archived", "Unarchived". If the entry fails after the template saved, the template stays saved and a warning says the history entry didn't save. | Spec R11. |
| J-D6 | **"Changed since you last used it":** the browser remembers, per template, the Modified time when you last started from it (localStorage, wrapped in try/catch). When the template's Modified is later and its editor isn't you, the Template card says "Changed by Shannon on Oct 30" with a **History** link. Lost storage just means no notice. | Per-viewer convenience; nothing shared needs it. |
| J-D7 | **Names are unique** among unarchived templates (trimmed, case-insensitive), 1–80 characters. Archived templates keep their names; unarchiving a clash asks for a new name. | Avoid two "Cotton" templates in the picker. |
| J-D8 | **Anyone can save, update, archive and unarchive** (R11). No delete in the app. | Spec. |
| J-D9 | **A saved One-Time order records which template it started from** (`templateId`, `templateName` in its Parameters; not shown anywhere yet beyond the order's parameters line "From template Cotton pre-season"). | Traceability for "why did this order use 1.5". |
| J-D10 | **The Templates page** is in Non-JD ordering's rail, after One-Time Order: name, description, the set-up in one line, changed by / when, Show archived, History (expand), **Start order** (opens One-Time Order with it applied), Archive / Unarchive. Editing happens on One-Time Set up (start from it, change, **Update template**). | One place to edit; a list to find and tidy. |

## SharePoint lists (J0, Brian)

Create on the Report Site, like the returns lists:

**NonJD_OneTimeTemplates**
| Column | Type | Notes |
|---|---|---|
| Title | (built in) | the template name |
| Description | Multiple lines of text (plain) | optional |
| Setup | Multiple lines of text (plain) | JSON, written by the app |
| Archived | Yes/No | default No |

**NonJD_TemplateChanges**
| Column | Type | Notes |
|---|---|---|
| Title | (built in) | the template's name at the time |
| TemplateId | Number (0 decimals) | **indexed** |
| Summary | Multiple lines of text (plain) | the change text |

Then add to `.env.production`: `VITE_LIST_ONETIME_TEMPLATES=<id>` and `VITE_LIST_TEMPLATE_CHANGES=<id>` (Claude
reads the IDs through Graph after Brian creates the lists, and gives them to him).

## File map

| File | Change |
|---|---|
| `src/data/types.ts` | `TemplatePeriod`, `OneTimeTemplateSetup`, `OneTimeTemplate`, `OneTimeTemplateRow`, `OneTimeTemplateInput`, `OneTimeTemplatePatch`, `TemplateChangeRow`, `TemplateChangeInput` |
| `src/config.ts`, `src/auth/bootstrap.ts` | two list keys, both required |
| `src/data/source.ts` | five methods on `DataSource` and `graphSource` |
| `src/data/lists.ts` | mappers + list calls (pattern: `returnRuleFromItem` / `returnRuleToFields`) |
| `src/data/mock/index.ts`, `fixtures.ts` | seeded templates and change entries; writes through the real mappers |
| `src/oneTime/templates.ts` (new) | pure: periods, set-up ↔ template, apply with notes, diff text, name checks |
| `src/oneTime/lastUsed.ts` (new) | localStorage "last used" per template |
| `src/pages/oneTime/TemplateCard.tsx` (new) | the Set up card: pick / start, save as, update, history, archive |
| `src/pages/oneTime/TemplateHistory.tsx` (new) | history list (used by the card and the page) |
| `src/pages/OneTimeOrderPage.tsx` | state from / to a template, `?template=<id>`, Parameters `templateId` / `templateName` |
| `src/orders/oneTimeDraft.ts` | `OneTimeSetup.templateId?`, `templateName?`; `describeOneTimeParameters` adds "From template X" |
| `src/pages/TemplatesPage.tsx` (new), routes, `src/ui/areas.ts` | the Templates page and rail link |

---

## Tasks

### Task J0: Lists and IDs (Brian, with Claude)

- [ ] **Step 1:** Brian creates the two lists above (Title, Description, Setup, Archived; Title, TemplateId indexed,
  Summary).
- [ ] **Step 2:** Claude reads the list IDs through Graph (`az rest ... /sites/<site>/lists?$select=id,displayName`)
  and checks the columns (`/lists/<id>/columns`): names, types, TemplateId indexed. Gives Brian the two lines for
  `.env.production`.
- [ ] **Step 3:** Brian adds them. (`npm run dev` uses the mock and doesn't need them.)

### Task J1: Types, config, data source, Graph and mock

**Files:** as in the file map (types, config, bootstrap, source, lists, mock); tests in `src/data/__tests__/`
(lists mappers) and `src/data/mock/__tests__/` (if present; else beside the existing mock tests).

- [ ] **Step 1: types** (`src/data/types.ts`):

```ts
/** How a template's months are kept so it stays current (plan J-D2). */
export type TemplatePeriod =
  | { kind: 'rolling'; months: number }   // the N latest complete months (history indices 1..N)
  | { kind: 'year'; year: string }        // a calendar year, e.g. '2025'
  | { kind: 'fixed'; months: string[] };  // exact months, 'YYYY-MM', newest first

export interface OneTimeTemplateSetup {
  branches: string[];
  franchises: string[];
  /** null = every dealer group. */
  dealerGroupCodes: string[] | null;
  period: TemplatePeriod;
  method: OneTimeMethod;
  loadingFactor: number;
  minDemands: number;
  minSales: number;
  minLineValue: number | null;
  maxLineValue: number | null;
}

export interface OneTimeTemplate {
  name: string;
  description: string;
  archived: boolean;
  setup: OneTimeTemplateSetup;
}
export interface OneTimeTemplateRow extends OneTimeTemplate, ItemAudit { itemId: number; }
export type OneTimeTemplateInput = OneTimeTemplate & { itemId?: number | null };
export type OneTimeTemplatePatch = Partial<OneTimeTemplate>;

export interface TemplateChangeRow {
  itemId: number;
  templateId: number;
  /** The template's name when the change was made. */
  name: string;
  summary: string;
  /** SharePoint Created (ISO) and Created By display name. */
  at: string | null;
  by: string | null;
}
export interface TemplateChangeInput { templateId: number; name: string; summary: string; }
```

(`OneTimeMethod` is imported from `@/engine`; if types.ts can't import from the engine without a cycle, declare
`'total' | 'average'` locally and assert equality with a type test.)

- [ ] **Step 2: config.** `AppConfig.lists.oneTimeTemplates` from `VITE_LIST_ONETIME_TEMPLATES`, `templateChanges`
  from `VITE_LIST_TEMPLATE_CHANGES`; both in `REQUIRED_LIST_KEYS`; the bootstrap header comment lists them. Tests for
  `missingListKeys` naming them.
- [ ] **Step 3: DataSource** (`src/data/source.ts`), mapped in `graphSource`:

```ts
loadOneTimeTemplates(): Promise<OneTimeTemplateRow[]>;
/** Create (no itemId) or replace every column. Returns the item id. */
saveOneTimeTemplate(t: OneTimeTemplateInput): Promise<number>;
/** Only the patch's columns (archive = { archived: true }). */
patchOneTimeTemplate(itemId: number, patch: OneTimeTemplatePatch): Promise<void>;
/** One template's change entries, newest first. */
loadTemplateChanges(templateId: number): Promise<TemplateChangeRow[]>;
addTemplateChange(c: TemplateChangeInput): Promise<number>;
```

- [ ] **Step 4: Graph** (`src/data/lists.ts`), following the return-rule mappers:
  - `ONE_TIME_TEMPLATE_FIELDS = ['Title', 'Description', 'Setup', 'Archived']`.
  - `oneTimeTemplateFromItem(item)`: `skipRow` when Title is blank or Setup isn't valid JSON or fails
    `parseTemplateSetup` (Step 5); `modified` / `editor` from the raw item's `modified` / `modifiedBy`.
  - `oneTimeTemplateToFields(t)`: Title = trimmed name, Description, Setup = `JSON.stringify(setup)`, Archived.
  - Patch → only the given columns (`setup` → Setup JSON).
  - Changes: fields `['Title', 'TemplateId', 'Summary']`; load filters `fields/TemplateId eq <id>` (indexed) and
    sorts by `created` descending in code; `at` = raw `created`, `by` = raw `createdBy`.
- [ ] **Step 5: `parseTemplateSetup(x: unknown): OneTimeTemplateSetup | null`** in `src/oneTime/templates.ts`
  (create the file here; J2 adds the rest): arrays of non-empty strings for branches / franchises; dealerGroupCodes
  array or null; period one of the three kinds (rolling months an integer 1..59; year `^\d{4}$`; fixed months
  matching `^\d{4}-\d{2}$`, at least one); method `'total' | 'average'`; finite numbers; line values finite or null.
  Anything else → null (the row is skipped with the list's usual skip warning).
- [ ] **Step 6: mock.** Seed two templates and their history in `fixtures.ts`:
  - itemId 1 "Cotton pre-season": branches ['1','92'], franchises ['BS'], dealer groups null, rolling 12, total,
    factor 1.5, min demands 0, min sales 0, line values null; editor 'Shannon Cole', modified '2026-10-30T15:14:00Z';
    changes: id 1 "Created" by 'Ben Hill' at '2026-10-20T14:00:00Z', id 2 "loading factor 1 → 1.5" by 'Shannon Cole'
    at '2026-10-30T15:14:00Z'.
  - itemId 2 "Old 2024 order": archived true, year '2024', franchises ['BS'], branches ['1'], factor 1; one "Created".
  - Writes go through the real mappers (as `saveReturnRule` does); `addTemplateChange` stamps `created` = now and
    `createdBy` = `MOCK_EDITOR`.
- [ ] **Step 7: tests:** mapper round trips (including a bad Setup row skipped), the change-list filter and order,
  mock save → load, patch archive. Full suite (two halves), lint, tsc. Commit "J1: template lists, types, sources".

### Task J2: Template logic (pure)

**Files:** `src/oneTime/templates.ts`, `src/oneTime/__tests__/templates.test.ts`.

- [ ] **Step 1: write the failing tests** (labels: 60 months newest first, as the history file gives them; index 0
  is the current partial month, `labels[1]` the latest complete month):

```ts
import { describe, expect, it } from 'vitest';
import { periodFromMonths, monthsFromPeriod, periodText, templateDiff, nameProblem } from '../templates';

// 2026-11 (partial) back to 2021-12: 60 labels, newest first
const labels = Array.from({ length: 60 }, (_, i) => {
  const d = new Date(Date.UTC(2026, 10 - i, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
});
const idx = (label: string) => labels.indexOf(label);

describe('periodFromMonths', () => {
  it('Rolling N from the latest complete month', () => {
    expect(periodFromMonths([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], labels)).toEqual({ kind: 'rolling', months: 12 });
    expect(periodFromMonths([1, 2, 3], labels)).toEqual({ kind: 'rolling', months: 3 });
  });
  it('a full calendar year', () => {
    const y2025 = labels.map((l, i) => (l.startsWith('2025-') ? i : -1)).filter((i) => i > 0);
    expect(periodFromMonths(y2025, labels)).toEqual({ kind: 'year', year: '2025' });
  });
  it('anything else is fixed, newest first', () => {
    expect(periodFromMonths([idx('2026-03'), idx('2026-05')], labels))
      .toEqual({ kind: 'fixed', months: ['2026-05', '2026-03'] });
  });
});

describe('monthsFromPeriod', () => {
  it('rolling follows the data', () => {
    expect(monthsFromPeriod({ kind: 'rolling', months: 3 }, labels)).toEqual({ months: [1, 2, 3], missing: [] });
  });
  it('a year that is only partly in the data is applied as far as it goes and says so', () => {
    const r = monthsFromPeriod({ kind: 'year', year: '2021' }, labels);
    expect(r.months).toEqual([idx('2021-12')]);
    expect(r.missing).toEqual(['2021-01', '2021-02', '2021-03', '2021-04', '2021-05', '2021-06', '2021-07',
      '2021-08', '2021-09', '2021-10', '2021-11']);
  });
  it('fixed months outside the data (or the current partial month) are missing', () => {
    expect(monthsFromPeriod({ kind: 'fixed', months: ['2026-11', '2026-05', '2019-01'] }, labels))
      .toEqual({ months: [idx('2026-05')], missing: ['2026-11', '2019-01'] });
  });
});

describe('periodText', () => {
  it('reads like the Set up summary', () => {
    expect(periodText({ kind: 'rolling', months: 12 })).toBe('Rolling 12');
    expect(periodText({ kind: 'year', year: '2025' })).toBe('Full year 2025');
    expect(periodText({ kind: 'fixed', months: ['2026-05', '2026-03'] })).toBe('May 2026, Mar 2026');
  });
});

const base = {
  name: 'Cotton', description: '', archived: false,
  setup: { branches: ['1'], franchises: ['BS'], dealerGroupCodes: null, period: { kind: 'rolling', months: 12 },
    method: 'total', loadingFactor: 1, minDemands: 0, minSales: 0, minLineValue: null, maxLineValue: null },
} as const;

describe('templateDiff', () => {
  it('Created when there is no before', () => {
    expect(templateDiff(null, base)).toBe('Created');
  });
  it('lists each change in a fixed order', () => {
    const after = { ...base, setup: { ...base.setup, loadingFactor: 1.5, franchises: ['BS', 'KU'],
      branches: [], period: { kind: 'rolling', months: 24 } } } as const;
    expect(templateDiff(base, after)).toBe(
      'removed branch 1; added franchise KU; period Rolling 12 → Rolling 24; loading factor 1 → 1.5');
  });
  it('name, description, archive', () => {
    expect(templateDiff(base, { ...base, name: 'Cotton 2027' })).toBe('Renamed Cotton → Cotton 2027');
    expect(templateDiff(base, { ...base, description: 'For Barry' })).toBe('description changed');
    expect(templateDiff(base, { ...base, archived: true })).toBe('Archived');
    expect(templateDiff({ ...base, archived: true }, base)).toBe('Unarchived');
  });
  it('blank when nothing changed', () => {
    expect(templateDiff(base, base)).toBe('');
  });
});

describe('nameProblem', () => {
  const rows = [{ itemId: 1, name: 'Cotton', archived: false }, { itemId: 2, name: 'Old', archived: true }];
  it('required, at most 80, unique among unarchived (trimmed, any case)', () => {
    expect(nameProblem('  ', rows, null)).toBe('Give the template a name.');
    expect(nameProblem('x'.repeat(81), rows, null)).toBe('Keep the name to 80 characters.');
    expect(nameProblem(' cotton ', rows, null)).toBe('A template called "Cotton" already exists.');
    expect(nameProblem('Cotton', rows, 1)).toBeNull();   // itself
    expect(nameProblem('Old', rows, null)).toBeNull();   // archived names are free
  });
});
```

- [ ] **Step 2:** run `npx vitest run src/oneTime/__tests__/templates.test.ts`; expect failures (functions missing).
- [ ] **Step 3: implement** in `src/oneTime/templates.ts` (beside `parseTemplateSetup` from J1):

```ts
import type { OneTimeTemplate, OneTimeTemplateSetup, TemplatePeriod } from '@/data/types';
import { fullYears, monthName, rollingMonths } from '@/engine';

const sameList = (a: readonly number[], b: readonly number[]) =>
  a.length === b.length && a.every((v, i) => v === b[i]);

/** The template period for the ticked history indices (plan J-D2). */
export function periodFromMonths(months: readonly number[], labels: readonly string[]): TemplatePeriod {
  const sorted = [...months].sort((x, y) => x - y);
  if (sorted.length > 0 && sameList(sorted, rollingMonths(sorted.length, labels))) {
    return { kind: 'rolling', months: sorted.length };
  }
  const year = fullYears(labels).find((y) => sameList([...y.months].sort((x, z) => x - z), sorted));
  if (year) return { kind: 'year', year: year.year };
  return { kind: 'fixed', months: sorted.map((i) => labels[i]) };
}

/** History indices for a template period on today's labels, and the months it wanted that aren't offered. */
export function monthsFromPeriod(p: TemplatePeriod, labels: readonly string[]): { months: number[]; missing: string[] } {
  const offered = (label: string) => { const i = labels.indexOf(label); return i >= 1 ? i : -1; };
  if (p.kind === 'rolling') {
    const months = rollingMonths(Math.min(p.months, labels.length - 1), labels);
    return { months, missing: [] };
  }
  const wanted = p.kind === 'year'
    ? Array.from({ length: 12 }, (_, m) => `${p.year}-${String(m + 1).padStart(2, '0')}`)
    : p.months;
  const months: number[] = [];
  const missing: string[] = [];
  for (const label of wanted) {
    const i = offered(label);
    if (i >= 1) months.push(i); else missing.push(label);
  }
  return { months: months.sort((x, y) => x - y), missing };
}

export function periodText(p: TemplatePeriod): string {
  if (p.kind === 'rolling') return `Rolling ${p.months}`;
  if (p.kind === 'year') return `Full year ${p.year}`;
  return p.months.map(monthName).join(', ');
}

const added = (before: readonly string[], after: readonly string[]) => after.filter((x) => !before.includes(x));
const fmt = (n: number | null) => (n == null ? 'none' : String(n));

/** The change entry's text (plan J-D5); '' when nothing changed. */
export function templateDiff(before: OneTimeTemplate | null, after: OneTimeTemplate): string {
  if (!before) return 'Created';
  if (before.archived !== after.archived) return after.archived ? 'Archived' : 'Unarchived';
  const parts: string[] = [];
  if (before.name.trim() !== after.name.trim()) parts.push(`Renamed ${before.name.trim()} → ${after.name.trim()}`);
  if (before.description.trim() !== after.description.trim()) parts.push('description changed');
  const b: OneTimeTemplateSetup = before.setup;
  const a: OneTimeTemplateSetup = after.setup;
  for (const x of added(b.branches, a.branches)) parts.push(`added branch ${x}`);
  for (const x of added(a.branches, b.branches)) parts.push(`removed branch ${x}`);
  for (const x of added(b.franchises, a.franchises)) parts.push(`added franchise ${x}`);
  for (const x of added(a.franchises, b.franchises)) parts.push(`removed franchise ${x}`);
  const groups = (g: string[] | null) => (g == null ? 'every dealer group' : g.join(', '));
  if (groups(b.dealerGroupCodes) !== groups(a.dealerGroupCodes)) {
    parts.push(`dealer groups ${groups(b.dealerGroupCodes)} → ${groups(a.dealerGroupCodes)}`);
  }
  if (periodText(b.period) !== periodText(a.period)) parts.push(`period ${periodText(b.period)} → ${periodText(a.period)}`);
  if (b.method !== a.method) parts.push(`method ${b.method === 'total' ? 'Total' : 'Avg / mo'} → ${a.method === 'total' ? 'Total' : 'Avg / mo'}`);
  if (b.loadingFactor !== a.loadingFactor) parts.push(`loading factor ${b.loadingFactor} → ${a.loadingFactor}`);
  if (b.minDemands !== a.minDemands) parts.push(`min demands ${b.minDemands} → ${a.minDemands}`);
  if (b.minSales !== a.minSales) parts.push(`min sales ${b.minSales} → ${a.minSales}`);
  if (b.minLineValue !== a.minLineValue) parts.push(`min line value ${fmt(b.minLineValue)} → ${fmt(a.minLineValue)}`);
  if (b.maxLineValue !== a.maxLineValue) parts.push(`max line value ${fmt(b.maxLineValue)} → ${fmt(a.maxLineValue)}`);
  return parts.join('; ');
}
```

  The order in the "lists each change" test is the order above: name, description, branches (added then removed),
  franchises, dealer groups, period, method, factor, minimums, line values. Match the test to the code if the
  engineer finds the order reads better otherwise, but keep it fixed.

```ts
export const MAX_TEMPLATE_NAME = 80;

export function nameProblem(
  name: string, rows: readonly { itemId: number; name: string; archived: boolean }[], selfId: number | null,
): string | null {
  const n = name.trim();
  if (n === '') return 'Give the template a name.';
  if (n.length > MAX_TEMPLATE_NAME) return `Keep the name to ${MAX_TEMPLATE_NAME} characters.`;
  const clash = rows.find((r) => !r.archived && r.itemId !== selfId && r.name.trim().toLowerCase() === n.toLowerCase());
  return clash ? `A template called "${clash.name.trim()}" already exists.` : null;
}
```

- [ ] **Step 4: apply with notes.** Add and test:

```ts
export interface TemplateApplied {
  branches: string[]; franchises: string[]; dealerGroupCodes: string[] | null; months: number[];
  method: OneTimeTemplateSetup['method']; factorText: string; minDemandsText: string; minSalesText: string;
  minLineText: string; maxLineText: string;
  /** What couldn't be applied, one sentence each (plan J-D3). */
  notes: string[];
}

export function applyTemplate(
  setup: OneTimeTemplateSetup,
  today: { branches: readonly string[]; franchises: readonly string[]; dealerGroups: readonly string[]; labels: readonly string[] },
): TemplateApplied
```

  Rules: keep only branches / franchises / dealer groups present today (franchises compared with `franchiseKey` from
  `@/engine`); a note per kind left out: "Branch 97 isn't in today's data, so it was left out." / "Branches 97 and 98
  aren't …" / same for franchise and dealer group; months via `monthsFromPeriod`, with one note for missing months
  ("Mar 2019 and Apr 2019 aren't in the 59 months of history, so they were left out."); numbers to text the way the
  page's inputs hold them (`String(n)`, null → ''). If no branch or franchise survives, the page's own
  "Pick at least one branch." / "Pick a franchise." problems take over; no extra note.
  Tests: a template with branch '97', franchise 'zz' and a year partly outside; all-present template gives no notes.

- [ ] **Step 5: `setupToTemplate(...)`** (the reverse): from the page's chosen branches, ticked franchises,
  `dealerGroupCodes`, chosen months + labels, method and parsed numbers → `OneTimeTemplateSetup`. Branches and
  franchises sorted for stable diffs. Test it round-trips through `applyTemplate` with no notes.
- [ ] **Step 6:** full suite, lint, tsc. Commit "J2: template logic".

### Task J3: Template card on One-Time Set up

**Files:** `src/pages/oneTime/TemplateCard.tsx`, `src/pages/oneTime/TemplateHistory.tsx`, `src/oneTime/lastUsed.ts`,
`src/pages/OneTimeOrderPage.tsx`; tests `src/pages/__tests__/oneTimeTemplates.test.tsx`,
`src/oneTime/__tests__/lastUsed.test.ts`.

- [ ] **Step 1: `lastUsed.ts`:** `rememberUsed(itemId: number, modified: string | null): void` and
  `lastUsed(itemId: number): string | null`, one localStorage key `spi-onetime-template-used` holding
  `{ [itemId]: modified }`; every access in try/catch (a throw → no-op / null). Tests with a throwing storage stub.
- [ ] **Step 2: the card** (first card on Set up, above "Order details"), states:
  - **No template chosen:** select "Start from a template" listing unarchived templates by name ("—" when none,
    text "No templates yet. Set up an order and save it as a template."), button **Use**; button
    **Save as template**.
  - **Started from one:** "From template **Cotton pre-season**" + its description; if J-D6 applies, an amber line
    "Changed by Shannon Cole on Oct 30" with **History**; buttons **Update template** (enabled only when
    `templateDiff(loaded, current)` isn't ''; its title shows that text), **Save as new template**, **History**,
    **Archive**, and **Stop using** (keeps the Set up, forgets the template).
  - **Use:** calls `applyTemplate` with today's branches / franchises / dealer groups / labels, sets every Set up
    state, fills the order name only if blank, `rememberUsed(itemId, modified)`, shows the notes (J-D3) in a dismissible
    info box. If the branches are still loading, Use waits ("Waiting for the branches to load.") because franchises
    and dealer groups come from them.
  - **Save as template / Save as new template:** a small inline form: Name (prefilled with the order name, or the
    template's name + " (copy)"), Description, **Save** / **Cancel**; `nameProblem` shown live. Save: re-read
    templates (fresh names), `saveOneTimeTemplate`, then `addTemplateChange({ templateId, name, summary: 'Created' })`;
    the card switches to "From template …" for the new one.
  - **Update template:** J-D4: re-read the list; if the row's `modified` differs from the one loaded, load its last
    change entry and ask "Shannon Cole changed this template at 10:14 AM (loading factor 1.5 → 2). Replace it with
    yours?" **Replace** / **Cancel**; then `saveOneTimeTemplate({ itemId, ... })` and one change entry with
    `templateDiff(serverRow, mine)`. The loaded baseline becomes the saved value.
  - **Archive:** asks "Archive Cotton pre-season? It leaves the template list; you can bring it back from Templates."
    then `patchOneTimeTemplate(id, { archived: true })` + entry "Archived"; the card returns to "No template".
  - Errors: the action's message under the card; a failed change entry after a saved template: "Template saved,
    but its history entry didn't save." (J-D5).
- [ ] **Step 3: `TemplateHistory`:** loads `loadTemplateChanges(id)`, shows "Oct 30, 10:14 AM · Shannon Cole ·
  loading factor 1 → 1.5" newest first (`formatDataAsOf`), "No history yet." when empty, error with Try again.
- [ ] **Step 4: page wiring:** `?template=<id>` on the One-Time route applies that template once the branches have
  loaded (used by the Templates page's Start order); the page keeps `template: { itemId, name, loaded:
  OneTimeTemplate } | null` in state; `openReview` adds `templateId` / `templateName` to `OneTimeSetup` (J5) when a
  template is in use.
- [ ] **Step 5: tests** on the mock (helpers from `OneTimeOrderPage.test.tsx`): Use "Cotton pre-season" ticks branches
  1 and 92, BS, Rolling 12, factor 1.5 and fills a blank name; a template with a missing branch shows the note;
  Save as template with a clashing name is refused, a new name saves the row and a "Created" entry; changing the
  factor enables Update template and writes "loading factor 1.5 → 2"; the Replace prompt when the row changed
  underneath (patch the mock between load and update); Archive; the J-D6 line with a stubbed `lastUsed`; Stop using.
  Full suite, lint, tsc. Commit "J3: template card on One-Time Set up".

### Task J4: Templates page

**Files:** `src/pages/TemplatesPage.tsx`, the router file that holds the Non-JD routes, `src/ui/areas.ts`;
test `src/pages/__tests__/TemplatesPage.test.tsx`.

- [ ] **Step 1:** route `/non-jd/templates` (match the One-Time route's prefix; check the router) titled
  "One-Time templates", rail link "Templates" after "One-Time Order" in Non-JD ordering.
- [ ] **Step 2:** table: Name (+ description under it), Set up (one line: "Branches 1, 92 · BS · Rolling 12 · Total
  × 1.5" built from `periodText` and the same wording as `describeOneTimeParameters`), Changed (editor · date),
  actions **Start order** (link to the One-Time route with `?template=<id>`), **History** (expands
  `TemplateHistory` under the row), **Archive** / **Unarchive** (asks first; Unarchive with a name clash says
  "Rename the other Cotton first, or start from this one and save it under a new name." and does nothing), each
  writing its change entry. "Show archived (N)" toggle. Empty state: "No templates yet. Save one from One-Time
  Order's Set up." with a link.
- [ ] **Step 3:** tests: list and toggle, Start order navigates with `?template=1` and the One-Time page applies it,
  History expands with the two mock entries, Archive / Unarchive and the clash refusal. Full suite, lint, tsc. Commit
  "J4: Templates page".

### Task J5: The order remembers its template

**Files:** `src/orders/oneTimeDraft.ts` (+ tests).

- [ ] **Step 1:** `OneTimeSetup` gains `templateId?: number; templateName?: string;` (only when a template was in
  use); `describeOneTimeParameters` appends " · From template <name>" when `templateName` is a non-empty string.
- [ ] **Step 2:** tests: a draft built with a template carries both fields into Parameters; old orders without them
  describe as before. Commit "J5: orders record their template".

(J3 Step 4 depends on J5's type; do J5 before J3 if the engineer prefers.)

### Task J6: Click-through, review, 0.10.0 build

- [ ] **Step 1:** `src/__tests__/clickThrough0100.test.tsx`: One-Time Order → Use "Cotton pre-season" → change factor
  → Update template → Continue → Review shows "From template Cotton pre-season" → Templates page → History shows
  the new entry → Save as template from a fresh order → Archive it → Show archived.
- [ ] **Step 2:** `projects/part order tool - app/for-users/0.10.0-try-it.md` for Brian. **Task-shaped, not a test
  script** (Brian found the 0.9.0 numbered list confusing): three short jobs ("Start this season's order from a
  template", "Change a template and see the history", "Save your own and archive it"), each 3–5 sentences with what
  to look for.
- [ ] **Step 3:** review pass (typescript-reviewer over J1–J5); fix; full suite, lint, tsc.
- [ ] **Step 4:** `package.json` 0.10.0, README Versions row; `npm run build`; check dist (the two new list IDs plus
  the existing ones and the site, no mock strings, "Version 0.10.0 · commit …"). Push.

### Task J7: Release (Brian's steps, one at a time)

- [ ] **Step 1:** Brian deploys 0.10.0 to Fedora (the usual commands).
- [ ] **Step 2:** Brian saves a template **TEST template** from a small One-Time set-up, changes one value and
  updates it, then archives it. Claude checks both lists through Graph (the row's Setup JSON, three change entries:
  Created, the diff, Archived), then deletes the TEST template and its change entries (test data, Brian's standing
  OK) and says what was deleted.

### Task J8: Documents and progress

- [ ] **Step 1:** guide section "One-Time templates" (task-shaped), walkthrough "Version 0.10.0", regenerate both
  .docx (check for hand edits first), FUTURE-IDEAS F8 → done in 0.10.0.
- [ ] **Step 2:** this plan's Progress, the spec's Progress, memory.

---

## Self-review against the spec

- Stores the One-Time Set up with name and description: J1 types, J2 `setupToTemplate`. Periods relative: J-D2,
  J2 `periodFromMonths` / `monthsFromPeriod`.
- Start from template, Save as template, Update template, Archive: J3 (and J4 for Unarchive / Start order).
- Every save writes a change entry; template shows its history; "Changed by Shannon on Oct 30": J-D5, J-D6, J3
  Steps 2–3, J4.
- Lists `NonJD_OneTimeTemplates`, `NonJD_TemplateChanges` with columns: J0, J1.
- Testing: pure period / diff functions unit-tested (J2); mock covers archived, changed-by-someone-else, missing
  branch; click-through, review, real test and cleanup (J6, J7).
- Types are consistent across tasks: `OneTimeTemplateSetup`, `TemplatePeriod`, `templateDiff`, `applyTemplate`,
  `setupToTemplate`, `nameProblem`, `rememberUsed` / `lastUsed`, `loadTemplateChanges` / `addTemplateChange`.
