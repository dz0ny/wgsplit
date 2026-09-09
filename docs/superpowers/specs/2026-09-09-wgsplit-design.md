# wgsplit — domain-based split tunneling for macOS

**Status:** approved design
**Date:** 2026-09-09

## Problem

WireGuard routes by IP CIDR (`AllowedIPs`). It has no concept of domains.
Routing `*.herokuapp.com` through a tunnel is therefore impossible with stock
WireGuard: Heroku resolves to shared, rotating AWS load balancer addresses, and
any CIDR wide enough to catch them would capture unrelated traffic.

The goal is whole-machine, transparent routing where the decision is made on
**hostname**, not address: named domains go through a WireGuard tunnel,
everything else goes out the normal interface.

## Approach

Wrap `sing-box`, which already implements this. Its TUN inbound captures all
system traffic; a `sniff` route action reads the TLS SNI / HTTP Host off each
connection, so routing rules match hostnames before any IP is involved. A
WireGuard endpoint carries matched traffic; `final: direct` carries the rest.

This was validated manually against sing-box 1.14.0 before the design was
written: config generated, `sing-box check` passing, tunnel running, and a
request to a Heroku review app served through it.

## Decisions

| Decision | Choice | Reason |
|---|---|---|
| Form factor | Menu-bar app + installed root daemon | sing-box needs root for TUN; a daemon avoids re-authenticating on every toggle |
| Tunnel model | One active tunnel at a time | Rules become a flat list with no target column; multi-tunnel routing is unneeded complexity |
| sing-box source | Bundled, version-pinned in `Resources/` | Config format broke twice between 1.12 and 1.14; generator targets one known version |
| Privilege boundary | Daemon generates config; app sends declarative rules | Prevents socket access from becoming root code execution |
| Repo | `dz0ny/wgsplit`, private, commits direct to main | Solo repo, no history to protect (explicit override of the usual branch+PR rule) |

### Why the daemon generates the config

sing-box config can specify arbitrary behavior. If the app could hand the root
daemon a config blob or a config *path*, anything able to write the socket would
gain root code execution. The socket protocol therefore carries only declarative
intent — which tunnel, which patterns — and the root side renders it. This is
the single most important constraint in the design.

## Architecture

SwiftPM workspace, three targets.

| Target | Runs as | Responsibility |
|---|---|---|
| `WGSplitKit` | library | Models, wg-quick/zip parser, config generator, protocol types |
| `wgsplitd` | root daemon | Owns state, generates + validates config, supervises sing-box, serves socket |
| `WGSplit.app` | user | Menu-bar UI, zip import, socket client |

Supporting scripts: `Scripts/bundle.sh` (assemble `.app`, embed pinned sing-box),
`Scripts/install-daemon.sh` (one-time `sudo` install of daemon + LaunchDaemon plist).

### Filesystem

| Path | Owner | Contents |
|---|---|---|
| `/Library/Application Support/WGSplit/state.json` | root `0600` | Tunnels (incl. private keys), rules, active tunnel |
| `/Library/Application Support/WGSplit/config.json` | root `0600` | Generated sing-box config |
| `/Library/Application Support/WGSplit/config.last-good.json` | root `0600` | Rollback target |
| `/var/run/wgsplit.sock` | `root:staff` `0660` | Control socket |

### Socket protocol

Five messages, JSON over a Unix stream socket. None carries sing-box config or a
filesystem path.

- `status` → running state, active tunnel, rule count, last error
- `importTunnel(Tunnel)` → persist a parsed tunnel
- `setActiveTunnel(id?)` → select or clear
- `setRules([Rule])` → replace the rule list
- `setEnabled(Bool)` → start/stop sing-box

### Apply sequence

1. Daemon persists new `state.json`.
2. Regenerates `config.json` from state.
3. Runs bundled `sing-box check`. On failure: leave the running process
   untouched, return the error. Nothing breaks.
4. On success: stop sing-box, start on the new config.
5. If the new process exits within 5s: restore `config.last-good.json`,
   restart, surface the error.
6. On staying up 5s: promote current config to `config.last-good.json`.

Step 5 exists because `sing-box check` exited 0 on a config that then died at
startup (a `detour` pointing at a bare direct outbound). Schema validation is
necessary but not sufficient; "starts and stays up" is the real test.

## Config generation

Targets the exact 1.14.0 shape validated by hand:

- `dns-direct` server with **no** `detour` (1.14 rejects a detour to a bare direct outbound)
- `route.default_domain_resolver` present (1.14 removed the implicit fallback)
- Route rules ordered: `sniff` → `hijack-dns` → domain matches → `final: direct`
- `dns-wg` emitted only when the imported tunnel declares `DNS =`; otherwise
  omitted and routing runs on SNI alone
- TUN inbound `172.19.0.1/30`, `auto_route`, `strict_route`, `stack: gvisor`

### Pattern translation

| User writes | Generates | Matches |
|---|---|---|
| `*.niteo.co` | `domain_suffix: [".niteo.co"]` + `domain: ["niteo.co"]` | apex and subdomains |
| `niteo.co` | `domain: ["niteo.co"]` | exact only |

`*.x` including the apex is deliberate: strictly the glob means subdomains only,
but a rule that silently misses `niteo.co` is a bug in the user's eyes. Documented in the UI.

**Guards.** The generator rejects `*`, `*.com`, and any pattern under two
labels. A typo there routes most of the internet through the tunnel, so this
refuses rather than warns.

## Zip import

App-side, via `WGSplitKit`. Reads every `.conf` in the archive, parses the
wg-quick INI, names each tunnel from its filename (`Niteo DE.conf` → "Niteo DE"),
sends each as `importTunnel`. Encrypted archives fail with an explicit message.

Parsed: `PrivateKey`, `Address`, `DNS`, `MTU`, `PublicKey`, `PresharedKey`,
`Endpoint`, `PersistentKeepalive`.

**`AllowedIPs` is deliberately discarded.** The generated endpoint always uses
`0.0.0.0/0`, because what gets routed is decided by domain rules, not by
WireGuard's own routing. Without this note the code reads like a bug.

## Known limitations

- **Status shows "sing-box is running", not "the tunnel is handshaking."**
  Distinguishing them needs sing-box's experimental Clash API or log scraping;
  neither earns its complexity in v1. A bad key therefore shows as connected
  until traffic fails.
- **Sniffing only sees hostnames for parseable protocols** (TLS, HTTP, QUIC). A
  raw TCP connection to a bare IP has no hostname and falls through to `direct`.
  Fine for web apps; fake-IP DNS mode would be the fix if it ever matters.
- **DNS hijack is not fully effective.** During validation a direct request
  still egressed over IPv6 despite `strategy: ipv4_only`, indicating some
  queries resolve outside the TUN. Routing is unaffected because rules match on
  sniffed SNI, not on DNS.

## Testing

`WGSplitKit` holds the coverage, being pure functions:

- Parser against fixture `.conf` files and a fixture zip
- Generator against golden JSON
- Pattern translation and guard rejections
- **Integration: generated config piped into the bundled `sing-box check`** —
  the test that catches a version bump breaking config, which is the failure
  mode actually observed twice during design
- Daemon rollback logic against a fake process supervisor

No UI tests. CI on a GitHub Actions macOS runner: `swift build`, `swift test`.

## Out of scope for v1

Multiple simultaneous tunnels, per-rule tunnel targets, fake-IP DNS mode,
handshake health reporting, Developer ID signing and notarization, auto-update.
