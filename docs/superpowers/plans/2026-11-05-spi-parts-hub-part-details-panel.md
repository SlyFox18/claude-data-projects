# Part details panel (Plan Q, app 0.15.1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

> **Shipped 2026-11-05:** app 0.15.1 (commit `ca5f16e`) on Fedora, installed by Brian; his try-it on mock and his real test
> (Ben's example on Seminole, not saved) passed. Commits: app 20c508a (Q1), 8d33289 (Q2), 03a2c17 (Q3), b674b61 (review
> fixes and Return wizard links), ca5f16e (Q4); data-projects 12c621f4 (try-it notes). Q1 + Q2 reviewed: approved on three
> fixes, all made in b674b61 (not re-reviewed; each has its own test). 3,081 tests, lint and tsc clean. App only.
>
> **Departures from the plan:**
> - **Open full page closes the panel first** on a plain click, so "Leave this page?" (in the page beneath) isn't hidden
>   behind the modal. If the user chooses Stay, the panel stays closed.
> - **Crash isolation:** the dialog shell and Close sit outside a keyed `ErrorBoundary` around `PartPanelBody` (which calls
>   `usePartRow`), so a crash in the panel shows its own message and the page keeps its work. Switching part reloads.
> - **`PartLink` and `useOpenPart` are in their own file**, `src/pages/part/PartLink.tsx`, which breaks an import cycle
>   through `OtherBranches`; `PartPanelContext.tsx` keeps only the provider.
> - **Return wizard links added** (`returns/PartsStep`, `ReviewStep`), since a return in progress has the same problem.
> - **Inventory excluded:** JD parts have no part page; its reports keep their own panels. Rule and check previews
>   (`returnRules/TryIt`, `transferRules/TransferTryItPanel`, `cleanup/CheckEditorPage`) stay plain text.
> - Closing focuses the opener, or `<main>` if the opener has gone. The backdrop closes on click, not mouse down. The
>   provider's pathname effect stays (it does nothing inside AppShell's keyed boundary; a test without that boundary needs it).
> - Known behaviour: the panel reads live settings, so it can show a newer number than the page beneath ("Changed"); the
>   browser's Back button leaves the page rather than closing the panel.

**Goal:** Clicking a part number anywhere opens a look-only side panel over the page, so an order in progress keeps its
ticks and quantities and never asks "Leave this page?".

**Architecture:** The panel isn't navigation: the page stays mounted under it, so `useBlocker` guards never fire. A
provider in `AppShell` holds "which part is open" and renders the panel; a shared `PartLink` keeps a real `href`
(new tab, Ctrl-click) and turns a plain click into "open the panel". With no provider (page tests) it's a plain `Link`,
so existing tests keep working. The panel reuses the part page's pieces, extracted into a shared component.

**Tech Stack:** React 19 + TS + react-router + Vitest (nonjd-order-app, branch `dev`).

**Spec:** `docs/superpowers/specs/2026-11-05-spi-parts-hub-part-details-panel-design.md`.

**Found while planning (spec updated):**
- JD parts have no part page: Inventory's `JdPartPanel` / `PartRecordsPanel` stay as they are (no `partPath` there).
- One-Time orders and the Order page show part numbers as plain text today. Ben's request names One-Time, so they
  gain `PartLink` (Q3).
- `useBranchData(branch, ...)` is per caller over a session cache, so the panel can load any branch beside the page's.
- `PartPage` calls `useTopBarChips`, and its tabs have fixed ids (`part-tab-detail`): the panel must not change the top
  bar, and its ids must not clash with a part page beneath it (`useId`).

**Rules for every task:** work on `dev`; stage only named files (`.env.example` has an unrelated change; never
`git add -A`); never read `.env*`; no `npm run build` (Q5 only); commit messages end with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; before each commit `npx tsc -b --noEmit`, `npx eslint <files>`.

---

### Task Q1: Shared part content and the panel

**Files:**
- Create: `src/pages/part/PartContent.tsx` (extracted from `PartView` in `PartPage.tsx`)
- Create: `src/pages/part/PartDetailsPanel.tsx`
- Modify: `src/pages/PartPage.tsx`
- Test: `src/pages/part/__tests__/PartDetailsPanel.test.tsx`

