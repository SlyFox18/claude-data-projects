# Report Org Apps: Design (2026-10-08)

**Goal:** Users reach production reports only through a **Fabric org app**, one per report workspace. The workspaces (RP - Financial / Service / Parts Reports) become **authoring-only**. Financial goes first, then Service, then Parts. Each workspace follows the same steps.

**Approved by Brian, 2026-10-08.** Source data: `docs/architecture/report-apps-access-inventory.md`.

## Decisions

| Topic | Decision |
|---|---|
| App type | **Org app** (a Fabric item), not a classic workspace app. There is no publish step: report deploys appear in the app immediately. Sandbox remains the review gate. |
| How it's built | In the Fabric UI. fabric-cicd 1.3.0 can't deploy OrgApp items, and managing them as code isn't worth it while they rarely change. |
| Access | One **Entra security group** per app (`PBI - Financial Reports`, `PBI - Service Reports`, `PBI - Parts Reports`), owned by Brian. People are added or removed in the group; the app is never edited for membership. |
| Financial members | Ben Hill, Jeff Coffman, Mary Hobson, Gery Straley: the same 4 as today. |
| Permissions | View only: no Build permission, no reshare, "Access to hidden content" off. |
| Workspace roles | Brian Admin; **Ben Hill Admin as backup**; SPN-Fabric-CICD-Deploy and SPN-Fabric-Refresh-Automation Contributor. Every other user role is removed. |

## Financial app

- **Name:** "Financial Reports". Created with **New → Org app** in RP - Financial Reports.
- **Content:** 60+ Days Past Due, which is also the landing page.
- **Branding:** SPI logo and theme colour.
- **Audience:** "Financial users" = the group `PBI - Financial Reports`.

## Switch order (nobody is locked out at any point)

1. **Brian** creates the group in the Entra admin center and adds the 4 members.
2. **Brian** creates the org app, adds the report, and puts the group in the audience.
3. **Claude** checks through the API that the group has access to the org app, the report and the semantic model.
4. **Brian** sends the 4 users the app link.
5. **Brian** changes the workspace roles: Ben to Admin; remove Jeff, Mary and Gery. If any step fails, Claude can make the role changes through the Fabric API.
6. **Claude** confirms the final roles through the API. **One user** (e.g. Gery) confirms they can open the app.

## What users notice

- **The workspace disappears from their view.**
- **Existing report links and bookmarks still work**, because org app members can open included items by direct link.
- **Their subscriptions keep working**, because they keep read access through the org app.

## Effect on deployments

- **None for updates.** Deploy reports updates items in place, and the org app shows them immediately.
- **New rule:** when a *new* report goes live in a workspace, it must also be added to that workspace's org app. This goes in the operations guide.

## Repeat for Service and Parts

- **Same six steps.** The Service group gets today's 7 viewers.
- **Parts:** the existing test org app ("Parts Department - Reports") is replaced. It is deleted only with Brian's explicit OK.
- **Per workspace:** decide whether anyone keeps Contributor (by default, no).

## Out of scope

- Org apps as code (CI-deployed).
- Row-level security.
- Multiple audiences per app. These can be added later without changing the pattern.
