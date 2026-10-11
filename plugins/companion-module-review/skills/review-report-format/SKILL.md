---
name: review-report-format
description: 'Defines the format of an assembled Companion module review: section order, the Verdict line, the 📋 Issues list (anchored checklist of findings), the per-finding block (Source / Evidence / Confirm by), and the 📝 Additional Notes section. Use when assembling the final review file, or when reformatting an existing review.'
---

# Review Report Format

Defines how the final review markdown is laid out. There is **no scorecard**: the 📋 Issues list is the at-a-glance summary, and it needs no counts kept in sync when findings are edited.

## When to Use This Skill

- When assembling the final review file from the deterministic findings and the reviewers' findings
- When generating the 📋 Issues list with anchor links to each finding
- When a review needs retroactive formatting

---

## ⚠️ CRITICAL: Review File Output Location

**Invoke the `companion-module-review:review-workspace-conventions` skill before writing the review file.**

Final review files MUST be written to this repo's `reviews/` directory — NOT the module's folder.

```text
reviews/{short-module-name}/review-{short-module-name}-{version}-{YYYYMMDD}-{HHmmss}.md
```

- `short-module-name` = module folder name with `companion-module-` prefix stripped
- Timestamp from: `date -u +"%Y%m%d-%H%M%S"`
- Create subdirectory if needed: `mkdir -p reviews/{short-module-name}/`

**❌ WRONG:** writing a review file inside the module clone (`companion-modules-reviewing/companion-module-*/review-*.md`)  
**✅ RIGHT:** `reviews/{short-module-name}/review-*.md` in this repo

---

## Markdown Lint (required)

Every review must pass **markdownlint** with the plugin's config before the run finishes. The workspace's `.markdownlint.jsonc` is identical, so the VS Code markdownlint extension shows the same result:

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/lint-review.ps1 -ReviewFile reviews/<name>/<review-file>.md   # add -Fix to auto-fix
```

Exit code 0 = clean. Otherwise fix every reported line and re-run until it is clean (`-Fix` repairs blank-line and table-spacing issues automatically; MD036 and MD040 need a hand fix). The config turns off only line length (MD013) and tabs inside code blocks (MD010, so evidence stays verbatim). Write it clean the first time:

| Rule | Write it like this |
| --- | --- |
| MD036 no bold-as-heading | Group labels are headings (`### Blocking`), never a bold-only line (`**Blocking**`) |
| MD040 fence language | Every opening fence names a language: `ts`, `js`, `json`, `yaml`, `bash`, `powershell`, `diff`, `markdown`, or `text` for logs, command output and plain listings |
| MD022 / MD031 / MD032 / MD058 | A blank line before **and** after every heading, fenced block, list and table — including between a `**Evidence:**` label and its fence, and between a heading and its list |
| MD060 table style | Compact pipes everywhere: `\| a \| b \|` rows and a `\| --- \| --- \|` divider (never `\|---\|---\|`) |
| MD038 code spans | No padding inside backticks (`` `foo` ``, not `` ` foo ` ``) |
| MD033 / MD034 | No inline HTML; wrap URLs as `[text](url)` or `<url>` |
| MD012 / MD047 | No double blank lines; the file ends with exactly one newline |

---

## Section Order

1. Title + meta table
2. **Verdict**
3. **❓ Assumptions to Confirm** *(only when there are any)*
4. **📋 Issues**
5. 🔴 Critical
6. 🟠 High
7. 🟡 Medium
8. 🟢 Low
9. 💡 Nice to Have
10. 🔮 Next Release
11. ⚠️ Pre-existing Notes *(scope `both` only)*
12. 📝 Additional Notes *(only when there are notes)*

Omit any section that has no content. Do **not** add a scorecard, a "Fix Summary", a "What's Solid" section, or summary/count lines.