- [x] **Step 1: Write the failing tests**

```tsx
function renderPanel(partKey = { branch: '1', franchise: 'MC', partNumber: 'MC-OOS-1' }) {
  const onClose = vi.fn();
  render(
    <TestRouter initialEntries={['/reorder']}>
      <Routes><Route path="*" element={
        <PartDetailsPanel partKey={partKey} onClose={onClose} source={createMockSource()} reauthenticate={async () => {}} now={NOW} />
      } /></Routes>
    </TestRouter>,
  );
  return { onClose };
}

describe('PartDetailsPanel', () => {
  it('is a labelled dialog with Detail and History, no Settings tab, and takes focus', async () => {
    renderPanel();
    const dialog = await screen.findByRole('dialog', { name: /MC-OOS-1/ });
    expect(within(dialog).getByRole('tab', { name: 'Detail' })).toBeInTheDocument();
    expect(within(dialog).getByRole('tab', { name: 'History' })).toBeInTheDocument();
    expect(within(dialog).queryByRole('tab', { name: 'Settings' })).toBeNull();
    expect(within(dialog).getByRole('button', { name: 'Close' })).toHaveFocus();
  });

  it('Close and Escape close it', async () => {
    const user = userEvent.setup();
    const { onClose } = renderPanel();
    await user.click(await screen.findByRole('button', { name: 'Close' }));
    await user.keyboard('{Escape}');
    expect(onClose).toHaveBeenCalledTimes(2);
  });

  it('Open full page links to the part page', async () => {
    renderPanel();
    expect(await screen.findByRole('link', { name: 'Open full page' }))
      .toHaveAttribute('href', '/part/1/MC/MC-OOS-1');
  });

  it('says so when the part is not in the branch data', async () => {
    renderPanel({ branch: '1', franchise: 'MC', partNumber: 'NOPE' });
    expect(await screen.findByText(/isn't in Branch 1's data/)).toBeInTheDocument();
  });

  it('does not change the top bar chips', async () => {
    // Render inside the top bar context the PartPage tests use and assert the chips stay unset after load.
  });
});
```

(Replace the last test's comment with the assertion, using the helper `src/pages/__tests__/PartPage.test.tsx` uses for
`useTopBarChips`.)

- [x] **Step 2: Run them to see them fail** (`npx vitest run src/pages/part/__tests__/PartDetailsPanel.test.tsx`).

- [x] **Step 3: Extract `PartContent`**

Move `PartView` from `PartPage.tsx` to `src/pages/part/PartContent.tsx` as `PartContent`, adding `readOnly?: boolean`:
- `const tabs = readOnly ? TABS.filter(([k]) => k !== 'settings') : TABS;` used for the tablist and `onTabKey`.
- `const idBase = useId();` tab and panel ids become `` `${idBase}-tab-${k}` `` / `` `${idBase}-panel-${k}` ``
  (`TabPanel` gets `idBase`). Check `PartPage.test.tsx` doesn't select by the fixed ids; if it does, switch it to roles.
- `SettingsTab` renders only when `!readOnly`. `useOpenReturns` and `OtherBranches` stay.
- The heading level: `headingLevel` isn't needed; the panel titles the dialog with `aria-labelledby` on the
  `data-testid="part-number"` heading (`id` from a new `titleId` prop).
`PartPage` keeps its loading, not-found and `useTopBarChips`, and renders `<PartContent .../>`, with its `NotFound`
and row lookup moved to a shared hook:

```ts
/** The part's row in its branch's live data, and why there's none. */
export function usePartRow(partKey: PartKey, options: BranchDataOptions) {
  const { branch, franchise, partNumber } = partKey;
  const data = useBranchData(branch, options);
  const { computed, meta } = data;
  const branchMissing = meta != null && !meta.branches.some((b) => b.branch === branch);
  const row = useMemo(() => (computed && computed.branch === branch
    ? computed.rows.find((r) => r.gold.franchise === franchise && r.gold.partNumber === partNumber) ?? null
    : null), [computed, branch, franchise, partNumber]);
  return { data, row, branchMissing, notInBranch: !row && computed?.branch === branch };
}
```

