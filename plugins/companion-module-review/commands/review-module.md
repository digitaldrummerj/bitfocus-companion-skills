---
description: Review a Bitfocus Companion module (next pending, or one you name) at a chosen scope and produce a ranked review report. Report-only.
argument-hint: "[module-name] [version] [tag|module|both]   (defaults: next pending module, oldest pending version, tag scope)"
---

Review a Bitfocus Companion module using the **`companion-module-review:review-companion-module`** skill. Run it from your companion-module-review workspace.

Arguments: $ARGUMENTS

Interpret the arguments:

- If an argument is exactly `tag`, `module`, or `both`, it is the **scope**.
- If an argument matches a version pattern (`^v?\d+\.\d+`, e.g. `v2.1.0` or `2.1.0`), it is the **version** to review — pass it to the skill as the review tag. A version requires a module name; if it isn't pending for that module, the run errors and lists the pending versions.
- Any other argument is the **module name** (strip any `companion-module-` prefix). Module names like `panasonic-ak-hrp1000` don't match the version pattern.
- Missing module name → review the **next pending** module (the skill runs the plugin's `bitfocus-queue.ps1` and picks the dedup-aware "Next up").
- Missing version → review the **oldest** pending version of the module.
- Missing scope → default **`tag`** (only this release's changes).

Scopes: `tag` = only the `previousTag..reviewTag` diff (new/regression only); `module` = the whole current module, flat by severity; `both` = whole module classified new vs pre-existing.

Follow the skill's ordered pipeline:
1. Ask the delivery mode: hold for my review, or deliver automatically.
2. Pick the target from the queue.
3. Set up the module.
4. Assign me as reviewer in the portal.
5. Build the fact sheet.
6. Run validate-template.
7. Dispatch the parallel review subagents.
8. Assemble the review and its TRACKER row.
9. Deliver it in auto mode; otherwise wait for my "submit".

This is **report-only** for the module: do not modify it, create fix branches, or push to its repo. When done, tell me the review file path, the scope, the verdict, and the blocking count.
