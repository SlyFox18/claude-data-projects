# SPI Parts Hub: part details in a side panel, without leaving the page (design)

> **Status:** design approved by Brian, 2026-11-05. Plan: `docs/superpowers/plans/2026-11-05-spi-parts-hub-part-details-panel.md` (Plan Q).
> **Shipped 2026-11-05:** app 0.15.1 (commit `ca5f16e`) on Fedora; Brian's real test on Seminole passed. Departures from
> this design are in the plan's Shipped block (Open full page closes the panel first; Return wizard links added).
> **Origin:** Ben, 2026-11-05 (via Brian): on an order in progress (e.g. Recommended Reorder → Transfers, 3 of 156
> ticked), clicking a part number to check it asks "Leave this page?"; he wants to see the part and come back without
> losing his work.

## Decisions (Brian, 2026-11-05)

| # | Decision |
|---|---|
| Q-D1 | **Everywhere:** every in-app part number link opens the panel (one behaviour to learn). |
| Q-D2 | **Look only:** Detail, History, Other branches; no Settings tab (a change mid-order would move the order's own numbers). Settings stays on the full page. |
| Q-D3 | **The leave warning stays** for real navigation (Open full page, the menu); the panel isn't navigation, so it never asks. |

## Behaviour

- Clicking a part number opens a **side panel** over the right of the screen; the page underneath stays mounted, so
  ticks, quantities, steps and scroll are unchanged.
- Panel: part number and description, branch, then the part page's Detail, History and Other branches (look only).
  **Close** (button, Esc, a click outside) returns focus to the link that opened it. **Open full page** navigates to
  the part page (and there the page's own leave warning applies).
- Other branches inside the panel switch the panel to that branch (no navigation).
- Ctrl/Cmd-click, middle-click and "open in new tab" still open the full part page in a new tab (the link keeps its
  `href`).
- Screens: Reorder (both steps), Transfers and transfer orders, Returns/Scrap lines, Cleanup results and Minimums,
  Part Lookup, Special statuses, rules Try it, Other branches on the part page. One-Time lines and the Order page show
  part numbers as plain text today; they gain the link. **Not Inventory:** JD parts have no part page, and its reports
  already open their own record panels without leaving the page.
- Accessibility: a dialog with a label, focus moved in and trapped, Esc closes, focus restored.

## Build

- A shared `PartLink` (renders the `Link` with `href`; a plain click opens the panel through a page-level provider) and
  a `PartDetailsPanel` that reuses the part page's tab components with `readOnly` (Settings hidden) and loads the part
  the way the page does (same cached data).
- The part page itself is unchanged apart from sharing its pieces.

## Checks and release

- Vitest per screen: the link opens the panel, the page state is kept, Esc/Close restore focus, modified clicks keep
  the href; the panel's tabs; Other branches switching.
- Click-through on mock: Reorder → Transfers, tick 3, open a part, close, still 3 ticked and no leave prompt.
- Try-it notes; release app 0.15.1 to Fedora only.
