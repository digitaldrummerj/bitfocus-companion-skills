# `apiScan` hints (companion-module-review)

`api-scan.ps1` (companion-module-review plugin) searches the module for version-specific patterns, and the review fact sheet carries the hits as `apiScan`. Treat each hint as a lead to verify, never as a finding on its own:
1. Open the hint's `file:line`.
2. Confirm it is real code (not a comment, string or dead branch).
3. Confirm the rule applies to this module's version.
4. Report it with the severity from the reference file.

| Hint id | Applies to | Check against |
|---|---|---|
| `V1-RUNENTRYPOINT`, `V1-PARSEVARIABLES`, `V1-CHECKFEEDBACKS-NOARGS`, `V1-VARDEFS-ARRAY`, `V1-ISVISIBLE-FN`, `V1-OPTIONS-IGNORE`, `V1-PRESET-BUTTON-CATEGORY`, `V1-PRESETS-SINGLE-ARG`, `V1-REQUIRED`, `V1-INPUTVALUE`, `V1-RELATIVEDELAY` | any 2.x | `references/v2.0.md` (removed APIs, High table) |
| `LATER-API-2.1` | 2.0.x only | `references/v2.0.md` → "Uses features from a later API version" |
| `ADV-FEEDBACK-NO-AFFECTED`, `SUBSCRIBE-NO-MONITOR`, `SETCUSTOMVAR-DEPRECATED` | ≥ 2.1 | `references/v2.1.md` |
| `BOOL-FEEDBACK-HELPER-BUG`, `HELPER-SEND-AWAIT` | any 2.x (bug and behaviour notes) | `references/v2.0.md` High table |

An empty `apiScan` does not mean the module is compliant: the scan only covers patterns a text search can see.
