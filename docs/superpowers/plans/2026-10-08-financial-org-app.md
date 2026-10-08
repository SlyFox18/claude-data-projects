# Financial Org App: Implementation Plan

> Spec: `docs/superpowers/specs/2026-10-08-report-org-apps-design.md`. Mostly UI steps (Brian), with API checks (Claude) between them. Service and Parts reuse this plan with the names swapped.

**Goal:** RP - Financial Reports becomes authoring-only. Its 4 users reach 60+ Days Past Due through the org app "Financial Reports", granted through the Entra group `PBI - Financial Reports`.

**IDs:**
- Workspace `67fefa98-9e80-4a79-afdd-c8988b6e64fc`
- Report `3c88348f-4267-44b9-a098-86795fe30eff`
- Model `2516982b-f52f-4676-b879-525e089e9b9e`

---

### Task 1: Create the security group (Brian)

- [ ] Go to https://entra.microsoft.com → **Groups** → **All groups** → **New group**. Fill in:
  - **Group type:** Security
  - **Group name:** `PBI - Financial Reports`
  - **Group description:** `Readers of the Financial Reports org app (RP - Financial Reports).`
  - **Membership type:** Assigned
  - **Owners:** Brian Fox
  - **Members:** Ben Hill, Jeff Coffman, Mary Hobson, Gery Straley
- [ ] Click **Create**. A new group can take a few minutes to appear in Fabric's people pickers.
- [ ] **Claude:** look up the group and its members through Microsoft Graph (read-only) and record the group's object ID here.

### Task 2: Create the org app (Brian)

- [ ] In **RP - Financial Reports**, go to **+ New item** → **Org app**. Name it `Financial Reports`.
- [ ] Add **60+ Days Past Due** and make it the landing page.
- [ ] Optionally add the SPI logo and theme colour. **Save**.
- [ ] Open **Manage audiences**. In the default audience (rename it to `Financial users`), add the group `PBI - Financial Reports`. Leave **Share**/reshare and Build **unchecked**. Leave "Access to hidden content" **off**.
- [ ] **Save**, then copy the app link: **Share** → **Copy link**.

### Task 3: Verify access (Claude)

- [ ] The OrgApp item and its audience child item exist in the workspace (Fabric items API).
- [ ] The group has access to the report and the model (Power BI dataset/report users API, or the item's Manage permissions pane, which Brian can screenshot if the API refuses).

### Task 4: Tell the users (Brian)

- [ ] Send Ben, Jeff, Mary and Gery the app link. Explain that their existing report links still work, and that the workspace will disappear from their view.

### Task 5: Change workspace roles (Brian, or Claude through the API)

- [ ] **Manage access** on RP - Financial Reports:
  - Ben Hill: Contributor → **Admin**.
  - **Remove** Jeff Coffman, Mary Hobson and Gery Straley.
  - Leave Brian (Admin) and both service principals (Contributor) as they are.

### Task 6: Confirm (Claude + one user)

- [ ] Workspace roles through the API should be exactly: Brian Admin, Ben Admin, 2 SPNs Contributor.
- [ ] **Gery** (Viewer until now) opens the app link and sees the report with data.
- [ ] Record the results in `docs/architecture/report-apps-access-inventory.md`.

### Task 7: Document the pattern (Claude)

- [ ] fabric-workspace-docs `OPERATIONS-GUIDE.md`: a "Report org apps" section covering the pattern, the group per app, and the rule that **a new report must be added to its org app**.
- [ ] Update memory, and commit both repos.
