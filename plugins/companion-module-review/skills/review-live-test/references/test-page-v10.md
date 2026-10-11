# Test Page Template: Companion page export, format 10

A format-10 page export (Companion 4.2) imports cleanly into Companion 5. Companion runs its own migrations on it, `v10tov11` through `v16tov17`. `v10tov11` wraps **every** module option into `{ isExpression: false, value }`, and `v12tov13` converts the plain `button` into a `button-layered`. So write the options **bare**, exactly as the old module version saved them, and let Companion produce the real stored form.

Verified against Companion `main` @ `b615afd` (2026-10-05): `companion/lib/Data/Upgrade.ts` (`upgradeImport`), `Data/Upgrades/v10tov11.ts`, `v12tov13.ts`, and `ImportExport/ImportFixup.ts`. The last one sets each imported entity's `upgradeIndex` from the connection's `lastUpgradeIndex`.

## Generator

```python
import json

CONN = 'testConn01'               # any id; only used inside the file
MODULE_ID = 'biamp-tesira'        # manifest id
VERSION_UNDER_TEST = '4.0.1'      # moduleVersionId, must be installed in Companion
LAST_UPGRADE_INDEX = -1           # len(old version's UpgradeScripts) - 1


def action(aid, definition_id, options):
    # options: BARE values, using the OLD version's action and option ids
    return {'type': 'action', 'id': aid, 'definitionId': definition_id,
            'connectionId': CONN, 'options': options}


def button(text, bgcolor, down, up=()):
    return {
        'type': 'button',
        'options': {'stepProgression': 'auto', 'rotaryActions': False},
        'style': {'text': text, 'textExpression': False, 'size': 'auto',
                  'alignment': 'center:center', 'pngalignment': 'center:center',
                  'color': 0xFFFFFF, 'bgcolor': bgcolor, 'show_topbar': 'default', 'png64': None},
        'feedbacks': [],
        'localVariables': [],
        'steps': {'0': {'action_sets': {'down': list(down), 'up': list(up)},
                        'options': {'runWhileHeld': []}}},
    }


page = {
    'version': 10,
    'type': 'page',
    'companionBuild': '4.2.0-review-live-test',
    'oldPageNumber': 99,
    'page': {
        'name': f'{MODULE_ID} live test ({VERSION_UNDER_TEST})',
        'gridSize': {'minColumn': 0, 'maxColumn': 7, 'minRow': 0, 'maxRow': 3},
        'controls': {
            '0': {   # row 0; keys are column numbers
                '0': button('C1\\nHOLD UP', 0x8B0000,
                            [action('c1', 'incFaderLevelTimer', {'rate': 250, 'command': 'increment'})]),
                '2': button('CONTROL', 0x006400,
                            [action('ctrl', 'setFaderLevel', {'level': -10})]),
            },
        },
    },
    'instances': {
        CONN: {
            'label': f'{MODULE_ID}_live_test',
            'moduleId': MODULE_ID,
            'moduleVersionId': VERSION_UNDER_TEST,
            'updatePolicy': 'manual',
            'config': {'host': '127.0.0.1'},   # the OLD version's config field ids
            'isFirstInit': False,
            'lastUpgradeIndex': LAST_UPGRADE_INDEX,
            'enabled': True,
            'sortOrder': 0,
        },
    },
    'connectionCollections': [],
}

open('test-pages/<module>-<scenario>.companionconfig', 'w').write(json.dumps(page, indent=2))
```

## Filling it in

- **Action and option ids** come from the **old** version (`git show <oldTag>:<actions file>`), not the reviewed one. The upgrade script is what renames them.
- **Values:**
  - Use realistic values that differ from the defaults (e.g. a 250 ms interval when the default is 500), so a lost value is visible.
  - Keep each option's old type: numbers as numbers, dropdown ids as their string ids.
- **`lastUpgradeIndex`:** count the old version's `UpgradeScripts` entries and subtract 1. If the old version is API v1, the entries are in `upgrades.js` or in the `runEntrypoint(..., UpgradeScripts)` argument.
- **Control button:** add one whose migration only renames ids, so you can tell "the script didn't run" apart from "the script wrote bad values".
- **Button text:** `\\n` in the Python string becomes a `\n` line break in Companion's button text.
