# Characterization tests before migrating (modules without tests)

If a v1 module has no tests, write a small vitest suite against the **v1 code first** and commit it while it passes. The migration then has a safety net, and every later test change is a deliberate, reviewable v2 shape change. Seven modules migrated this way (elgato-keylight, hdtv-wolfpackgreen, lynbh-obs, philips-wiz-bulbs, sage-eventgfx, spotify-remote, zoom-tiles). Each suite passed on v1 and again after migration, with only small expected edits.

## What to cover

| Area | Assert |
|---|---|
| Definition guards | Action, feedback and preset ids are unique and non-empty. Option ids are unique within each definition. Every preset references actions and feedbacks that exist. |
| Action callbacks | The right device command, request or OSC message for each main category, with the transport mocked (UDP/TCP helper, `fetch`/`got`, websocket client). |
| Feedback callbacks | The value or style returned for a given module state. |
| Variables | The ids in the definitions, plus value updates for representative state. |
| Config | Field ids, defaults and regexes. |
| Upgrade scripts | Sample inputs are transformed correctly. Write the inputs in the shape the scripts will see **after** the migration only once you reach Phase 7. |
| Parsers / helpers | Pure functions, with fixtures where the device protocol is involved. |

Keep the tests coupled to **behaviour**, not to v1-only API shapes. Assert "the command sent", not "`parseVariablesInString` was called".

## Setup

```bash
yarn add -D vitest
```

- **`package.json`:** `"test": "vitest run"`.
- **`vitest.config.ts`:** `test: { include: ['tests/**/*.test.ts'] }`.
- **`tsconfig.json`:** cover `tests/**` with `rootDir: "./"` and `noEmit: true` (Phase 1.2).
- **eslint:** add the test-file override from `esm-and-tooling.md` → "Lint: test-file override". Otherwise `n/no-unpublished-import` and `@typescript-eslint/unbound-method` fail every test file.

**CommonJS v1 modules:** vitest is ESM-only, so `tsc -p tsconfig.json` fails on the tests (TS1479) while `package.json` has no `"type": "module"`. Typecheck the tests with a **temporary** override in `tsconfig.json`, and remove it in Phase 1 once `"type": "module"` lands:

```json
{
	"compilerOptions": { "module": "ESNext", "moduleResolution": "Bundler", "types": ["node", "chai"] }
}
```

## Loading the instance class in a v1 module

In v1, `main.ts` calls `runEntrypoint(...)` at import time, and the `InstanceBase` constructor needs Companion's IPC. Stub `runEntrypoint`, then build instances with `Object.create(Class.prototype)` and stub the host methods the code calls:

```ts
import { vi } from 'vitest'

const { runEntrypoint } = vi.hoisted(() => ({ runEntrypoint: vi.fn() }))

vi.mock('@companion-module/base', async (importOriginal) => {
	const actual = await importOriginal<typeof import('@companion-module/base')>()
	return { ...actual, runEntrypoint }
})

await import('../src/main.js')
// v1 modules rarely export the class. Read it from the runEntrypoint call instead.
const ModuleInstance = runEntrypoint.mock.calls[0][0] as new (internal: unknown) => any
const UpgradeScripts = runEntrypoint.mock.calls[0][1] as unknown[]

function createInstance() {
	const instance = Object.create(ModuleInstance.prototype)
	Object.assign(instance, {
		log: vi.fn(),
		updateStatus: vi.fn(),
		checkFeedbacks: vi.fn(),
		checkAllFeedbacks: vi.fn(), // already stubbed, so the v2 test change is small
		setVariableValues: vi.fn(),
		setVariableDefinitions: vi.fn(),
		setActionDefinitions: vi.fn(),
		setFeedbackDefinitions: vi.fn(),
		setPresetDefinitions: vi.fn(),
	})
	return instance
}
```

Mock socket helpers the same way, e.g. return a fake `UDPHelper` from the `vi.mock` factory that records sends.

**In Phase 8** (v2), delete the `runEntrypoint` stub and use the default import: `const { default: ModuleInstance, UpgradeScripts } = await import('../src/main.js')`. Keep `Object.create(ModuleInstance.prototype)`, because the v2 constructor still needs IPC. If the fake socket recorded `send`, rename it to `sendAsync` wherever the code moved to it (see **companion-v1-to-v2-migrate-definitions** B.4).

## Commit

Commit as `test: add characterization tests before v2 migration` once `yarn test`, `tsc -p tsconfig.json` and `yarn lint` pass on v1. Then start Phase 1.
