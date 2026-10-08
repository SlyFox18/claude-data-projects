# Report Apps: Access Inventory (2026-10-07)

> **Financial done (2026-10-08):**
> - Org app "Financial Reports" (`5c4a400b-0443-484e-9b47-e0640491e32f`), with one audience "Financial users" (`6cd4b087-…`) and hidden content off.
> - Group `PBI - Financial Reports` (`dd0f6315-22fc-4ce8-ab1f-7ac984525750`) holds Ben, Jeff, Mary and Gery, and has Read on the model.
> - Workspace roles are now: Brian Admin, **Ben Admin (backup)**, 2 SPNs Contributor. Jeff, Mary and Gery were removed.
> - Users emailed the app link.
> - Pattern written up in fabric-workspace-docs `OPERATIONS-GUIDE.md` → "Report Org Apps".
> - **Next: Service, then Parts.**

**Goal (Brian, 2026-10-07):**
- Users reach reports only through a Power BI **app**, one per workspace.
- The three report workspaces become **authoring-only**.
- Build order: **Financial** first, then Service, then Parts.
- The existing "Parts Department - Reports" app was a test and has never really been used, so it can be redone.

This is a read-only snapshot taken from the Fabric API. Nothing was changed.

## Who has workspace access today

| Person | Financial | Service | Parts |
|---|---|---|---|
| Brian Fox | Admin | Admin | Admin |
| Ben Hill | Contributor | Contributor | Contributor |
| Jeff Coffman | Contributor | Viewer | Viewer |
| Mary Hobson | Contributor | — | — |
| Gery Straley | Viewer | Viewer | Viewer |
| Adam Bray | — | Viewer | — |
| Bryant Butchee | — | Viewer | — |
| Casey Hurst | — | Viewer | — |
| Kurt Hurst | — | Viewer | — |
| Tommy Knight | — | Viewer | — |
| Barry Sheets | — | — | Viewer |
| Curt Summers | — | — | Viewer |
| Shannon Brooks | — | — | Viewer |
| SPN-Fabric-CICD-Deploy | Contributor | Contributor | Contributor |
| SPN-Fabric-Refresh-Automation | Contributor | Contributor | Contributor |

- Every grant is to an **individual user**; no security groups are used.
- **Apps:** only RP - Parts Reports has one ("Parts Department - Reports"). Financial and Service have none.

## Not yet known (needs admin rights or the Power BI UI)

1. **Direct report shares.** People can be given access to a single report without a workspace role.
2. **App audiences.** Who the Parts app is currently published to.
3. **Usage.** Who actually opened which report in the last 30–90 days.
4. **Subscriptions.** Users' email subscriptions on these reports, which would need recreating in the app.

All four can be read with the Power BI **admin** APIs. My login gets "unauthorized" for those today. Alternatively, Brian can check each in the UI:
- **Manage permissions** on each report;
- the app's **Audience** tab;
- the workspace's **Usage metrics report**;
- **Subscriptions** under each report.

## Proposed target pattern (for discussion)

- **Workspace roles:** Brian (Admin), the two service principals (Contributor), and one **backup admin**, so nobody is locked out if Brian is away. Everyone else comes off the workspace.
- **Readers:** an **Entra security group** per workspace, for example `PBI - Financial Reports Users`, added to the app audience. Adding or removing a person is then a group change, with no app republish.
- **Builders:** if someone needs Analyze in Excel or to build their own visuals, give the app audience **Build** permission rather than a workspace role.
- **Cutover per workspace:**
  1. build and publish the app;
  2. add the group to the audience;
  3. send users the app link;
  4. after a few days, remove the user roles from the workspace.
- **Every report deploy then ends with Update app.** We already do that.
