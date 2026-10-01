---
name: companion-v2-config
description: '(@companion-module/base v2.x) Reference for Companion v2 module configuration: a ModuleConfig type alias (must satisfy JsonObject), secret-text fields stored in a separate typed secrets object, init/configUpdated/saveConfig with secrets, isVisibleExpression instead of isVisible functions, minLength instead of required, bonjour-device fields, width layout and Regex constants. Use when asked to add config fields, connection settings (host, port, credentials), conditional fields or passwords in a v2 module. Does NOT apply to v1 modules — use companion-config; for converting v1 config code use companion-v1-to-v2-migrate-definitions.'
license: MIT
---

# Companion v2 Config Skill

Connection configuration for `@companion-module/base` **v2.x**.

## When to Use This Skill

- Defining `GetConfigFields()` and the `ModuleConfig` type
- Storing credentials safely as **secrets**
- Showing or hiding fields conditionally
- Handling `init` / `configUpdated` / `saveConfig` in v2

---

## Key API Types

### `ModuleConfig` (and `ModuleSecrets`)

```typescript
export type ModuleConfig = {
	host: string
	port: number
	protocol: string
	enablePolling: boolean
	pollInterval: number
	device: string | null
}

export type ModuleSecrets = {
	password: string
}
```

- Use a **`type` alias**, not an `interface`. `InstanceTypes.config` must satisfy `JsonObject`, and interfaces have no implicit index signature.
- Values must be JSON-safe: string, number, boolean, null, arrays and objects. No `Date`, `Map` or `undefined`-only fields.
- Put the types in `ModuleSchema`: `config: ModuleConfig`, `secrets: ModuleSecrets` (or `secrets: undefined` if there are none).

### `SomeCompanionConfigField`

`getConfigFields()` returns `SomeCompanionConfigField[]`. Every field needs a `width` from 1 to 12.

---

## Config Field Types

| `type` | Value | Notes |
|---|---|---|
| `textinput` | `string` | `regex`, `minLength` (replaces v1 `required`), `default?` |
| `number` | `number` | `min`, `max`, `default`, `step?`, `range?` |
| `checkbox` | `boolean` | `default` |
| `dropdown` | `string \| number` | `choices`, `default`, `allowCustom?`, `minChoicesForSearch?` |
| `multidropdown` | array | `choices`, `default: []`, `minSelection?`, `maxSelection?`, `sortSelection?` |
| `colorpicker` | `number` (or `string`) | `default`, `enableAlpha?`, `returnType?` |
| `static-text` | — | `value`. Display only |
| `bonjour-device` | `string \| null` | Pairs with `bonjourQueries` in the manifest. `null` means manual entry |
| `secret-text` | `string` | Stored in **secrets**, not config. `minLength?`, `regex?` |

All fields support `tooltip`, `description` and `isVisibleExpression`.

---

## Patterns & Examples

### Basic config with conditional fields and a secret

```typescript
import { Regex, type SomeCompanionConfigField } from '@companion-module/base'

export function GetConfigFields(): SomeCompanionConfigField[] {
	return [
		{
			type: 'static-text',
			id: 'info',
			label: 'Information',
			width: 12,
			value: 'Enter the IP address of your device.',
		},
		{
			type: 'bonjour-device',
			id: 'device',
			label: 'Device',
			width: 6,
		},
		{
			type: 'textinput',
			id: 'host',
			label: 'Target IP',
			width: 8,
			regex: Regex.IP,
			minLength: 1,
			isVisibleExpression: '!$(options:device)',
		},
		{
			type: 'number',
			id: 'port',
			label: 'Target Port',
			width: 4,
			min: 1,
			max: 65535,
			default: 8000,
			isVisibleExpression: '!$(options:device)',
		},
		{
			type: 'dropdown',
			id: 'protocol',
			label: 'Protocol',
			width: 6,
			choices: [
				{ id: 'tcp', label: 'TCP' },
				{ id: 'udp', label: 'UDP' },
			],
			default: 'tcp',
		},
		{
			type: 'secret-text',
			id: 'password',
			label: 'Password',
			width: 6,
			minLength: 4,
		},
		{
			type: 'checkbox',
			id: 'enablePolling',
			label: 'Enable polling',
			width: 6,
			default: true,
		},
		{
			type: 'number',
			id: 'pollInterval',
			label: 'Poll interval (ms)',
			width: 6,
			min: 100,
			max: 60000,
			default: 1000,
			isVisibleExpression: '$(options:enablePolling)',
		},
	]
}
```

