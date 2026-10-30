---
name: review-submit
description: Deliver a finished Companion module review. Commits and pushes the review with its TRACKER row marked ✅, then in the Bitfocus developer portal (the user's logged-in Chrome) either clicks Request changes with the standard findings message or clicks Approve, and after an approval watches the build and flags it if it fails. Use when the user says "submit" for a review (hold mode), or automatically at the end of review-companion-module when the user chose "Deliver automatically" for this review cycle.
---

# Submit a Review to the Maintainer

Delivers **one** review that is already written and lint-clean (review-companion-module Step 7a). Two triggers only:

- **Hold mode** (the default): the user read the review and said "submit".
- **Auto mode**: the user chose **Deliver automatically** at the start of this review cycle (review-companion-module Step 0b).

Never deliver in any other situation. Both portal actions email the maintainer and can't be undone.

## Guardrails

- **The verdict comes from the review file**, nothing else: `## Verdict: ❌ Changes Required` → request changes; `## Verdict: ✅ Approved` → approve. If the file has neither, stop and ask.
- **Never Approve** unless the verdict is ✅ Approved **and** the version is `PENDING`.
- Act only on the version row whose tag is the reviewed tag. **Request changes** also shows on already-approved rows, so match the row by tag, never by position.
- Before every final click, confirm the dialog title names this module and tag: "Request Changes for `<tag>`" or "Approve `<name>` `<tag>`?".
- Never click anything else on the page (**Deprecate module**, **Add module notes**, **Edit**, other rows).
- Batches deliver **one module at a time in the main session**, in queue order. That keeps one git writer and one browser driver.

## Step 1 — Read the review

From `reviews/<name>/<file>.md`, collect:

- the module, the tag (meta table **Version**), and the verdict;
- the blocking IDs (the `🔴 Critical` / `🟠 High` finding headings), for the commit message, e.g. `C1-C2, H1`;
- whether there are **non-blocking findings**: any `🟡 Medium`, `🟢 Low`, `💡 Nice to Have` or `🔮 Next Release` section.

Check the version is still `PENDING`:

```powershell
$h = @{ Authorization = "Bearer $(gh auth token)" }
(Invoke-RestMethod "https://developer.bitfocus.io/api/v1/public/modules/companion-connection/<name>/versions" -Headers $h).versions |
    Where-Object gitTag -eq '<tag>' | Select-Object gitTag, status, published
```

If it's withdrawn, rejected or approved already, stop and tell the user.

## Step 2 — Commit and push the review

In the workspace (the companion-module-review repo), on `main`:

1. In `reviews/TRACKER.md`, change this review's row from ⬜ to ✅. Change that row only.
2. Stage **only** that row and the review file. Use `git add -p reviews/TRACKER.md` when other rows have unrelated changes, and `git add reviews/<name>/<file>.md`.
3. Commit:
   - Changes required: `add: reviews/<name>/<file>.md. changes required (<blocking IDs>)`.
   - Approved: `add: reviews/<name>/<file>.md. approved`, or `… approved (non-blocking findings only)` when it has non-blocking findings.
4. `git push origin main`.
5. Build the review link from the remote: `https://github.com/<owner>/<repo>/blob/main/reviews/<name>/<file>.md`. `ConvertTo-RepoWebUrl` in `${CLAUDE_PLUGIN_ROOT}/scripts/lib/ReviewState.ps1` turns `git remote get-url origin` into the `https://github.com/<owner>/<repo>` part.

## Step 3 — Act in the portal

Invoke the `claude-in-chrome` skill. Load its core tools in one ToolSearch, call `tabs_context_mcp`, and create a new tab. Open `https://developer.bitfocus.io/modules/companion-connection/manage/<name>`. If the page shows sign-in, or the extension isn't connected, go to **If the portal step fails**.

The **Versions** tab lists one row per version: tag, submitted date, status and actions. Find the row for the reviewed tag.

### Changes Required → Request changes

1. Click that row's **Request changes**. Check the dialog title is "Request Changes for `<tag>`".
2. Click into the text box and type this message. Each blank line below is one Enter, a new paragraph in the editor. Fill in the review link:

   ```text
   Here are the findings: <review link>

   Please fix the critical and high findings. The rest are for you to review and decide what to do with them.

   Note: The findings are AI generated. There may be things the AI pointed out that do not make sense to implement or change.  If something is in the critical or high that you think is not valid, please let us know in Slack and we can take a look at it.
   ```

3. Take a screenshot and check the text and link are complete. Then click **Submit**.

### Approved → Approve

1. Click that row's **Approve**. Check the dialog title is "Approve `<name>` `<tag>`?". The dialog says approving starts the build.
2. **If the review has non-blocking findings,** type into the comments box: `Approved. A few optional suggestions are here: <review link>`. The button then reads **Approve with comments**. With no non-blocking findings, leave the box empty.
   - **If the user asked for a note** with the approval (e.g. "approve it with a note that before 1.0.0 please add feedbacks"), press Enter after the link line and type the note as its own paragraph, in the user's words, e.g. `Before 1.0.0, please add feedbacks.` With no non-blocking findings, the note is the whole comment. Never add a note the user didn't ask for.
3. Click **Approve** / **Approve with comments**.

### Confirm, then close the tab

Re-open the manage page, wait ~2 s, and read the reviewed tag's row (match it by tag, e.g. with `javascript_tool` over the table rows). It must now read **Changes Requested** or **Approved**. Close the tab.

The portal page is the source of truth here. The public versions API can lag behind it: right after an approval it has returned `PENDING` while the page already showed Approved. If you also check the API, retry it for up to ~30 s before treating `PENDING` as a failure, and never click Approve or Request changes a second time because of a stale API answer.

## Step 4 — After an approval: watch the build

Start the watcher with the Bash tool's `run_in_background`, so the session is notified when it ends:

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/bitfocus-watch-build.ps1 -ModuleName <name> -GitTag <tag>
```

| Exit | Meaning | Tell the user |
| --- | --- | --- |
| 0 | built and published (a note is added if the run itself failed after publishing) | "published", plus the note if any |
| 1 | **build failed**: status `FAILED`, or the run failed and nothing was published | **flag it for review**, with the build log URL |
| 2 | **not published after 30 min** | **flag it for review**, with the build log URL if any |
| 3 | rejected or not found (shouldn't happen right after an approval) | **flag it** |

The review counts as delivered either way. A failed build is for the user to look at, not for you to fix or re-approve.

## If the portal step fails

**Lost tab group.** If the browser tools keep flipping between "Tab … is not in Claude's tab group" and "This session has no tab group of its own", or clicks report success but nothing opens, more than one browser (e.g. Chrome and Brave) is running the Claude in Chrome extension, and the tools can't tell them apart. Check the version's status with the Step 1 API call first (the click may not have landed, or may have), then ask the user to close every browser but the one they use for the portal, and retry once they have.

If it still fails, the review is pushed but the maintainer hasn't been notified. Say so plainly, then:

- Set the row back to ⬜.
- Commit `fix: TRACKER — <name> <tag> not yet delivered`, and push.
- Give the user the review link and the exact action to take by hand: **Request changes** with the message above, or **Approve**.

Stop after 2–3 failed attempts at any click. Don't keep retrying.

## Report

For each module, report:

- the commit;
- the review link;
- the portal action taken (changes requested / approved, with or without the comment);
- for approvals, the build result when the watcher finishes.
