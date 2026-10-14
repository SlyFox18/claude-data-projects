# Parts Lookup — Frontend Rebuild — Design Spec

**Date:** 2026-08-18
**Author:** Brian Fox
**Status:** Approved for implementation planning

---

## 1. Problem Statement

The automated static-file refresh pipeline (`2026-08-14-parts-lookup-refresh-pipeline-design.md`) is live and running — `InMaster_PartsLookup_Raw` refreshes hourly during business hours and partition files land in SharePoint on the same cadence. That pipeline replaces the costly Fabric SQL Database backend, but the existing `parts-lookup-app` React app still talks to that database directly, via Rayfin's Fabric-brokered auth and a live `mssql` data service. This spec covers rebuilding the frontend to read from the new static files instead, and to run independently of Fabric App infrastructure entirely, so it can be piloted from Brian's own computer before eventually moving to an IT-provided machine.

The existing UI (search box, sortable results table, home-branch prioritization, "Data as of" freshness note) is already built and validated — this is a plumbing swap underneath it, not a redesign.

---

## 2. Scope

### In scope
- Replacing Rayfin's Fabric-brokered auth (`@microsoft/rayfin-auth-provider-fabric`) with standalone Entra ID sign-in via MSAL.js
- Replacing the live `client.data.PartLocation...` query with a Microsoft Graph API read against the SharePoint partition files
- Restricting sign-in to a small pilot group via Entra app assignment
- Removing the app's dependency on Rayfin's `auth`, `data`, and `staticHosting` services entirely
- A small addition to the already-shipped refresh pipeline (`run_refresh.py`, in the `data-projects` repo): write a single `_meta.json` file with a generation timestamp, alongside the partition files
- Hosting the built app from Brian's computer via a lightweight local static server, exposed to pilot testers over a real HTTPS URL via a tunnel service (e.g. Cloudflare Tunnel)

