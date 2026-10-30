---
name: review-assign-reviewer
description: Assign the reviewer (the signed-in GitHub user) to one or more Companion modules in the Bitfocus developer portal, by driving the user's logged-in Chrome. Use at the start of a module review (Step 2b of review-companion-module), or for every module of a batch before the batch starts, so nobody else picks them up. Never takes over a module someone else is assigned to, and never blocks a review when it can't assign.
---

# Assign Yourself as Reviewer in the Developer Portal

The portal's assignment call only accepts the browser login (it rejects the GitHub token the review scripts use), so this runs in the user's own logged-in Chrome with the Claude in Chrome tools. Proven on stageaudioworks-obs-multisite (2026-10-29).

**Input:** one or more module names (without `companion-module-`).

## Guardrails

- **Assignment never blocks a review.** If anything below fails, report it and carry on with the review.
- **Never take over** a module assigned to someone else: record it and leave it.
- On the module page, click **only** the reviewer control and the **Assign myself as reviewer** button. The same page has **Approve**, **Request changes**, **Deprecate module** and **Add module notes**: never touch them here.
- Leave **Keep me assigned after reviews** off (the portal then clears the assignment once no versions await review).
- Run it in the **main session, one module at a time**, never from parallel subagents (one browser driver).

## Steps

1. **Who you are:** `gh api user --jq .login`. The portal shows reviewers by GitHub login.
2. **Browser:** invoke the `claude-in-chrome` skill, load its core tools in one ToolSearch, call `tabs_context_mcp`, and create a new tab. If the extension isn't connected, stop here: tell the user and list the modules to assign by hand.
3. **Who has what — one read:** open `https://developer.bitfocus.io/modules/review?type=companion-connection`, wait ~3–4 s (the table loads after the page), and read the text (`get_page_text`). Each module block ends with its reviewer: a login, `Unassigned`, or (for a new module) `Never Unassigned`. If the page redirects to sign-in, stop: ask the user to sign in to the portal in Chrome.
4. **Per module:**
   - Reviewer is **your login** → already yours, skip.
   - Reviewer is **another login** → skip; report "assigned to `<login>` — not taken over".
   - **Unassigned** → open `https://developer.bitfocus.io/modules/companion-connection/manage/<name>`, `find` the **Assign reviewer** button (top right of the module header) and click it, then `find` and click **Assign myself as reviewer** in the dialog. The header button now reads your login; confirm with `find` ("current reviewer in the module header").
   - A module missing from the queue table isn't pending: skip and report it.
   - If a click doesn't take after 2 tries, record "failed" and move on; after 2–3 modules fail, stop and hand the rest to the user.
5. **Check:** open `https://developer.bitfocus.io/modules/review?assigned=me`, wait, read the text, and confirm every module you assigned is listed with your login.
6. **Clean up:** close the tab.

## Report

One line per module: `assigned`, `already yours`, `assigned to <login> — not taken over`, `not pending`, or `failed`. List any failed ones for the user to assign by hand.