**No 🧪 Tests section.** When a module has tests they are run, but the report says nothing about them unless they **fail**. A failing test run is an ordinary finding in the severity section that fits its impact (name the failing test and the error). Passing tests, coverage, test quality and missing tests are never mentioned.

**Blocking** = every finding in the `🔴 Critical` and `🟠 High` sections (pre-existing ones in those sections included). Everything else is non-blocking. Blocking drives the Verdict and the 📋 Issues grouping; it is never printed as a count.

---

## Verdict

The status line only — no reasoning paragraph:

```markdown
## Verdict: ❌ Changes Required
```

or (no blocking findings)

```markdown
## Verdict: ✅ Approved
```

---

## 📋 Issues

### Rules

- **Include every finding** with a heading in the main review body (Critical through Next Release)
- **Group as Blocking / Non-blocking** — Blocking = `🔴 Critical` + `🟠 High`; Non-blocking = everything else
- **Don't list individual notes** (Pre-existing Notes table entries, 📝 Additional Notes bullets), because they have no headings of their own. But when the review has a 📝 Additional Notes section, end the Issues list with a `### Notes` group that links to it, so the reader knows it's there: `- [📝 Additional Notes](#-additional-notes)`. The anchor is `#-additional-notes`: GitHub drops the 📝 but keeps the hyphen that the space after it becomes. Notes are never checklist items: they need no action.
- The groups are `### Blocking` / `### Non-blocking` **headings** (never bold-only lines — that is MD036), each followed by a blank line before its list
- If there are no blocking issues, omit the `### Blocking` heading and its list
- If there are no non-blocking issues, omit the `### Non-blocking` heading and its list
- If there is no 📝 Additional Notes section, omit the `### Notes` group

Each item is a GitHub-flavored Markdown task list item (`- [ ]`). On a re-review, mark an item `- [x]` once the maintainer has addressed it in the resubmitted version.

```markdown
## 📋 Issues

### Blocking

- [ ] [C1: Issue title here](#c1-issue-title-here)
- [ ] [H1: Issue title here](#h1-issue-title-here)

### Non-blocking

- [ ] [M1: Issue title here](#m1-issue-title-here)
- [ ] [L1: Issue title here](#l1-issue-title-here)
- [ ] [N1: Issue title here](#n1-issue-title-here)

### Notes

- [📝 Additional Notes](#-additional-notes)
```

### Anchor Generation (GitHub Markdown Rules)

To generate the anchor for a heading:

1. Lowercase the entire heading text
2. Remove everything that is NOT: letters, digits, spaces, hyphens
3. Replace **one or more** consecutive spaces/hyphens/underscores with a **single** hyphen (they collapse — `—` surrounded by spaces becomes one `-`, not two)
4. Backtick content keeps its inner text (backticks themselves are removed)
5. Emoji characters and their variation selectors are removed
6. Special characters removed: `:` `(` `)` `—` `.` `@` `/` `'` `` ` `` `!` `?`

> ⚠️ **Avoid emoji in issue headings.** Emoji followed by spaces produce ambiguous anchor output across Markdown renderers. Keep emoji in section headings (e.g. `## 🔴 Critical`) but use plain text in issue headings (`### C1:`, `### H1:`, …). Classification belongs in the metadata lines below the heading, not in the heading text.

| Heading | Anchor |
| --- | --- |
| `### C1: \`clearIdleTimer()\` called in Reconnect action — method does not exist` | `#c1-clearidletimer-called-in-reconnect-action-method-does-not-exist` |
| `### H1: EventSource not closed in \`destroy()\`` | `#h1-eventsource-not-closed-in-destroy` |
| `### M3: \`@companion-module/base\` version doesn't satisfy peer dependency` | `#m3-companion-modulebase-version-doesnt-satisfy-peer-dependency` |
| `### N1: Unused import in \`upgrades.ts\`` | `#n1-unused-import-in-upgradests` |

---

## ❓ Assumptions to Confirm

