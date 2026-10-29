# SPI Parts Hub: a launch page in front of the tools (design)

> **Status:** approved by Brian 2026-10-29 (brainstorm with mockups). Next: implementation plan (Plan H, app 0.8.0).
> **Origin:** Ben's idea F2 in `projects/part order tool - app/FUTURE-IDEAS.md` ("a landing page above the tools"),
> settled before JD ordering or inventory management are built so they slot in rather than being bolted on.

## Goal

The app opens on a **launch page** where each person picks where to go: Shannon picks Non-JD ordering, Barry (later)
JD ordering, anyone can go straight to Cleanup. Inside an area the app works as it does today, but the left nav lists
only that area's screens, so it stops growing with every new tool. The app is renamed **SPI Parts Hub** and carries
the South Plains Implement logo. Areas that aren't built yet show as "Coming later" cards so Ben can see how the whole
tool will look and feel.

## Decisions (Brian, 2026-10-29)

| # | Decision |
|---|---|
| H1 | **The app's own launch page plus links out** (not a portal of separate apps): every area Ben listed lives inside this app on the same data; a row of links goes to the other parts tools. |
| H2 | **The launch page sits in front of today's screens.** Today's Home becomes Non-JD ordering's own Home. |
| H3 | **Inside an area, the nav shows one area at a time:** the logo and name, "‹ All areas" (back to the launch page), an area switcher, then only that area's screens. |
| H4 | **Areas on day one:** Non-JD ordering, Cleanup, Part Lookup (live); JD ordering and Inventory management (greyed out, "Coming later", not clickable). |
| H5 | **Launch cards say what's waiting** for the branch picked at the top of the launch page. |
| H6 | **Name "SPI Parts Hub"; the logo:** the colour logo on the launch page, the white one at the top of the dark nav. |
| H7 | **Today's addresses stay** (approach 1): the launch page takes `/`, today's Home moves to `/non-jd`, every other screen keeps its path and belongs to an area. |

Defaults set in the design (Brian can change them): the app always opens on the launch page; everyone sees every area
(limiting areas by person waits until JD ordering exists); App Settings stays at the bottom of the nav and is also
linked from the launch page.

## The launch page (`/`)

- **Header:** the colour logo (`SPI Logo.png`, from `transfer-app/public/`) and "SPI Parts Hub", a line under it.
- **Greeting and context:** "Good morning, <first name>", "Where do you want to go?", the branch picker (the App
  Settings default branch to start with, as Home today) and the "Data as of …" badge.
- **Area cards** (in this order), each a link to the area's first screen, with an icon, the name and a one-line
  description:

| Card | Description | What's waiting (for the picked branch) | Opens |
|---|---|---|---|
| Non-JD ordering | Reorder, One-Time orders, transfers, rules. | "N parts to order · $X" (amber) and "N could come by transfer" (purple), the same figures as today's Home cards; nothing when 0 | `/non-jd` |
| Cleanup | Things to fix in Equip. | "N minimums with no demand at Branch B": the parts in that branch's reorder file with the flag Cleanup lists (`minimumNoDemand`), so it equals Cleanup filtered to that branch (not Home's "hidden" count, which only covers lines with something to order); nothing when 0 | `/cleanup` |
| Part Lookup | Any part: stock, prices, history, settings. | none | `/lookup` |
| JD ordering | John Deere parts ordering. | "Coming later" tag; greyed, dashed, not a link | — |
| Inventory management | The Corp Parts reports, in the app. | "Coming later" tag; greyed, dashed, not a link | — |

- **Links row:** "Other parts tools: Parts Availability ↗ (https://go-parts.spitractor.com) · Parts reports ↗ (the
  Parts Reports org app)" and App Settings. External links open in a new tab. The Parts Reports app address is a
  build setting (`VITE_LINK_PARTS_REPORTS`); while it is blank the link is left out.
- **Loading and errors:** the counts load as Home's do (this branch's file plus the shared files). While loading, the
  cards show without counts; if the data can't be read, the cards still work and the counts are left out with Home's
  existing error banner.

## Inside an area

- **Nav (top to bottom):** the white logo (`spi-logo.png`) and "SPI Parts Hub"; "‹ All areas" (to `/`); the area
  switcher (a select of the live areas, showing the current one; picking one opens its first screen); the area's
  screens; App Settings at the bottom (as today).
- **Areas and their screens:**
  - **Non-JD ordering:** Home (`/non-jd`, today's Home unchanged), Recommended Reorder (`/reorder`), One-Time Order
    (`/one-time`), Transfers (`/transfers`, incl. transfer order pages), Orders (`/orders`, incl. order pages), Rules
    (`/rules`), Transfer rules (`/transfer-rules`), Special statuses (`/special`).
  - **Cleanup:** Cleanup (`/cleanup`).
  - **Part Lookup:** Part Lookup (`/lookup`) and the part pages it opens.
- **Which area a screen is in** comes from its path (one table: path → area). App Settings (`/settings`) belongs to
  no area: its nav shows "‹ All areas" and the switcher with no screen list.
- **Breadcrumbs and links:** the top bar trail starts with the area ("Non-JD ordering › Recommended Reorder") instead
  of "Home"; every in-app link that pointed to `/` as "Home" (e.g. Home cards, "Back to Home") points to `/non-jd`.

## Names, version, data

- Browser tab title, About, the README and the app's `package.json` description: **SPI Parts Hub**. The app repo
  keeps its name (`nonjd-order-app`) for now.
- **Version 0.8.0.**
- No data, contract, Gold or SharePoint change. The Fedora address stays; a new one comes with the production move
  (1.0.0).
- The logos are copied into the app's `public/` folder.

## Testing

- Launch page: the five cards in order, live ones link to their screens, coming-later ones are not links; the counts
  match Home's for the same branch and change with the branch picker; counts left out (not wrong) while loading or on
  a read error; the links row (Parts Reports hidden when its setting is blank).
- Nav: on every existing path the right area is current and only its screens are listed; the switcher opens another
  area's first screen; "‹ All areas" goes to `/`; `/settings` shows no screen list.
- Every old address still opens the same screen (deep links), and leave-with-ticks questions still fire when leaving
  through "‹ All areas" or the switcher.
- A short mock click-through list for Brian.

## Out of scope

- Building JD ordering or Inventory management (only their cards).
- Per-person areas, remembering the last area, and a new address.
- Moving other apps (Parts Availability) into this one.
