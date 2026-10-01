# Phase 8: updating tests for v2

| v1 test pattern | v2 replacement |
|---|---|
| Mock instance stubs `parseVariablesInString: vi.fn(async (s) => s)` | Delete the stub. Callbacks receive options that are already parsed, so pass final values: `callback({ options: {...} } as any, ctx)`. |
| Mock instance stubs `checkFeedbacks` and asserts `toHaveBeenCalledWith()` with no args | Stub `checkAllFeedbacks` too. Assert that `checkFeedbacks` is called with **feedback ids** (`FeedbackIdX.member`). |
| `setVariableDefinitions` mock asserts an array of `{ variableId, name }` | Assert an object: `expect(defs).toHaveProperty('my_var', { name: '...' })`, or check `Object.keys(defs)`. |
| `setPresetDefinitions` mock captures one argument; tests read `preset.category` | It now captures `(structure, presets)`. Use the `capturePresets()` placement helper from **companion-v1-to-v2-migrate-presets** → `references/tests.md`. |
| `if (preset.type !== 'button') continue` / `type === 'button'` | `'simple'`. Otherwise the guard test silently skips **every** preset and still passes. Only `tsc` over the tests catches this (TS2367). |
| Preset assertions like `options.idVariable` is `undefined` | v2 presets must give every action option, so expect the field default (e.g. `''`). |
| Harness helpers typed `(definition: CompanionActionDefinition \| undefined, …)` / `CompanionFeedbackDefinition` | Schema-typed definitions (and the `\| false` the definitions map allows) don't fit the un-parameterised type. Type the parameter `unknown` when the harness only calls `.callback`, or use the precise schema generic. |
| Tests call `callback(event)` only | v2 passes a context as the 2nd argument. Pass `{ type: 'action', signal: new AbortController().signal }` (or `type: 'feedback'`) when the code reads the context. `signal` exists from **2.1+ (Companion 5.0+)**. |
| Tests import the class through `require`, `index.js` or a named import | `import ModuleInstance from '../src/main.js'` (default import) |
| Tests build option values like `{ userName: '$(internal:x)' }` and expect parsing | Parsing is Companion's job now. Test with already-resolved values. |
| Tests fire an action with an option key missing and expect a fallback | Keep that test. It protects the `?? default` guards for options missing from saved buttons. |
| Guard tests over definitions check `options[].id` uniqueness | Keep them. Duplicate option ids are rejected at runtime in 2.1. |

Mock helpers: rename any `InstanceBaseExt` mock type to `ModuleInstance`, cast with `as unknown as ModuleInstance`, and add whatever fields the code under test touches.

Typecheck the tests as well: `yarn tsc -p tsconfig.json --noEmit`. vitest and jest strip types, so a test that no longer matches the v2 shapes can still "pass".
