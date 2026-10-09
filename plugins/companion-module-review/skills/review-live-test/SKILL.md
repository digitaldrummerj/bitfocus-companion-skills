---
name: review-live-test
description: Live-test a Companion module finding or fix in the user's local Companion. Builds a patched copy of the module outside the review clone, writes an old-format test page with the affected actions, then drives Companion with headless Playwright to import the module package, switch the connection version, import the page and read back each button's action fields. Use when a finding depends on how Companion really behaves (upgrade scripts, option formats, migrations), or to prove a suggested fix works before sending a review.
---

# Live-Test a Module Finding or Fix in Companion

Reproduces a finding, or checks a suggested fix, in the user's real Companion, so neither the review nor the maintainer has to rely on reading code. Proven on biamp-tesira v4.0.0 (C1/C2, 2026-10-08): the bug showed 0 / blank fields and the fix showed 250 / "Custom attribute".

## Guardrails (read first)

- **The review clone is never modified.** All test work happens in a standalone copy under `companion-modules-reviewing/test-pages/` (gitignored): no edits, branches or commits in `companion-modules-reviewing/companion-module-<name>/`. The workspace's report-only rule still applies to the module under review.
- **Companion** is the user's local install at `http://127.0.0.1:8000`. Drive it with the workspace's **headless** Playwright server, `companion-playwright` (defined in the workspace `.mcp.json`: `--headless --isolated`, output in the gitignored `.playwright-mcp/`). Its tools are `mcp__companion-playwright__browser_*`. It opens no window and uses a fresh, extension-free profile on every run, so the LastPass problem below doesn't apply. Don't use the generic `plugin:playwright` server: it opens a visible window.
- **Pages:**
  - Import only onto the user's test page (**75**) or onto an **empty** page: one with nothing but the default page-up, page-number and page-down buttons (page 76 is an example).
  - **Never add a new page.**
  - Never import onto a page with real buttons.