Right after the Verdict, so the reviewer sees it first. It lists every assumption a finding depends on that the review could **not** confirm from the module's code or the `@companion-module/base` package in its `node_modules`. Typical examples are how the Companion host application behaves (for example upgrade-script input, or what it does with a malformed value) and device or protocol behaviour. Other apps that consume Companion presets (Bitfocus Buttons, for example) are **out of scope**: don't raise findings or assumptions about them. Collect them from the reviewers' and verifiers' `ASSUMPTIONS` output; a verifier's `uncertain` verdict always yields one.

### Confirmed facts (never list as assumptions)

These were confirmed by the review maintainer. Treat them as facts: don't list them under ❓ Assumptions to Confirm, and drop them if a reviewer or verifier lists them. When the maintainer confirms or corrects a new assumption, add it here, with its date, and in the domain skill it belongs to.

| Fact | Confirmed | Also recorded in |
| --- | --- | --- |
| Companion runs each upgrade script **only once per connection** and records how many it has run, so editing a released script never reaches connections that already ran it | 2026-10-08 | companion-upgrades, companion-v2-upgrades, companion-v2-api-compliance `references/v2.0.md` |
| When a connection is disabled or deleted, Companion calls `destroy()` and then **stops the module's process**. Not a reason to relax cleanup: `destroy()` must still stop every timer, interval, socket and child process the module started | 2026-10-08 | companion-protocol-reviewer agent |
| Companion resolves variables (`useVariables` text fields and expression-mode fields) **before** an action or feedback callback runs; the callback only sees resolved values | 2026-10-08 | companion-v2-api-compliance `references/v2.0.md` |
| Companion stores **every** action/feedback option wrapped (`{ isExpression, value }`), including options saved under an API v1 version of the module; old configs are migrated automatically on startup after an upgrade or on import. So a v2 module's upgrade script always receives wrapped values | 2026-10-08 (Companion source + maintainer) | companion-v2-api-compliance `references/v2.0.md`, companion-v2-upgrades |
| An upgrade script's output is stored **unchanged**. A bare value is read as `undefined`, fails validation, and Companion **refuses to run the action** ("Failed to parse action options"). The impact of a bare write is "button stops working", not a wrong value. Reproduced in Companion 5 (biamp-tesira v2.1.0 → v4.0.0 import test): a bare number shows as 0 and a bare dropdown value shows blank in the editor | 2026-10-08 (Companion source + reproduced by maintainer) | companion-v2-api-compliance `references/v2.0.md`, companion-v2-upgrades |
| An installed module runs from its **packaged `.tgz` layout** (the bundled `main.js` at the package root, built by `companion-module-build`), not from the repo's `dist/` folder. Files the code reads at runtime must be in the package (a `build-config.cjs` `extraFiles`, or embedded) | 2026-10-09 (maintainer) | review-report-format |
| A module can call `setActionDefinitions()` at any time (e.g. after connecting, or in `configUpdated()`) and Companion uses the new definitions. But Companion runs the **saved actions' `subscribe` callbacks only once, right after `init()`**; it doesn't replay them when the definitions arrive later. A module whose action definitions appear after `init()` and that relies on action `subscribe` must call `this.subscribeActions()` itself, the way it calls `this.subscribeFeedbacks()`. Reproduced in Companion 5.1.0 with an API 1 (base 1.12.1) module: no "Subscribe act:" after a restart, and editing the action subscribed it at once | 2026-10-11 (live test, devcore-mixingstation v2.0.0; maintainer kept the finding) | review-report-format |
| Companion 5 passes **bare** option values to an **API 1** module's upgrade script and wraps the script's output when it stores it (API 2 scripts get wrapped values, see above). Reproduced: a base 1.12.1 script calling `path.startsWith('ch.')` on `action.options.path` ran correctly, and the stored result was `{ isExpression: false, value }` | 2026-10-11 (live test, devcore-mixingstation v1.0.1 → v2.0.0) | review-report-format |
| Other apps that consume Companion presets (e.g. Bitfocus Buttons) are **out of scope**. Don't raise findings or assumptions about them (this drops the "layered preset without `alternatives` fallback" rule) | 2026-10-08 | companion-v2-api-compliance `references/v2.1.md` (rule removed) |

