# Phase 0.3: inventory of v1 APIs

Run these commands from the module root and save the output. Every matching line is a work item for a later phase.

```bash
# Entry point / class typing
grep -rn "runEntrypoint" src
grep -rn "InstanceBase<\|InstanceBaseExt" src tests 2>/dev/null
grep -rn "import type { ModuleInstance }\|import { ModuleInstance }" src tests 2>/dev/null   # named export → default (Phase 2)
grep -rnE "^export (interface|type) .*Config" src
grep -rnE "interface \w*Config" src                                     # → type alias in Phase 2
grep -rnE "(interface|type) \w+ (extends InstanceBase|= \{[^}]*setActionDefinitions)" src   # hand-written instance types (migrate-definitions A.2)

# Variable parsing (removed in v2): every field each call reads needs useVariables: true (migrate-definitions B.3)
grep -rn "parseVariablesInString" src tests 2>/dev/null
grep -rln "parseVariablesInString" src | xargs grep -n "type: 'textinput'" | head -50   # textinputs in parsing files: check each has useVariables
grep -rn "useVariables: true" src           # fields marked but never parsed in v1 start substituting in v2: record as a behaviour change

# Feedback checks / lifecycle
grep -rnE "checkFeedbacks\(\s*\)" src
grep -rnE "checkFeedbacks\(\.\.\." src                                  # spread of a runtime list (migrate-definitions C.3)
grep -rn "subscribe" src/feedback* src/feedbacks 2>/dev/null
grep -rn "imageBuffer" src

# Variables
grep -rn "setVariableDefinitions" src
grep -rn "variableId" src

# Inputs / config
grep -rn "isVisible:" src
grep -rn "isVisibleExpression" src          # every referenced action/feedback field needs disableAutoExpression
grep -rnE "\brequired:\s*(true|false)" src  # textinput → minLength: 1; any other field type → delete
grep -rn "InputValue" src tests 2>/dev/null
grep -rn "optionsToIgnoreForSubscribe" src
grep -rn "learn:" src
grep -rn "useVariable\b" src                # the v1 "Use variable" checkbox idiom (see migrate-definitions B.2)

# Presets
grep -rn "setPresetDefinitions" src
grep -rn "CompanionButtonPresetDefinition\|CompanionPresetDefinitions\|CompanionTextPresetDefinition" src
grep -rn "category:" src/preset* src/presets 2>/dev/null   # also matches builder-helper params named `category`; convert those too
grep -rnE "type: ['\"](button|text)['\"]" src
grep -rn "relativeDelay" src
grep -rnE "options: \{\s*\}" src/preset* src/presets 2>/dev/null   # presets relying on option defaults (must list every option in v2)

# Socket helpers: v2 send() is synchronous; promise behaviour moved to sendAsync() (migrate-definitions B.4)
grep -rn "UDPHelper\|TCPHelper\|TelnetHelper" src
grep -rnE "await [^;]*\.send\(" src

# Module format
grep -rn "require(" src
grep -rnE "module\.exports|module != undefined|typeof module" src     # throws under ESM
grep -rlE "require\(|module\.exports" scripts .husky *.js 2>/dev/null   # CJS helper scripts → rename to .cjs
node -p "require('./package.json').type ?? '(none: CommonJS)'"   # not grep: '"type"' also matches repository.type
grep -n '"extends"\|"module"\|"moduleResolution"\|"rootDir"\|"noEmit"' tsconfig*.json

# Custom variable writes from actions (candidates for 2.1 action results)
grep -rn "setCustomVariableValue" src

# Hard-coded version strings that may need a bump at the end
grep -rn "$(node -p "require('./package.json').version")" src
```

Also list the test setup, because tests usually mock the v1 instance surface:

```bash
ls tests/helpers tests/__mocks__ 2>/dev/null
grep -rln "parseVariablesInString\|checkFeedbacks\|setVariableDefinitions\|setPresetDefinitions\|type !== 'button'\|type === 'button'" tests 2>/dev/null
cat .husky/pre-commit 2>/dev/null           # lint-staged hook? See "Commits while the build is red" in the SKILL
sh .husky/pre-commit 2>/dev/null; echo "hook exit=$?"   # broken at baseline? see esm-and-tooling.md → Git hooks
```