All `PartPage` tests must pass unchanged at this point.

- [x] **Step 4: Write `PartDetailsPanel`**

```tsx
// A part's details over any page (Plan Q): the part page's content, look only, in a dialog. The page beneath stays
// mounted, so nothing there is lost and its leave warning never fires. Close, Escape or a click outside closes it.
export function PartDetailsPanel({ partKey, onClose, source, reauthenticate = graphReauthenticate, now }: {
  partKey: PartKey; onClose: () => void; source?: DataSource; reauthenticate?: () => Promise<void>; now?: () => Date;
}) {
  const titleId = useId();
  const closeRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const { data, row, branchMissing, notInBranch } = usePartRow(partKey, { source, reauthenticate, now });
  useEffect(() => { closeRef.current?.focus(); }, []);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { e.stopPropagation(); onClose(); return; }
      if (e.key === 'Tab') trapTab(e, panelRef.current);
    };
    document.addEventListener('keydown', onKey, true);
    return () => document.removeEventListener('keydown', onKey, true);
  }, [onClose]);
  const { branch, franchise, partNumber } = partKey;
  return (
    <div className="fixed inset-0 z-50 bg-black/30" data-testid="part-panel-backdrop"
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div ref={panelRef} role="dialog" aria-modal="true" aria-labelledby={titleId} tabIndex={-1}
        data-testid="part-panel"
        className="absolute inset-y-0 right-0 flex w-full max-w-[920px] flex-col gap-3 overflow-y-auto bg-bg p-5 shadow-xl">
        <div className="flex items-center justify-end gap-2">
          <Link to={partPath(branch, franchise, partNumber)} className="text-[13.5px] font-semibold text-accent-2 hover:underline">
            Open full page
          </Link>
          <Button ref={closeRef} onClick={onClose}>Close</Button>
        </div>
        {!row || !data.computed ? (
          <>
            <h2 id={titleId} className="text-[18px] font-black text-ink">{partNumber}</h2>
            {branchMissing || notInBranch
              ? <Banner tone="low" title={branchMissing
                ? `Branch ${branch} isn't in this morning's published data.`
                : `Part ${partNumber} (${franchise}) isn't in Branch ${branch}'s data.`} />
              : <LoadState data={data} what="the part" />}
          </>
        ) : (
          <PartContent key={JSON.stringify([branch, franchise, partNumber])} readOnly titleId={titleId}
            partKey={partKey} row={row} months={data.computed.months} data={data} source={source}
            reauthenticate={reauthenticate} today={centralToday(now ? now() : new Date())} />
        )}
      </div>
    </div>
  );
}
```

`trapTab` goes in the same file: on Tab, collect `a[href], button:not([disabled]), input, select, [tabindex="0"]` inside
the panel; Shift+Tab on the first moves to the last and Tab on the last to the first (`e.preventDefault()`). Check
whether `Button` forwards `ref`; if it doesn't, add `forwardRef` or render a ref-holding wrapper as `JdPartPanel` does
(read how it focuses its Close button and follow that).

- [x] **Step 5: Run** the new tests and `npx vitest run src/pages/__tests__/PartPage.test.tsx` → PASS.

- [x] **Step 6: Commit**

```bash
git add src/pages/part/PartContent.tsx src/pages/part/PartDetailsPanel.tsx src/pages/PartPage.tsx src/pages/part/__tests__/PartDetailsPanel.test.tsx
git commit -m "Plan Q task Q1: PartContent shared with the part page; PartDetailsPanel, look only"
```

---

### Task Q2: `PartLink` and the provider

**Files:**
- Create: `src/pages/part/PartPanelContext.tsx`
- Modify: `src/ui/AppShell.tsx` (wrap `<Outlet />` in `<PartPanelProvider>`)
- Test: `src/pages/part/__tests__/PartLink.test.tsx`

- [x] **Step 1: Write the failing tests**

