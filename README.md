# wgsplit

Route chosen domains through a WireGuard tunnel on macOS. Everything else goes direct.

WireGuard routes by IP CIDR and has no concept of domains, which makes a rule like
`*.herokuapp.com` impossible with stock WireGuard — Heroku resolves to shared,
rotating AWS addresses, and any CIDR wide enough to catch them would capture far
more than you want. wgsplit wraps [sing-box](https://sing-box.sagernet.org/), whose
TUN inbound sniffs the TLS SNI off each connection and routes on the **hostname**
instead.

## Install

```bash
make run
```

That vendors sing-box, builds, bundles and launches. Use `make run` rather than
`open dist/WGSplit.app` — `open` will not relaunch an app that is already
running, so a rebuild silently keeps the old process. `make run` quits it first.

| Target | Does |
| --- | --- |
| `make run` | rebuild and relaunch the app |
| `make build` | build and bundle, no launch |
| `make install` | install the daemon from the terminal |
| `make uninstall` | remove the daemon and quit the app |
| `make status` | daemon, socket and tunnel state |
| `make logs` | tail the daemon log |
| `make test` | run the suite |

The app bundle is self-contained. On first launch the menu offers
**Install Helper…**, which elevates via `osascript` and asks for your password
in the standard macOS dialog — no terminal needed. It copies `wgsplitd` and
`sing-box` to root-owned `/Library/PrivilegedHelperTools/wgsplit/` and loads the
LaunchDaemon. The daemon deliberately runs from that copy, never from inside the
app bundle: root executing a binary in a user-writable location would be a
privilege-escalation path.

Move `WGSplit.app` to `/Applications` before installing if you want Start at
Login to stick — `SMAppService` wants a stable location.

For development, the same script still works from a checkout:

```bash
swift build -c release && sudo ./Scripts/install-daemon.sh
```

## Use

1. **Import Tunnels from Zip…** — point it at a WireGuard export zip.
2. **Edit Domains…** — one pattern per line.
3. **Start.**

**Start at Login** is in the menu. It uses `SMAppService`, which wants a stably
located, properly signed bundle — if it refuses, move `WGSplit.app` to
`/Applications` and toggle it again. The menu shows the real error rather than
failing quietly.

| Pattern | Matches |
| --- | --- |
| `*.niteo.co` | `niteo.co` and every subdomain |
| `niteo.co` | `niteo.co` only |

Patterns broader than two labels (`*`, `*.com`) are rejected — a typo there would
route most of the internet through your tunnel.

## Architecture

| Component | Runs as | Responsibility |
| --- | --- | --- |
| `WGSplitKit` | library | Parsing, pattern compilation, config generation (pure, tested) |
| `wgsplitd` | root daemon | Owns state, generates config, supervises sing-box |
| `WGSplit.app` | user | Menu-bar client |

The daemon generates sing-box config itself, and the socket protocol carries only
declarative intent — which tunnel, which patterns. If the app could send config or
a config path, socket access would mean root code execution.

Applying a change runs `sing-box check` first, and leaves the running process alone
if it fails. If the new process then dies within 5 seconds, the daemon rolls back to
the last known-good config. `check` passing is necessary but not sufficient — a
config can validate and still fail at startup.

## Status reporting

The menu reports three states. Health is an **active probe**: the daemon asks
sing-box's clash_api to time a request through the `wg-out` outbound, so it
measures whether the tunnel actually carries traffic.

| Menu bar icon | Headline | Meaning |
| --- | --- | --- |
| pulsing plain shield | Working… | a request is in flight |
| `lock.shield` | Stopped | sing-box is not running |
| `lock.shield.fill` | Connected · not passing traffic | up, but the probe fails — e.g. a wrong key |
| `checkmark.shield.fill` | Connected · Niteo DE · 42 ms | probe succeeded, with measured latency |

An earlier version counted live connections via `/connections`, which was wrong:
that endpoint lists only currently-open connections, so ordinary short requests
finished before any poll could see them. The probe is deterministic and, unlike
connection counting, actually detects a broken tunnel.

The probe runs at most every 20s, off the request thread, so a status query never
blocks on the network.

clash_api is bound to `127.0.0.1` on a random high port with a random secret,
generated once and persisted `0600` beside `state.json`. Only the daemon reads it;
it is never exposed over the control socket.

## Known limitations
- Only sniffable protocols (TLS, HTTP, QUIC) can be routed by name. A raw TCP
  connection to a bare IP has no hostname and falls through to direct.
- `AllowedIPs` in imported configs is ignored by design; domain rules decide routing.

## Development

```bash
swift test              # full suite
./Scripts/vendor-singbox.sh   # required for SingBoxCheckTests
```

`SingBoxCheckTests` pipes generated config through the real pinned binary. It is the
test that catches a sing-box upgrade breaking the config schema.

## Uninstall

```bash
sudo ./Scripts/uninstall-daemon.sh
```
