# Phase 8: updating tests for v2

| v1 test pattern | v2 replacement |
|---|---|
| Mock instance stubs `parseVariablesInString: vi.fn(async (s) => s)` | Delete the stub. Callbacks receive options that are already parsed, so pass final values: `callback({ options: {...} } as any, ctx)`. |
| Mock instance stubs `checkFeedbacks` and asserts `toHaveBeenCalledWith()` with no args | Stub `checkAllFeedbacks` too. Assert that `checkFeedbacks` is called with **feedback ids** (`FeedbackIdX.member`). |
| `setVariableDefinitions` mock asserts an array of `{ variableId, name }` | Assert an object: `expect(defs).toHaveProperty('my_var', { name: '...' })`, or check `Object.keys(defs)`. |
| `setPresetDefinitions` mock captures one argument; tests read `preset.category` | It now captures `(structure, presets)`. Use the `capturePresets()` placement helper from **companion-v1-to-v2-migrate-presets** → `references/tests.md`. |
| `if (preset.type !== 'button') continue` / `type === 'button'` | `'simple'`. Otherwise the guard test silently skips **every** preset and still passes. Only `tsc` over the tests catches this (TS2367). |
| Preset assertions like `options.idVariable` is `undefined` | v2 presets must give every action option, so expect the field default (e.g. `''`). |
| Harness helpers typed `(definition: CompanionActionDefinition \| undefined, …)` / `CompanionFeedbackDefinition` / `CompanionActionDefinitions[string]` | Schema-typed definitions (and the `\| false` the definitions map allows) don't fit the un-parameterised type. Type the parameter `unknown` when the harness only calls `.callback`, or use the precise schema generic. |
| Tests call `callback(event)` only | v2 passes a context as the 2nd argument. Pass `{ type: 'action', signal: new AbortController().signal }` (or `type: 'feedback'`) when the code reads the context. `signal` exists from **2.1+ (Companion 5.0+)**. |
| Tests import the class through `require`, `index.js` or a named import | `import ModuleInstance from '../src/main.js'` (default import) |
| Setup mocks `runEntrypoint` (`vi.mock('@companion-module/base', … runEntrypoint: vi.fn())`) and reads the class from its call | Delete the stub, and use the default import. Keep `Object.create(ModuleInstance.prototype)`, because the constructor still needs Companion's IPC. See `characterization-tests.md`. |
| Fake socket helper records `send` | Rename it to `sendAsync` where the code now awaits it. `TCPHelper.send` mocks return a `boolean`. |
| `imageBuffer` length assertions (`r.imageBuffer.length === w * h * 4`) | Decode first: `Buffer.from(r.imageBuffer, 'base64').length`. A string has `.length` too, so the old assertion compiles and only fails at runtime. |
| Reading preset entry options: `preset.steps[0].down[0].options.someKey` | Entry types also union Companion's internal logic actions (`internal:logicIf`, …), so TS2339/TS7053. Read via `(entry.options as Record<string, unknown>).someKey`. |
| `def?.type !== 'advanced'` on a definitions map entry | Entries can be `false`, so TS2339. Narrow with `!def \|\| def.type !== 'advanced'`. |
| Tests build option values like `{ userName: '$(internal:x)' }` and expect parsing | Parsing is Companion's job now. Test with already-resolved values. |
| Tests fire an action with an option key missing and expect a fallback | Keep that test. It protects the `?? default` guards for options missing from saved buttons. |
| Guard tests over definitions check `options[].id` uniqueness | Keep them. Duplicate option ids are rejected at runtime in 2.1. |

Mock helpers: rename any `InstanceBaseExt` mock type to `ModuleInstance`, cast with `as unknown as ModuleInstance`, and add whatever fields the code under test touches.

A module gaining its first vitest tests also needs the eslint test-file override: `esm-and-tooling.md` → "Lint: test-file override".

Typecheck the tests as well: `yarn tsc -p tsconfig.json --noEmit`. vitest and jest strip types, so a test that no longer matches the v2 shapes can still "pass".