The section exists so the reviewer can confirm or correct each assumption once and have the review skills updated, so the next review doesn't have to assume it. Don't list facts that were checked (quoted code, a reproduced run, a base typing that was read). Omit the section when there are none.

```markdown
## ❓ Assumptions to Confirm

| # | Assumption | Based on | Affects |
| --- | --- | --- | --- |
| A1 | Companion 5 passes every option to an upgrade script as `{ isExpression, value }`, including values saved by a Companion 4 version of the module | base 2.1.3 typings and its own upgrade helpers; Companion's host code not checked | [C1](#c1-anchor), [H2](#h2-anchor), [M7](#m7-anchor) |
| A2 | Companion 5 cannot read an unwrapped value that an upgrade script writes back | not determinable from the module or base | [C1](#c1-anchor), [H2](#h2-anchor) |
```

- **Assumption**: one plain sentence stating what is assumed to be true.
- **Based on**: what the assumption rests on, and what was *not* checked.
- **Affects**: links to every finding whose existence or severity depends on it. If an assumption turns out false, those findings may change severity or disappear.

---

## Source Links

Every cited file in the **module's own repo** is a clickable GitHub link, pinned to the exact commit the review tag points to, with the line or range as the anchor. Build it from the fact sheet's `sourceLinkBase` (`<repoWebUrl>/blob/<reviewCommit>`):

```markdown
[`src/upgrades.ts:67-73`](https://github.com/bitfocus/companion-module-x/blob/<reviewCommit>/src/upgrades.ts#L67-L73)
[`src/main.ts:142`](https://github.com/bitfocus/companion-module-x/blob/<reviewCommit>/src/main.ts#L142)
```

