# Jest → vitest conversion

Under ESM, jest needs `--experimental-vm-modules` and the ts-jest ESM preset. vitest is ESM-native, so switching is usually simpler. Two modules (zoom-cavzrc, zoom-osc-iso) were converted this way.

## When

Do it as **its own commit**, and confirm the pass/fail counts are the same as jest's:

- **Preferred: before Phase 1**, on the v1 code. This proves the safety net is unchanged before anything else moves (zoom-cavzrc: the same 133 passed / 3 failed on both runners).
- **Exception: after the Phase 1 ESM commit**, when `src/` still uses `require()` for something the tests mock. `vi.mock` only intercepts ESM `import`, and **not** `require()`, while `jest.mock` intercepted both. Convert the `require` first (zoom-osc-iso did this with `require('node-osc')`).

## Mapping

| jest | vitest |
|---|---|
| `jest.config.js` / `.ts` | `vitest.config.ts` (`defineConfig` from `vitest/config`) |
| `testMatch` | `test.include` |
| `setupFilesAfterEnv` | `test.setupFiles`. A `vi.mock()` in a setup file applies to every test file. |
| `moduleNameMapper` (regex → stub) | `resolve.alias: [{ find: /regex/, replacement: absPath }]` (see below) |
| `jest.fn()`, `jest.spyOn`, `jest.useFakeTimers` | `vi.fn()`, `vi.spyOn`, `vi.useFakeTimers` |
| `jest.mock('x', factory)` | `vi.mock('x', factory)`. A mock of a **default-imported** CJS package must return `{ default: … }` (see `esm-and-tooling.md`). |
| `jest.requireMock('x')` | No direct equivalent. `vi.mock('x')`, then `import * as x from 'x'`, which gives the mocked module. |
| `jest.Mock` type | `import { type Mock } from 'vitest'` |
| Global `jest`/`describe`/`expect` without imports | Import them from `'vitest'` explicitly (recommended), or set `test.globals: true` plus `"types": ["vitest/globals"]` |
| `enableJest: true` in `generateEslintConfig` | Remove it. Add the test-file override from `esm-and-tooling.md`. |
| `tsconfig.test.json` (`module: commonjs`, `types: ["jest"]`) | Delete it. Fold the tests into `tsconfig.json` (Phase 1.2). |
| devDependencies `jest`, `ts-jest`, `@types/jest`, `ts-node` (if only used for the jest config) | Remove them. Add `vitest`. |

```ts
// vitest.config.ts — moduleNameMapper equivalent
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'

const mock = (file: string): string => fileURLToPath(new URL(`./tests/__mocks__/${file}`, import.meta.url))

export default defineConfig({
	resolve: {
		alias: [{ find: /^.*\/src\/images(\.js)?$/, replacement: mock('images.ts') }],
	},
	test: {
		include: ['tests/**/*.test.ts'],
		setupFiles: ['tests/setup.ts'],
	},
})
```

**Version note:** vitest 4 rejects an **arrow-function** implementation that is then called with `new` (`vi.fn(() => obj)` used as a constructor). Use `vi.fn(function () { return obj })`, or stay on vitest 3 until those mocks are rewritten.
