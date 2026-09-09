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
./Scripts/vendor-singbox.sh       # pinned sing-box 1.14.0 into Resources/
swift build -c release
sudo ./Scripts/install-daemon.sh  # one-time root daemon install
./Scripts/bundle.sh && open dist/WGSplit.app
```

## Use

1. **Import Tunnels from Zip…** — point it at a WireGuard export zip.
2. **Edit Domains…** — one pattern per line.
3. **Start.**

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

## Known limitations

- Status reports that sing-box is **running**, not that the tunnel is handshaking.
  A bad key shows as connected until traffic fails.
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