- Use the **full commit SHA**, not the tag name. A maintainer can re-push a tag, and a link to the tag name would then point at different lines.
- Link in the **File** metadata, in **Confirm by**, and wherever a module file is named in prose. Code blocks can't hold links, so their `// path:line` header comments stay plain text; the **File** / **Confirm by** links cover them.
- A file with several ranges gets one link per range: [`src/main.ts:412-430`](…#L412-L430), [`src/main.ts:192-194`](…#L192-L194).
- Files **outside** the module repo (`node_modules/@companion-module/base/…`, the templates) stay as plain code spans. They are not in the module's GitHub repo.
- If `sourceLinkBase` is null (no GitHub remote, or the tag doesn't resolve), use plain code spans and say so in the meta table.

---

## Finding Blocks

Every finding starts with a plain-text heading and a metadata **list** (one `- **Key:** value` item per line — consecutive bold lines without list markers render as one run-on paragraph). The **Source** line tells the human reviewer how much checking the finding needs:

| Source | Meaning | Human check needed? |
| --- | --- | --- |
| `🤖 validate-template (<ID>)` | Deterministic — produced by `validate-template.ps1` (finding id in parentheses), which has its own test suite | No — trust as-is |
| `🔎 <reviewer> — verified` | AI judgment, independently confirmed by the `companion-finding-verifier` with freshly captured evidence | Glance at the Evidence |
| `🔎 <reviewer> — ⚠️ needs your check` | AI judgment the verifier could neither confirm nor refute | Yes — read the code |
| `🔎 <reviewer>` | AI judgment below High (not verified — non-blocking) | Optional |

`<reviewer>` is `protocol reviewer`, `QA reviewer`, or `compliance reviewer` (list several when findings were merged).

### Write for the user, not the code

The reader is a reviewer skimming many findings and a maintainer deciding what to fix. Most of them know Companion as an **operator** (buttons, actions, options, connection status) before they know the module's internals. Every finding (blocking or not) must make sense **before** the reader looks at any code.

- **Title = the visible effect**, in plain words: "Hold-to-adjust buttons lose their repeat speed after upgrading", not "level_hold_start upgrade writes a raw 500". Put code identifiers in the body, not the title, unless there is no user-visible effect (pure code quality).
- **Lead with "What goes wrong"**: a concrete scenario. Say who is affected, what they do, and what they see. Use the names shown in Companion's UI (the action name "Start hold level adjustment", the option label "Repeat interval (ms)", the connection status) and add the code id in parentheses the first time if it helps someone find it.
- **Use real values.** "A button set to repeat every 250 ms will repeat every 500 ms" beats "the interval is lost".
- **Explain the mechanism in plain language in "Why it happens"**, in 2–4 short sentences. Define any API term the first time it appears, e.g. "Companion 5 stores each option as a small object, `{ isExpression: false, value: 250 }`, instead of the bare value `250`". Don't stack identifiers, and don't use "this" or "it" without a noun.
- **Say who is NOT affected** when the reach is narrow (e.g. "users already on v3.x are unaffected"). That's how the reader judges urgency.
- **"Fix" opens with one plain sentence** describing the change in words, then the code.
- **Keep code out of the narrative.** Quoted code belongs in **Evidence** (and in **Fix**). The two narrative parts should read like an explanation to a colleague.

### Blocking finding (Critical / High)

The parts, in order: heading, metadata list, **What goes wrong**, **Why it happens**, **Evidence**, **Confirm by**, **Fix**. AI-judgment blocking findings MUST carry **Evidence** (the verbatim code lines, with `file:line`, that prove the claim, as re-captured by the verifier) and **Confirm by** (one line telling a human exactly what to look at). Deterministic findings carry the validator's expected-vs-found instead of a code quote.

````markdown
### H1: Removing the connection leaves it trying to reconnect in the background

- **Source:** 🔎 protocol reviewer — verified
- **Classification:** 🆕 NEW
- **File:** [`src/main.ts:138-141`](https://github.com/bitfocus/companion-module-x/blob/<reviewCommit>/src/main.ts#L138-L141)

**What goes wrong:** If the device is offline when a user deletes or disables the connection, the module keeps trying to reconnect every 5 seconds. If the device comes back, the module opens a connection that nothing owns, so the device sees a phantom client until Companion restarts.

**Why it happens:** When a connection is removed, Companion calls the module's `destroy()` to clean up. `destroy()` closes the socket but doesn't cancel the pending "reconnect in 5 seconds" timer, so the timer still fires afterwards and reconnects.

**Evidence:**

```ts
// src/main.ts:138-141
async destroy(): Promise<void> {
	this.socket?.destroy()
	this.updateStatus(InstanceStatus.Disconnected)
}
// src/main.ts:201
this.reconnectTimer = setTimeout(() => this.connect(), 5000)
```

**Confirm by:** open [`src/main.ts:138-141`](https://github.com/bitfocus/companion-module-x/blob/<reviewCommit>/src/main.ts#L138-L141). There is no `clearTimeout(this.reconnectTimer)`.

**Fix:** cancel the reconnect timer before closing the socket.

```ts
clearTimeout(this.reconnectTimer)
```
````

### Non-blocking finding (Medium and below)

Same structure, shorter: heading (the visible effect), metadata list, **What goes wrong** (one or two sentences), a short **Why it happens**, and **Fix**. Evidence and Confirm by are optional.

---

## 📝 Additional Notes

Informational items the maintainer may act on or ignore — never blocking, never in 📋 Issues, no checkbox. One line each. `TSCONFIG-DIFF` validator notes always go here:

```markdown
## 📝 Additional Notes

- `tsconfig.build.json` differs from the template (`"extends"` is `@tsconfig/node22/tsconfig.json` where the template has `@companion-module/tools/tsconfig/node22/recommended-esm.json`). Fine as long as the module builds — no change required.
```

Omit the section when there are no notes.