### Out of scope
- Any change to the existing search/table/sorting UI itself (`HomePage.tsx`'s presentation layer stays as-is)
- Decommissioning the currently-deployed Fabric App (`*.fabricapps.net`) — it's simply left alone, unmaintained, on its last build. A separate, deferred decision.
- Moving hosting to the eventual IT-provided machine (same build artifact, different host — a later, separate step)
- Any change to the refresh pipeline's extract/partition/upload logic beyond the `_meta.json` addition

---

## 3. Architecture

- The app remains a Vite + React 19 SPA. `HomePage.tsx` is unchanged except for what it calls to fetch data.
- All three Rayfin backend services (`auth`, `data`, `staticHosting`) are removed from `rayfin.yml` / the app's dependency on them. The app becomes a plain static SPA with two external integration points: Entra ID (sign-in) and Microsoft Graph (data reads).
- The currently-deployed Fabric App keeps running on its last-published build — this repo simply stops deploying to it. No active decommissioning as part of this work.
- **Hosting:** `npm run build` output is served by a lightweight Node static server (e.g. the `serve` package) running on Brian's computer, exposed to pilot testers via a Cloudflare Tunnel (or equivalent), which provides a real trusted HTTPS URL without certificate management or firewall changes. This is explicitly temporary, throwaway infrastructure — what actually moves to an IT-provided machine later is the built static files and the build command, not this server setup.

---

## 4. Auth

- A new Entra ID App Registration (SPA platform type), separate from the service principal used by the backend refresh pipeline (that one is app-only/client-credentials; this one needs interactive user sign-in).
- Redirect URIs: the Cloudflare Tunnel's HTTPS URL, plus `localhost` for local development.
- `@azure/msal-browser` and `@azure/msal-react` replace `@microsoft/rayfin-auth-provider-fabric`.
- The existing `IAuthService` contract (`signIn`, `signOut`, `getCurrentUser`, `initEmbeddedAuth`) is preserved — a new `EntraAuthService` implements it. `MockAuthService` (local dev) is unaffected.
- The app registration requires assignment. Pilot testers (or a security group containing them) are assigned directly in Entra — sign-in is blocked at Microsoft's own login screen for anyone not assigned, with no allowlist logic to maintain inside the app.
- After sign-in, the app acquires a delegated Microsoft Graph token (`Files.Read`, scoped to the same SharePoint site the backend pipeline already writes to) via MSAL's silent-token-acquisition flow.

---

## 5. Data Fetching

- Given a search term, the app computes the same 2-char `PartNumber` prefix that `partition.py` uses to name files (ported to TypeScript — must stay in sync with `partition.py`'s `safe_prefix()`).
- The app acquires a Graph delegated token (silently renewed by MSAL as needed) and fetches:
  `GET https://graph.microsoft.com/v1.0/sites/{site-id}/drives/{drive-id}/root:/{prefix}.json:/content`
  with an `Authorization: Bearer <token>` header. `{site-id}` and `{drive-id}` are already-known real values — the same ones resolved during the backend pipeline's Task 2 (SharePoint IDs) and stored in that project's `.env` — not new discovery work for this rebuild.
- **Why Graph API and not a direct SharePoint URL:** the validated prototype's browser test worked by riding the browser's existing SharePoint session cookie (the DevTools console was already on a SharePoint page). That doesn't hold for an app hosted on its own origin — a plain `fetch()` straight to `spitractor.sharepoint.com` from a different origin would hit CORS. Microsoft Graph is built to support exactly this pattern (an SPA calling Graph with a bearer token), so reads go through Graph instead.
- The returned rows are filtered client-side for an exact `PartNumber` match (case-insensitive, matching the existing UX where the search box already uppercases input).
- **Freshness display:** the refresh pipeline (`run_refresh.py`, in `data-projects`) is extended to write one additional small file per run — `_meta.json`, containing a single `generatedAt` timestamp — uploaded alongside the partition files. The frontend fetches this once per session (cached) and displays it as "Data as of {timestamp}," replacing the old per-row `lastRefreshed` column from the SQL database (which was never really meaningful per-row anyway, since every row already came from a single extraction moment).

---

## 6. What Stays the Same

- `HomePage.tsx`'s presentation: search input, sortable results table, home-branch highlighting via `localStorage`, column layout.
- `App.tsx`'s routing and `AuthGuard` pattern.
- `MockAuthService` for local development.
- The `IAuthService` interface contract.

## 7. What Changes

- `RayfinAuthService` → `EntraAuthService` (MSAL-based).
- `rayfinClient.ts` / `client.data.PartLocation...` calls → a new data-fetching service that calls Microsoft Graph directly.
- `rayfin.yml`'s `auth`, `data`, and `staticHosting` services are disabled/removed; the `rayfin/data/` entity definitions (`PartLocation.ts`, `schema.ts`) are no longer needed once the mssql data service is gone.
- `bootstrap.ts` is updated to wire up MSAL instead of the Rayfin client.
- Deployment: `npm run build` output is served locally instead of via `rayfin up staticapp deploy`.

---

## 8. Testing / Validation Plan

- Confirm a non-assigned test account is genuinely blocked at sign-in (validates the Entra app-assignment restriction works, not just that it's configured).
- Confirm a real Graph API delegated-token fetch succeeds end-to-end from the app's actual hosted origin (the Cloudflare Tunnel URL) — this validates the CORS assumption for real, since the prototype never tested a genuinely cross-origin fetch.
- Confirm the Cloudflare Tunnel URL stays reachable and stable across the local computer sleeping, restarting, or losing network briefly.
- Side-by-side spot check: run the same part number search against the currently-deployed Fabric App and the new app, confirm identical results (accounting for any difference in refresh timing between the two backends).
- Confirm the "Data as of" timestamp displays correctly and updates after a real pipeline refresh cycle.

---

## 9. Related Work

- **`2026-08-14-parts-lookup-refresh-pipeline-design.md`** — the automated backend this frontend now reads from. That pipeline is complete and running; this spec's only change to it is the `_meta.json` addition (Section 5).
- **`2026-08-14-parts-lookup-static-file-prototype-design.md`** — validated the partitioned-JSON-file approach and read latency; its browser test's session-cookie-based read is what this spec's Graph API approach replaces for the real deployed app.
- **`project_parts_lookup_tool` memory** — full incident history and architecture evaluation that led to this whole project.
- **`parts-lookup-app` repo** — where the actual frontend code changes happen (this spec lives in `data-projects` alongside its sibling specs for document-trail consistency, per this project's established pattern).