```tsx
const KEY = { branch: '1', franchise: 'MC', partNumber: 'MC-OOS-1' };

function renderLink(withProvider = true) {
  const page = (
    <><PartLink partKey={KEY}>MC-OOS-1</PartLink><button>Other</button></>
  );
  render(
    <TestRouter initialEntries={['/reorder']}>
      <Routes>
        <Route path="/reorder" element={withProvider ? <PartPanelProvider source={createMockSource()}>{page}</PartPanelProvider> : page} />
        <Route path="*" element={<Where />} />
      </Routes>
    </TestRouter>,
  );
}

describe('PartLink', () => {
  it('keeps the part page as its href', () => {
    renderLink();
    expect(screen.getByRole('link', { name: 'MC-OOS-1' })).toHaveAttribute('href', '/part/1/MC/MC-OOS-1');
  });

  it('a plain click opens the panel and stays on the page; Close gives focus back to the link', async () => {
    const user = userEvent.setup();
    renderLink();
    await user.click(screen.getByRole('link', { name: 'MC-OOS-1' }));
    expect(await screen.findByRole('dialog')).toBeInTheDocument();
    expect(screen.queryByTestId('where')).toBeNull();
    await user.click(screen.getByRole('button', { name: 'Close' }));
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.getByRole('link', { name: 'MC-OOS-1' })).toHaveFocus();
  });

  it('a Ctrl-click is left to the browser (no panel)', async () => {
    const user = userEvent.setup();
    renderLink();
    await user.keyboard('{Control>}');
    await user.click(screen.getByRole('link', { name: 'MC-OOS-1' }));
    await user.keyboard('{/Control}');
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('with no provider it is a plain link', async () => {
    const user = userEvent.setup();
    renderLink(false);
    await user.click(screen.getByRole('link', { name: 'MC-OOS-1' }));
    expect(screen.getByTestId('where')).toHaveTextContent('/part/1/MC/MC-OOS-1');
  });

  it('a click stops at the link, so a row click handler beneath does not fire', async () => {
    const onRow = vi.fn();
    const user = userEvent.setup();
    render(
      <TestRouter initialEntries={['/reorder']}>
        <PartPanelProvider source={createMockSource()}>
          <div onClick={onRow}><PartLink partKey={KEY}>MC-OOS-1</PartLink></div>
        </PartPanelProvider>
      </TestRouter>,
    );
    await user.click(screen.getByRole('link', { name: 'MC-OOS-1' }));
    expect(onRow).not.toHaveBeenCalled();
  });

  it('leaving the page closes the panel', async () => { /* navigate with Open full page: no dialog at /part/... */ });
});
```

(Fill the last test: click "Open full page", expect `where` to show the part path and no dialog.)

- [x] **Step 2: Run them to see them fail.**

- [x] **Step 3: Implement**

```tsx
// Part links open the part in a panel over the page (Plan Q): PartPanelProvider, in the app shell, holds which part is
// open; PartLink keeps its real href, so a new tab, Ctrl-click and middle-click still reach the full page. With no
// provider (a page rendered alone) it's a plain link. Opening another part while one is open replaces it (Other
// branches inside the panel), and Close gives focus back to the link that first opened it.
interface PartPanelApi { open(partKey: PartKey, opener: HTMLElement | null): void }
const PartPanelContext = createContext<PartPanelApi | null>(null);

export function PartPanelProvider({ children, source, reauthenticate, now }: {
  children: ReactNode; source?: DataSource; reauthenticate?: () => Promise<void>; now?: () => Date;
}) {
  const [partKey, setPartKey] = useState<PartKey | null>(null);
  const opener = useRef<HTMLElement | null>(null);
  const { pathname } = useLocation();
  useEffect(() => setPartKey(null), [pathname]);
  const api = useMemo<PartPanelApi>(() => ({
    open(key, el) {
      setPartKey((cur) => {
        if (cur === null) opener.current = el;
        return key;
      });
    },
  }), []);
  const close = useCallback(() => {
    setPartKey(null);
    opener.current?.focus();
    opener.current = null;
  }, []);
  return (
    <PartPanelContext.Provider value={api}>
      {children}
      {partKey && <PartDetailsPanel partKey={partKey} onClose={close} source={source} reauthenticate={reauthenticate} now={now} />}
    </PartPanelContext.Provider>
  );
}

export function PartLink({ partKey, children, className, title }: {
  partKey: PartKey; children: ReactNode; className?: string; title?: string;
}) {
  const panel = useContext(PartPanelContext);
  const { branch, franchise, partNumber } = partKey;
  const onClick = (e: MouseEvent<HTMLAnchorElement>) => {
    e.stopPropagation();
    if (!panel || e.button !== 0 || e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) return;
    e.preventDefault();
    panel.open(partKey, e.currentTarget);
  };
  return (
    <Link to={partPath(branch, franchise, partNumber)} className={className} title={title} onClick={onClick}>
      {children}
    </Link>
  );
}

/** Opens a part from something that isn't a link (a clickable row); navigates when there's no provider. */
export function useOpenPart(): (partKey: PartKey, opener?: HTMLElement | null) => void {
  const panel = useContext(PartPanelContext);
  const navigate = useNavigate();
  return (k, el = null) => (panel
    ? panel.open(k, el)
    : navigate(partPath(k.branch, k.franchise, k.partNumber)));
}
```

