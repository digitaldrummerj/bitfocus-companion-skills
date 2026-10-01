# ESM and tooling details (Phases 1 and 9)

## CommonJS packages under ESM

`tsc` and vitest often **don't** catch these. vitest's interop hides default-import mistakes, and hand-written `.d.ts` files can claim exports that don't exist at runtime. Check each CJS dependency in Node itself:

```bash
node --input-type=module -e "import * as m from 'got-cjs'; console.log(Object.keys(m))"
node --input-type=module -e "import d from 'osc'; console.log(typeof d, Object.keys(d).slice(0, 5))"
```

| Situation | Import |
|---|---|
| The package sets `module.exports = {...}` with no `exports.default` (e.g. `osc`) | **Default** import: `import osc from 'osc'`. Named imports fail at runtime. |
| The package sets `exports.default` and named exports (e.g. `got-cjs`) | **Named** import: `import { got } from 'got-cjs'`. The default import is the whole `exports` object, so `got.post` is `undefined`. |
| The package ships an ESM entry (e.g. `node-osc` ≥ 9) | Normal named or default imports, as its types say. |
| None of these work | `createRequire(import.meta.url)` plus an explicit cast (Phase 1.3). |

Knock-on edits when you switch to a default import:

- **Hand-written ambient types** (`declare module 'osc' { … }` with named exports only) must declare the default too.
- **Untyped packages** fail with TS7016 under `recommended-esm`. Add `src/types/<pkg>.d.ts`:
  ```ts
  /** Minimal typings for the parts of the untyped `osc` package the module uses */
  declare module 'osc' {
  	namespace osc {
  		interface UDPPortOptions { localAddress?: string; localPort?: number; remoteAddress?: string; remotePort?: number; metadata?: boolean }
  		class UDPPort {
  			constructor(options: UDPPortOptions)
  			on(event: string, listener: (...args: any[]) => void): this
  			open(): void
  			close(): void
  			send(packet: { address: string; args: unknown }, address?: string, port?: number): void
  		}
  	}
  	export = osc
  }
  ```
- **Test mocks** of that package must provide `default`: `vi.mock('osc', () => ({ default: { UDPPort: FakePort } }))`.

`module.exports = …` and `if (module != undefined) …` inside `src/` throw a `ReferenceError` under ESM. Replace them with `export`.

## Plain-JS helper scripts

`"type": "module"` makes every `.js` file in the repo ESM, including scripts that husky hooks or `package.json` scripts run (e.g. `scripts/update-help.js` using `require`). Rename CommonJS helpers to **`.cjs`** and update every caller (hooks, `package.json` scripts). Otherwise every commit fails from Phase 1 on.

## tsconfig inheritance in either direction

Phase 1.2 assumes `tsconfig.json` extends `tsconfig.build.json`. If the repo has it the other way round, **invert it first**:
1. Move the compiler options into `tsconfig.build.json`, extending `recommended-esm`.
2. Make `tsconfig.json` extend the build config.
3. Only then add `rootDir: "./"` and `noEmit: true` to `tsconfig.json`.

Adding `noEmit` to a config that the build extends stops the build from emitting anything.

## Already-ESM v1 modules

If `package.json` already has `"type": "module"`, Phase 1 is usually just two steps:
1. Swap the tsconfig to `recommended-esm` and delete the `Node16`, `baseUrl` and `paths` overrides.
2. Fix the `import type` errors. Expect a **TS1484** for every type-only import.

## Version bumps

- Bump `@companion-module/base` and `@companion-module/tools` in **one** `yarn add`. Otherwise tools 2.x prints a transient `YN0060` (it peers on base ^1.x).
- The versions in the Phase 1.1 table are **minimums**. Keep newer versions the repo already pins.

## Lint: test-file override

`generateEslintConfig` flags test files once vitest is a devDependency. Add the override when the module first gains tests, or when converting from jest:

```js
// eslint.config.mjs
import { generateEslintConfig } from '@companion-module/tools/eslint/config.mjs'

const baseConfig = await generateEslintConfig({ enableTypescript: true })

export default [
	...baseConfig,
	{
		files: ['tests/**/*.ts', 'vitest.config.ts'],
		rules: {
			'n/no-unpublished-import': 'off', // vitest is a devDependency; tests are never published
			'@typescript-eslint/unbound-method': 'off', // assertions on vi.fn() members
		},
	},
]
```

