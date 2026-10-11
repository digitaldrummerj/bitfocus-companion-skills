# Stand-in device server

A stand-in server pretends to be the device or app a module talks to, so the module connects, builds its definitions and sends real requests while you watch. Build one only after the reviewer chose it (SKILL.md, Phase 2b).

## How to derive it

Read the module's client code, not the vendor's docs:

| Question | Where to look (devcore-mixingstation v2.0.0 example) |
| --- | --- |
| Transport, framing, request/reply matching | `src/ms/MixingStation.ts`: one WebSocket, JSON `{ path, method, body }`; a reply matches a request with the same `path` + `method`; errors carry an `error` field; value pushes arrive on `/console/data/get/<path>/val` |
| Every request it sends | the same file: `GET /app/state`, `/app/mixers/available`, `/console/data/paths`, `/console/information`, `POST /console/data/subscribe`, `…/unsubscribe`, `/console/data/set/<path>/val`, `GET /console/data/get/<path>/val`, `/console/data/definitions2/<path>` |
| Reply shapes | `src/ms/Model.ts` (`AppStateDto`, `ConsoleListDto`, `DataPathsDto`, `ConsoleInformationDto`, `ValueDto`) |
| What it waits for before building definitions | `src/CompanionDataFactory.ts`, `src/main.ts`: `topState: "connected"`, then the path tree and the console information |

For other transports the same questions apply: a TCP module's line terminator and command grammar, a UDP/OSC module's addresses and argument types, an HTTP module's routes and JSON.

## Rules

- Small, realistic fake data: a few channels or inputs, a current value per valid path.
- Answer what you know; send the protocol's error reply for anything else.
- Log **every** request with a timestamp, and flag unknown paths with `!!`. The log is the evidence.
- Take libraries from the module's own `node_modules` by path (an argument), so nothing gets installed.
- Use a free, non-default port, and point the test page's connection config at `127.0.0.1:<port>`.

## Example: devcore-mixingstation (WebSocket + JSON)

Run with `node mock-ms.cjs <clone>/node_modules/ws 18080 > mock.log 2>&1` in the background.

```js
// Minimal stand-in for the Mixing Station WebSocket API, for live-testing the
// devcore-mixingstation review (H1/H2/L2). Logs every request the module sends.
// Usage: node mock-ms.cjs <path-to-ws-package> [port]
const WebSocket = require(process.argv[2])
const port = Number(process.argv[3] || 18080)

const tree = {
  child: {
    ch: {
      child: Object.fromEntries(
        ['0', '1', '2', '3'].map((id) => [id, { child: { mix: { val: ['lvl', 'on'] } } }]),
      ),
    },
    fx: { child: { 0: { child: { par: { val: ['mix'] } } } } },
    main: { child: { 0: { child: { mix: { val: ['lvl'] } } } } },
  },
}

// Every valid value path and its current value
const values = {}
for (const id of ['0', '1', '2', '3']) {
  values[`ch.${id}.mix.lvl`] = -20
  values[`ch.${id}.mix.on`] = true
}
values['fx.0.par.mix'] = 10
values['main.0.mix.lvl'] = -5

const log = (...a) => console.log(new Date().toISOString().slice(11, 23), ...a)

const server = new WebSocket.WebSocketServer({ port })
log(`mock Mixing Station listening on ws://127.0.0.1:${port}`)

server.on('connection', (ws) => {
  log('module connected')
  const reply = (path, method, body, error) => ws.send(JSON.stringify({ path, method, body, error }))
  const sendValue = (p) => reply(`/console/data/get/${p}/val`, 'GET', { value: values[p], format: 'val' })

  ws.on('message', (data) => {
    const msg = JSON.parse(data.toString())
    const { path, method, body } = msg
    log('<-', method, path, body ? JSON.stringify(body) : '')

    if (path === '/app/state') return reply(path, method, { state: 'connected', topState: 'connected' })
    if (path === '/app/mixers/available')
      return reply(path, method, {
        consoles: [{ manufacturer: 'Mock', name: 'Mixer', consoleId: 1, modelEnums: [{ id: 0, name: 'M1' }] }],
      })
    if (path === '/console/data/paths') return reply(path, method, tree)
    if (path === '/console/information')
      return reply(path, method, {
        totalChannels: 4,
        channelColors: [],
        channelTypes: [{ offset: 0, stereo: false, name: 'Ch', shortName: 'Ch', count: 4, type: 0, signalTargets: [] }],
        rtaFrequencies: [],
        dbfsOffset: 0,
      })

    if (path === '/console/data/subscribe' || path === '/console/data/unsubscribe') {
      const p = body.path
      if (!(p in values)) {
        log('   !! unknown path', p)
        return reply(path, method, null, 'Unknown path ' + p)
      }
      if (path.endsWith('/subscribe')) sendValue(p)
      return
    }

    let m = path.match(/^\/console\/data\/get\/(.+)\/val$/)
    if (m) {
      if (!(m[1] in values)) {
        log('   !! unknown path', m[1])
        return reply(path, method, null, 'Unknown path ' + m[1])
      }
      return sendValue(m[1])
    }

    m = path.match(/^\/console\/data\/set\/(.+)\/val$/)
    if (m) {
      if (!(m[1] in values)) {
        log('   !! SET on unknown path', m[1])
        return reply(path, method, null, 'Unknown path ' + m[1])
      }
      values[m[1]] = body.value
      log('   == SET', m[1], '=', JSON.stringify(body.value), 'fade', JSON.stringify(body.fade))
      return sendValue(m[1])
    }

    m = path.match(/^\/console\/data\/definitions2\/(.+)$/)
    if (m) return reply(path, method, { value: { type: 'bool', enums: null }, node: null })

    log('   (unhandled)')
  })
  ws.on('close', () => log('module disconnected'))
})
```

What its log showed (H1, a doubled channel path after the upgrade):

```text
17:30:37.632 <- POST /console/data/set/ch.3.mix.lvl/val {"value":-10}          (v1.0.1)
17:31:29.767 <- POST /console/data/set/ch.3.ch.3.mix.lvl/val {"value":-10}     (v2.0.0)
17:31:29.767    !! SET on unknown path ch.3.ch.3.mix.lvl
```