Note: `setPartKey` updater with a side effect runs twice under StrictMode harmlessly (same `el`), but set the opener
outside the updater if a reviewer prefers: keep a `partKeyRef`. In `AppShell.tsx`, wrap the `<Outlet />`:
`<PartPanelProvider><Outlet /></PartPanelProvider>`.

- [x] **Step 4: Run** the new tests and `npx vitest run src/__tests__/shell.test.tsx src/ui` → PASS.

- [x] **Step 5: Commit**

```bash
git add src/pages/part/PartPanelContext.tsx src/ui/AppShell.tsx src/pages/part/__tests__/PartLink.test.tsx
git commit -m "Plan Q task Q2: PartLink and PartPanelProvider (a part link opens the panel, the page stays)"
```

---

### Task Q3: Every part link

**Files (each `<Link to={partPath(...)}>` becomes `<PartLink partKey={{ branch, franchise, partNumber }}>`, same
className and title):**
- Modify: `src/pages/ReorderPage.tsx:1353`, `src/pages/transfers/TransferStep.tsx:202`, `src/pages/TransfersPage.tsx:250`,
  `src/pages/TransferOrderPage.tsx:664`, `src/pages/returns/ReturnLinesTable.tsx:122`,
  `src/pages/cleanup/CheckResultsPage.tsx:377`, `src/pages/cleanup/MinimumsPage.tsx:201`,
  `src/pages/SpecialStatusesPage.tsx:176`, `src/pages/rules/TryItPanel.tsx:153`, `src/pages/part/OtherBranches.tsx:172`
- Modify: `src/pages/PartLookupPage.tsx:236-250`: the row's `onClick={() => navigate(to)}` becomes
  `onClick={(e) => openPart(key, e.currentTarget)}` with `useOpenPart`; its link a `PartLink`.
- Modify: `src/pages/OneTimeOrderPage.tsx` and the components that render its lines and the Order page's lines
  (`src/pages/OrderPage.tsx`; find with `grep -n "partNumber" `): where a part number is shown as text on a line, wrap it
  in `PartLink` with that line's branch and franchise. A line whose part isn't in the branch's data gets the panel's
  "isn't in Branch N's data" message.
- Change the Reorder link's title "Open the part page" to "Part details".
- Test: the pages' test files, and `src/pages/__tests__/partPanelPages.test.tsx` (new)

- [x] **Step 1: Write the failing test**, one case per screen, each rendering the page inside
`PartPanelProvider` with the mock source:

```tsx
it.each([
  ['Recommended Reorder', '/reorder?branch=1', ReorderPage, 'MC-OOS-1'],
  ['Transfers', '/transfers', TransfersPage, /* a part the mock lists */ ''],
  ['Cleanup check', '/cleanup/superseded-stock', () => <CheckResultsPage builtIn="superseded-stock" />, 'MC-SS-1'],
  ['Minimums', '/cleanup/minimums', MinimumsPage, 'MC-MINIGN-1'],
  ['Part Lookup', '/lookup?q=MC-OOS', PartLookupPage, 'MC-OOS-1'],
  ['Special statuses', '/special', SpecialStatusesPage, /* a part the mock lists */ ''],
])('%s: a part number opens the panel', async (_, path, Page, part) => {
  // render at path inside TestRouter + PartPanelProvider; click the link named `part`; expect the dialog named part.
});
```

Fill in the real parts from each page's own test file, and add One-Time, Order page, Returns and transfer order lines
the same way (they need a draft or a saved row: reuse those test files' setups, or put those cases in those files).

- [x] **Step 2: Run to see them fail** (the links navigate, no dialog).

- [x] **Step 3: Replace the links**, screen by screen. Tests that expect a link's `href` keep passing (PartLink keeps
it). Tests that render a page alone keep navigating (no provider).

- [x] **Step 4: The order-in-progress test** in `partPanelPages.test.tsx`:

```tsx
it('Reorder, Transfers step: tick 3, open a part, close: still 3 ticked, no leave question', async () => {
  // ReorderPage inside PartPanelProvider at step 1; tick 3 rows; note the save button "Save 3 transfers"; click a
  // part link; expect the dialog and no "Leave this page?"; press Escape; expect no dialog, "Save 3 transfers" still
  // there and the 3 boxes still ticked; click "Open full page"-free path: the leave question still appears on a
  // real link (the Order step's Non-JD ordering crumb or a <Link to="/orders"> rendered beside the page).
});
```

- [x] **Step 5: Run** `npx vitest run src/pages src/__tests__`, tsc, lint. Fix tests that clicked a part link and
expected to land on the part page *inside the shell* (with the provider now in `AppShell`): make them use the link's
href, or Open full page. Name each changed test in the commit body.

- [x] **Step 6: Commit**

```bash
git add <the pages and tests changed, by name>
git commit -m "Plan Q task Q3: every part number opens the panel (One-Time and Order lines gain links)"
```

---

### Task Q4: 0.15.1, click-through, try-it notes

**Files:** `package.json`, `package-lock.json`; create `src/__tests__/clickThrough0151.test.tsx`; create (data-projects)
`projects/part order tool - app/for-users/0.15.1-try-it.md`.

- [x] **Step 1: Click-through** (setup as `clickThrough0150.test.tsx`), through the real shell and routes: Recommended
Reorder → Transfers, tick 3, click a part number: panel with Detail and History, no Settings; History tab; Other
branches: click another branch, the panel switches to it (no navigation); Escape: back on Transfers, 3 still ticked, no
leave question; click a part, Open full page: "Leave this page?" appears (the guard still guards), Stay; the panel is
gone or still open as the provider decides, and the ticks remain. Then `package.json` version `0.15.1` as 0150 checks.

- [x] **Step 2: Run the full suite** in two halves (`npx vitest run src/pages`; the rest), tsc, lint.

- [x] **Step 3: Try-it notes** for Brian and Ben (the 0.15.0 note's style, saying exactly where to click): Ben's own
example, Seminole → Recommended Reorder → Transfers → tick 3 → click a part number → look at History → Close → still 3
ticked. Then Other branches inside the panel; Open full page and its question; right-click → open in new tab; a part
on a One-Time line; a part in Cleanup. Look for: is the panel wide enough; is Settings missing from it a problem.

- [x] **Step 4: Commit both repos.**

---

### Task Q5: Release (with Brian)

- [x] Brian's try-it on mock.
- [x] `npm run build`; dist checks (version 0.15.1, the commit, the SharePoint site id, no mock data); upload to
  `~/nonjd-order-deploy/dist` on 10.110.100.13; Brian installs (the six sudo steps).
- [x] Real test: Brian follows Ben's example on Seminole in the real app, on an order he doesn't save.
- [x] Docs: guide + walkthrough (regenerate both .docx: `node guide.js`, `node walkthrough.js`), FUTURE-IDEAS (F11 done),
  this plan's and the spec's status, memory. Then the F12 reason-code design for Brian and Ben.