## New lint findings after the tools v3 bump

Eslint 10 and typescript-eslint 8.5x+ flag code that passed before. Fix each one minimally, in a separate small commit or the tooling commit, and record it as **tooling-driven** rather than part of the API migration:

| Rule | Typical cause | Fix |
|---|---|---|
| `@typescript-eslint/explicit-module-boundary-types` | The class became `export default` (Phase 2), so its public methods are now module boundaries | Add return types (`Promise<void>`). Type `any` parameters as `unknown` plus a guard, or use a scoped disable if retyping would change behaviour. |
| `@typescript-eslint/await-thenable` | `await tcp.send(…)` / `await udp.send(…)`: `send()` is synchronous in v2 | `sendAsync()` (**companion-v1-to-v2-migrate-definitions** B.4) |
| `@typescript-eslint/no-unnecessary-type-assertion` | Casts that the typed schema made redundant, `as never`, `{} as Record<string, never>` | Delete the cast |
| `@typescript-eslint/no-unsafe-enum-comparison` | `(x as number) === SomeEnum.member` after removing a cast | Type the config or option field with the enum itself |
| `no-useless-assignment` (new in eslint 10's recommended set) | A dead initial value, `let x = 0` overwritten before it is read | Drop the dead initializer |
| `n/no-unpublished-import`, `@typescript-eslint/unbound-method` in tests | vitest imports, `vi.fn()` assertions | The test-file override above |

Fix `tsc -p tsconfig.json` errors in tests **before** chasing lint errors in tests. Many test lint errors (e.g. `no-unnecessary-type-assertion` on `as never`) are knock-on effects of type errors.

**Lint errors outside the module** (agent tooling such as `.squad/`, local scripts) that already fail at baseline are **recorded, not fixed**. Adding them to `generateEslintConfig({ ignores: [...] })` is a separate, opt-in commit.

## Git hooks

Check the hook at baseline (Phase 0), before the first migration commit:

```bash
ls .husky/pre-commit && cat .husky/pre-commit     # missing file → the hook is a no-op
sh .husky/pre-commit                              # does it pass on the untouched v1 tree?
yarn lint-staged --debug 2>&1 | grep -i "no files\|matched"   # do the globs match src/**/*.ts?
```

| Baseline result | What to do during the migration |
|---|---|
| No `.husky/pre-commit` | No hook runs. `--no-verify` is unnecessary; just commit. |
| Passes on v1 | Try a normal commit first. Use `--no-verify` only when the hook **actually fails** on a red-build phase, and say so in the commit body. |
| Fails on v1 for unrelated reasons (e.g. it calls a script that doesn't exist) | Record it. Run its steps (`yarn lint-staged`) by hand, and commit with `--no-verify`, explaining why. Don't fix the hook as part of the migration. |
| lint-staged globs match no TS files | The hook never lints TS. Flag it for the maintainer, and run `yarn lint` yourself. |

lint-staged creates and drops a temporary **backup stash** ("Backing up original state…") on every commit. It is expected and transient, so it isn't a stash you created or broke.

## Packaging (Phase 9)

- **`yarn package`** writes `<id>-<version>.tgz` **and** a `pkg/` directory. Template-derived repos gitignore both (`/*.tgz`, `/pkg`).
- **Tracked `pkg/`:** if the repo tracks `pkg/` despite the ignore, packaging deletes tracked files. Restore them with `git restore pkg` instead of committing the deletion, and flag it for the maintainer (`git rm -r --cached pkg`).
- **Smoke test:** catch ESM runtime errors that `tsc` and vitest miss:
  ```bash
  node --input-type=module -e "const m = await import('./pkg/<id>/main.js'); console.log(typeof m.default, m.UpgradeScripts.length)"
  ```
- **esbuild warnings:** tools v3 bundles with esbuild, which may print warnings such as `[direct-eval]` for modules that `eval()` device data. They are not failures, and `companion-module-check` still exits 0. esbuild doesn't rename symbols in scopes that contain a direct eval, so names the eval relies on survive. Check the packaged code if in doubt.
- **Source manifest version:** if `companion/manifest.json` carries a real `version` (not `0.0.0`), bump it together with `package.json`.
- **`HELP.md` formatting:** if it already failed prettier at baseline, don't let lint-staged reformat unrelated content in the docs commit. Record it as pre-existing.
