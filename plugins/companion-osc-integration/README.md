# Companion OSC Integration

Integrate OSC transport, lifecycle management, and state updates into a Bitfocus
Companion module. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You need to add OSC UDP or TCP communication to a module.

- You want OSC lifecycle code isolated from the main instance class.

- You need to send OSC commands from actions or helpers.

- You must process inbound OSC messages into state, variables, and feedback updates.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-osc-integration@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-osc-integration/` in your project.

## What It Covers

- How to structure an `OSC` class and wire it into Companion lifecycles.

- Socket setup, teardown, error handling, and keepalive patterns.

- Typed send and receive handling with the `osc` npm package.

- State updates, variable writes, and feedback refreshes from incoming messages.

## Example Requests

- "OSC integration"

- "OSC UDP"

- "help with osc integration"

## Activation Hints

- It is a strong match for requests about `OSC integration`.

- It also fits prompts mentioning `OSC UDP`.

- Use it when work is clearly about Bitfocus Companion modules and `osc`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