- **Never click Reset configuration** on the Import / Export page, and never delete connections or pages.
- **Fallback only, Claude in Chrome:** use the user's real Chrome only if the headless server is unavailable. In that browser, password managers break automation: with **LastPass** on, a module whose connection settings contain a password field (e.g. biamp-tesira's **Login username** / **Login password**, the device credentials, not a Companion login) gets LastPass icons injected. Those block every click and screenshot ("Cannot access a chrome-extension:// URL of different extension") once the Change Module Version dialog opens. Ask the user to turn LastPass off first, and stop after two failures.
- **File pickers:** in Playwright, `browser_click` the upload button. The page then reports a file-chooser modal state; answer it with `browser_file_upload` and the absolute path. Files must be under the workspace (the server's allowed root).

## Phase 1 — Build the test package

1. **Extract the tag** into a standalone copy:

   ```bash
   cd companion-modules-reviewing
   D=test-pages/<module>-<newVersion>-fix
   mkdir -p $D && git -C companion-module-<module> archive <reviewTag> | tar -x -C $D
   ```

2. **Apply the fix** from the review's **Fix** block. Keep it to the finding(s) under test.
3. **Bump the patch version** in `package.json` (e.g. 4.0.0 → 4.0.1) so Companion shows it as a separate version.
4. **Build:**
   - Reuse the clone's dependencies: `cp -R ../../companion-module-<module>/node_modules $D/` (or run `yarn install`).
   - Run `yarn package`. It produces `<module>-<newVersion>.tgz`.
   - Copy the `.tgz` up to `test-pages/`.
5. **Check before going to Companion:**
   - Type check: `yarn tsc -p tsconfig.build.json --noEmit` (TS modules).
   - For upgrade-script fixes, run the built `dist/upgrades.js` with `node` on the exact options Companion would pass. Companion 5 always passes options wrapped as `{ isExpression: false, value: … }`.
   - Run `yarn test` and note any test that fails *because* of the fix. Report it; don't edit the module's tests.

For a **baseline**, test the unfixed `<reviewTag>` package first (the `.tgz` the validator's `-RunBuild` already produced in the clone), so the user sees the bug and then the fix.

## Phase 2 — Write the test page

Write an importable page holding one button per affected action, built from the **old** module version's action definitions (`git show <oldTag>:<actions file>`), plus one **control** button whose migration doesn't touch the code under test.

Follow **`references/test-page-v10.md`**. It is a Companion 4.2 (format **10**) page export. Companion upgrades it through its own migrations on import, including `v10tov11`, which wraps every option. So the buttons reach the module exactly as an old user's saved config would.

Key fields:

- the connection's `moduleId`;
- `moduleVersionId` set to the version under test;
- `lastUpgradeIndex` = (number of `UpgradeScripts` in the **old** version) − 1. `-1` means none ran yet.

Write it to `test-pages/<module>-<scenario>.companionconfig`.

## Phase 3 — Run it in Companion (headless Playwright)

Load the tools in one ToolSearch call: `select:mcp__companion-playwright__browser_navigate,…browser_snapshot,…browser_click,…browser_type,…browser_press_key,…browser_file_upload,…browser_wait_for,…browser_take_screenshot,…browser_close`. If the server isn't connected, ask the user to approve it with `/mcp` (project servers from `.mcp.json` need a one-time approval).

How to work in Playwright (all proven headless on 2026-10-08):

- Prefer **stable selectors** as the `target` over snapshot refs: `role=button[name="Save"]`, `role=option[name="v4.0.1"]`, `label:has-text("Import configuration")`, `[title="75/0/0"]`. Use `browser_find` (regex search of the accessibility tree) to read values, rather than full snapshots.
- The **What's New in Companion** dialog appears about **2 s after** the first page load of each isolated session. `browser_wait_for` 2 s, then click `role=button[name="Close modal"]` if `browser_find` shows it. It doesn't come back for the rest of the session.
- **Uploads:** `browser_click` on the `label:has-text("…")` (not its inner div), wait for the "[File chooser]" modal state, then `browser_file_upload` with the absolute path.

### A. Import the module package

1. `/modules` → `browser_click` `label:has-text("Import module package")` → `browser_file_upload` the `.tgz`.
2. Check the console log in `.playwright-mcp/`. "Failed to install module … already exists" means that version is already installed. That's fine for a re-test, but a **new** fix iteration needs a new patch version, because Companion won't overwrite an installed version.

### B. Switch the connection version

1. `/connections/<connectionId>`. The id is in the URL after you click the connection on `/connections`.
2. `browser_wait_for` text "Module Version" → click `button[aria-label="Change module version"], button[title="Change module version"]`.
3. Click `role=combobox[name="Version"]` → click `role=option[name="v<version>"]` → click `role=button[name="Save"]`.
4. `browser_find` `/Module Version|v\d+\.\d+\.\d+/` and confirm the connection now shows the new version.

### C. Import the test page

Re-importing re-runs the upgrade scripts on the imported buttons.

1. `/import-export` → `browser_wait_for` "Import configuration" → click `label:has-text("Import configuration")` → `browser_file_upload` the `.companionconfig`. Never click **Reset configuration**.
2. `browser_wait_for` "Destination Page". The destination combobox defaults to page 1 (real buttons): click `role=combobox[name="1 (HOME-1)"]`, then click `role=option[name=/^75 /]` (or the empty page's number; the list holds every page).
3. `browser_find` `/Replace page \d+ with imported page|Link to/`. The button must read **Replace page 75 …** (or your empty page), and the connection behaviour must be **Link to `<connection>`**.
4. Click `role=button[name="Replace page 75 with imported page"]` → `browser_wait_for` "Import successful".

### D. Verify (primary: the UI)

1. `/buttons/<N>` → wait 2 s → click `[title="<N>/0/0"]` (titles are `page/row/column`). The edit panel opens on **Step 1**.
2. `browser_find` the action name and its fields, e.g. `/Start hold level adjustment|textbox "Repeat interval \(ms\)"/`.
   - Textboxes show their value.
   - A combobox shows its selected label. A combobox with **no text** is blank: that's the bare-value symptom.
3. Evidence: `browser_take_screenshot` with target `role=tabpanel[name="Edit Button <N>/0/0"]` and filename `.playwright-mcp/<module>-<version>-<button>.png`.
4. Repeat for every test button, including the control button.
5. Only press buttons if the finding is about execution. With no device attached, a press only shows a connection error; the useful signal is whether Companion logs "Failed to parse action options".

**Optional cross-check (undocumented):** `curl -s "http://127.0.0.1:8000/int/export/page/<N>?format=json"` returns the page as Companion stores it. It's the same internal route the web UI's export button uses, but it isn't a documented API and may change without notice. Use it only as extra evidence. It shows each option as `{ isExpression, value }` (a bare value is the C1/C2-style bug), each action's `upgradeIndex`, and the connection's `moduleVersionId`. If it errors, skip it.

**Baseline then fix:** switch the connection to the unfixed version → import → verify (expect the bug) → switch to the fixed version → re-import → verify (expect the fix). Close with `browser_close`.

## Phase 4 — Report

Give the user a table:

| Button | Action after upgrade | Field | Baseline (unfixed) | With fix |
| --- | --- | --- | --- | --- |

Include the screenshot paths (in `.playwright-mcp/`). Then:

- **If the finding reproduced:** add one line to its **Evidence** in the review ("Reproduced in Companion 5 by importing a page saved under the old version …").
- **If it did not reproduce:** say so plainly, drop or correct the finding, and record the confirmed Companion behaviour in **`companion-module-review:review-report-format`** → Confirmed facts.

Leave the test assets in `test-pages/` for the user to delete. The fix itself goes to the maintainer through the review, never as a commit.
