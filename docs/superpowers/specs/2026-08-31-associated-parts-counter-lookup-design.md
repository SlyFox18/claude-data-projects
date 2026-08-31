# Associated Parts — Counter Lookup Feature Design

## Overview

Adds "frequently bought together" recommendations to the existing **Parts
Availability** app (`parts-lookup-app` repo) — the same tool parts counter
staff already use to check branch availability, now also live-rolling-out to
the parts department company-wide. A counter employee looks up a part
number and sees, alongside its availability, which other parts most
commonly sell with it — enabling a real upsell prompt ("customers who buy
this also buy...") at the point of a live customer interaction.

**Why this exists:** the Power BI "Associated Parts" report (see
`docs/superpowers/specs/2026-08-27-associated-parts-design.md` and its
implementation plan) proved the underlying market-basket analysis produces
genuinely useful, business-sensible recommendations — but its intended
audience (parts counter staff) has no Power BI license and won't for the
foreseeable future. This feature delivers the same underlying data
(`Fact_PartAssociation`) through infrastructure that's already licensed,
already deployed, and already installed on every relevant device: the
existing Parts Availability app's static-file/no-live-database
architecture.

**Two-repo scope, same as the rest of this feature's history:**
- `data-projects` (this repo) — a new export step producing a JSON file
  from `Fact_PartAssociation`, uploaded to the same SharePoint
  site/drive the Parts Availability app already reads from.
- `parts-lookup-app` (separate repo, `C:\Users\bfox\Documents\Git-Projects\parts-lookup-app`)
  — the app-side feature: a new data-fetch function and UI component.

## Data Pipeline (data-projects)

**Source:** the already-live `Fact_PartAssociation` Lakehouse table (built
weekly by `Fact_PartAssociation_Build.ipynb` — see that notebook and its
design/plan docs for how the table itself is computed; this feature adds a
new consumer of that table, not a new computation of the underlying
association logic).

**Grain change for this export:** the counter tool has no use for a
franchise breakdown — that's an internal modeling detail from the Power BI
side, not something a parts-counter recommendation needs. The export
collapses `Fact_PartAssociation` from `(Franchise, PartA, PartB)` down to
one row per `(PartA, PartB)`:
1. Sum `CoOccurrenceCount` across franchises for each `(PartA, PartB)` pair.
2. Sum `AnchorInvoiceCount` across franchises for each distinct `PartA`
   (de-duplicated first, same logic as the `Anchor Invoices` DAX measure —
   this value is a repeated value across every `PartB` row for the same
   `PartA` in the source table, not something to sum naively per-row).
3. Sum `AssociatedInvoiceCount` across franchises for each distinct `PartB`
   (same de-duplication approach, keyed on `PartB`).
4. Sum `TotalInvoiceCount` across franchises (one value, company-wide).
5. Compute `ConfidencePercent = CoOccurrenceCount / AnchorInvoiceCount`,
   `BaselinePercent = AssociatedInvoiceCount / TotalInvoiceCount`,
   `Lift = ConfidencePercent / BaselinePercent` as **plain numeric fields
   baked into the export** — there is no live DAX engine on the client
   side, so these must be pre-computed, not left for the app to derive.
6. Join `PartB`'s `Description` from `dim_Parts` so the app never needs a
   second lookup just to show a human-readable name.

**Output columns:** `PartA`, `PartB`, `Description`, `CoOccurrenceCount`,
`ConfidencePercent`, `Lift`.

**File format:** a single JSON file (gzip-compressed, matching the existing
app's `.json.gz` convention). **Confirmed via a real run against live data
during planning:** the collapsed export is 44,258 rows across 5,635
distinct `PartA` values, 5.6 MB uncompressed, **718 KB gzipped** — no
partitioning needed at all, dramatically smaller than the 1M+-row
`InMaster` data that required the existing app's 2-char-prefix scheme.
Given the small size and the weekly (not hourly) refresh cadence, the app
fetches and caches this file once per page load rather than re-fetching it
on every search — see App Integration below.

**Refresh cadence:** weekly, immediately following
`Fact_PartAssociation_Build.ipynb`'s own weekly run — either as an
additional cell in that same notebook, or a small follow-on script/notebook
triggered right after it in the same pipeline. Uploads to the same
SharePoint site/drive (`VITE_GRAPH_SITE_ID`/`VITE_GRAPH_DRIVE_ID` in
`parts-lookup-app`'s `.env`) the existing app already reads from — no new
Entra app registration, no new SharePoint site, no new auth flow.

## App Integration (parts-lookup-app)

**New data-fetch function**, `lookupAssociatedParts(partNumber)` in
`dataService.ts`, following `lookupPartNumber()`'s existing shape (acquire
a Graph token, fetch via the same `graphFileUrl()`/`parseGzipJsonResponse()`
helpers), filter to rows where `PartA` matches the searched term, sort by
`CoOccurrenceCount` descending, return the top 10.

**Deliberate difference from `lookupPartNumber()`: cache the whole file in
memory per page load, not fetch-per-search.** `lookupPartNumber()`
intentionally never caches, because that data refreshes hourly and a parts
counter tab realistically stays open all day — a stale cache there would
show wrong availability. This export refreshes weekly, and at 718 KB for
the *entire* dataset, there's no reason to re-fetch it on every single part
lookup throughout the day. Fetch it once (lazily, on first use) and hold it
in a module-level variable; a page reload (which a "Data as of" staleness
banner can prompt the user to do, same as today) picks up the latest
version.

**One shared `AssociatedPartsPanel` component**, rendering a table with
`Description`, `CoOccurrenceCount`, `ConfidencePercent`, `Lift` (same
columns already validated in the Power BI report) — used in two places so
there's no duplicated rendering logic:

1. **Inline** — automatically appended below the existing availability
   table on `HomePage.tsx`, populated from whatever part number the user
   just searched. No new input field, no extra click for the common case.
2. **Standalone view** — a second simple page/route with its own
   part-number input, for looking up "what goes with this" independent of
   an availability check (e.g. a part not carried at the user's branch, or
   a customer asking about upsells for something already known to be in
   stock).

Both call the same `lookupAssociatedParts()` and render the same
`AssociatedPartsPanel` — the two placements are a UI-routing decision, not
two separate features.

**Freshness treatment:** reuse the existing `_meta.json`/staleness-banner
pattern (or a small addition to it) so a stale associated-parts export
doesn't silently show outdated recommendations without the same warning
treatment the availability table already gives users.

**Ranking/filtering for v1:** top 10 by `CoOccurrenceCount` descending, no
`Lift` floor filter. Add a `Lift` floor (e.g. excluding anything below
~1.3) only if real testing surfaces generic/noise parts creeping into
results — don't pre-build the filter speculatively (see Testing below).

## Empty / No-Recommendation State

`Fact_PartAssociation` only keeps pairs with at least 10 shared invoices in
the last 24 months (`MIN_COOCCURRENCE`, see the underlying design/plan) —
so a real, valid, in-stock part can legitimately have **zero** qualifying
associated parts if it's low-volume, new, or just doesn't have a strong
pairing pattern. This is an expected, honest outcome, not an error.

`AssociatedPartsPanel` must show an explicit message in this case, matching
the pattern `HomePage.tsx` already uses for an empty availability search
("No branches found carrying part..."):

> *No frequently-bought-together data available for this part.*

Do **not** render a blank panel (looks broken) or hide the section entirely
(makes the feature seem unreliable — "does this ever work?"). Showing an
explicit message either way (has recommendations / doesn't) keeps this
feature consistent with the rest of the app and makes clear it ran
successfully even when it found nothing.

Deliberately out of scope for v1: distinguishing "this part doesn't exist
at all" from "it exists but has no qualifying pairings" — that would need
extra plumbing (a full parts-existence list) for a distinction that
probably doesn't matter much to a counter person in the moment. A single
generic message covers both cases; revisit only if real Fedora testing
shows it's actually confusing.

## Testing & Rollout

The Parts Availability app is rolling out to the parts department (~70
users, 19 stores) in the next 1-2 days on its production host
(`https://go-parts.spitractor.com`, Windows Server 2016). This feature must
not introduce any risk to that rollout.

1. Build this feature on a feature branch in `parts-lookup-app` — `main`
   and the production Server 2016 deployment are untouched throughout.
2. Deploy that branch's build to the **Fedora fallback server**
   (`https://10.110.100.13`, already running the same app, same Entra auth,
   real data) — safe to iterate on since it isn't the URL being
   rolled out this week.
3. Validate there: try real part numbers, confirm the top-10-by-count list
   reads sensibly without a `Lift` filter (per the Power BI validation,
   e.g. `TY22062` → JD fluids, filters, hydraulic hose/fittings), decide
   whether the `Lift` floor is actually needed, and confirm both the
   inline and standalone placements feel right in practice.
4. Once satisfied, merge to `main` and run the existing `deploy.ps1`
   promotion to the Server 2016 production host — a routine fast-follow
   update, done deliberately *after* this week's initial rollout has
   settled, not during it.

This mirrors the same Dev → Sandbox → Production discipline already used
for the Power BI side of this project, mapped onto this app's own
branch/Fedora/production-server equivalents.

## Open Items (deferred to implementation)

- Whether a `Lift` floor filter is needed — decided from real Fedora
  testing, not assumed here.
- Exact freshness-tracking file for this new export (a separate
  `_meta_associated_parts.json` vs. reusing the existing `_meta.json`) —
  a separate file is likely correct, since this export runs on its own
  weekly schedule, independent of the hourly `PartLocations` refresh that
  owns the existing `_meta.json`; confirmed during implementation.