### Conditional visibility

`isVisible: (options) => …` functions are **not supported in v2**; Companion ignores them. Use an expression string over the other fields:

| v1 | v2 |
|---|---|
| `isVisible: (o) => !!o.enablePolling` | `isVisibleExpression: '$(options:enablePolling)'` |
| `isVisible: (o) => o.mode === 'manual'` | `isVisibleExpression: '$(options:mode) == "manual"'` |
| `isVisible: (o) => !o.device` | `isVisibleExpression: '!$(options:device)'` |

### Lifecycle with secrets

```typescript
export default class ModuleInstance extends InstanceBase<ModuleSchema> {
	config!: ModuleConfig
	secrets!: ModuleSecrets

	async init(config: ModuleConfig, _isFirstInit: boolean, secrets: ModuleSecrets): Promise<void> {
		this.config = config
		this.secrets = secrets
		this.updateDefinitions()
		this.connect() // don't await the device here
	}

	async configUpdated(config: ModuleConfig, secrets: ModuleSecrets): Promise<void> {
		this.config = config
		this.secrets = secrets
		this.disconnect()
		this.connect()
	}

	rememberPassword(password: string): void {
		this.saveConfig(this.config, { ...this.secrets, password })
	}
}
```

- `init(config, isFirstInit, secrets)` and `configUpdated(config, secrets)` both receive secrets.
- `saveConfig(config, secrets)` persists both. It does **not** call `configUpdated`. When `secrets` is `undefined` in the schema, use the single-argument `saveConfig(config)`.
- `secret-text` values never reach `config`. They exist only in the secrets object. The whole config object **and the keys** of the secrets object are reported to the web UI, so keep sensitive values in secrets.
- `init()` must return promptly. Start the connection and report progress with `updateStatus(InstanceStatus.Connecting)`.

### Validating config

```typescript
private connect(): void {
	if (!this.config.host) {
		this.updateStatus(InstanceStatus.BadConfig, 'Missing host')
		return
	}
	this.updateStatus(InstanceStatus.Connecting)
	// ...
}
```

---

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| `interface ModuleConfig` | Use `type ModuleConfig = {…}` (it must satisfy `JsonObject`) |
| `isVisible: (opts) => …` | Not supported. Use `isVisibleExpression` |
| `required: true` | Replaced by `minLength: 1` |
| Password in a `textinput` / v1 `secret` field stored in config | Use `secret-text` and the secrets object. Move existing values with an upgrade script (`updatedSecrets`) |
| Expecting `saveConfig` to trigger `configUpdated` | It doesn't. Apply the change yourself |
| Duplicate field `id`s | **2.1+ (Companion 5.0+)** drops later duplicates and logs a warning |
| Awaiting the connection inside `init` | Return quickly and connect in the background |
| `bonjourdevice` / `secret` from older docs or skills | The real type names are `bonjour-device` and `secret-text` |

## Import Reference

```typescript
import { Regex, InstanceStatus, type SomeCompanionConfigField } from '@companion-module/base'
```

## Related Skills

- **`companion-v2-module-scaffold`** — `ModuleSchema` and the lifecycle in `main.ts`
- **`companion-v2-upgrades`** — migrate old config fields and move passwords into secrets
- **`companion-v2-api-compliance`** — review checklist
- **`companion-config`** — the v1 equivalent

## Regex Constants Reference

`Regex.IP`, `Regex.HOSTNAME`, `Regex.PORT`, `Regex.BOOLEAN`, `Regex.MAC_ADDRESS`, `Regex.PERCENT`, `Regex.FLOAT`, `Regex.SIGNED_FLOAT`, `Regex.FLOAT_OR_INT`, `Regex.NUMBER`, `Regex.SIGNED_NUMBER`, `Regex.SOMETHING`, `Regex.TIMECODE`.
