# vdaemon-proxy

A worker-protocol proxy in front of nix-daemon (#157). Every client of the daemon socket
goes through it: each op is logged as one JSON line, each client is connected upstream with
its own uid and gid, so the daemon's trusted-users and allowed-users see the real client.
Read-only ops can be answered from the store database (#183).
Voltaic 0.3.0 (`src/*.vlt`) with id_effect 0.13.0, on nix-store-core's worker protocol and
read-only database. The NixOS side, with its sockets, fallback and probes, is
`features/nix/vdaemon-proxy`.

## Modes

- **Relay** (always): bytes are copied both ways unchanged; the tap (`src/tap.vlt`)
  follows op boundaries and names paths for the log.
- **Conformance** (`conformance.nix`): for each of the six read-only ops, the proxy also
  computes its own answer and compares it byte for byte with nix-daemon's; the client
  always gets the daemon's. Differences are logged and counted (`conformance.prom`).
- **Native** (`native.nix`, per op): an op in `VDAEMON_NATIVE` is answered by the proxy.
  Only the six read-only ops can be listed, and each is flipped only after a clean
  conformance period on drakkar, in its own PR. There is an instant kill switch per op
  (`/run/vdaemon-proxy/forward-<Op>` or `forward-all`).

## Ops kept forwarded, and why (#244)

Every write, build and GC stays nix-daemon's: a native version would own side effects that
cannot be shown equal, for no win worth the risk. See the table on #244 and the header of
`features/nix/vdaemon-proxy/native.nix`. In short:

- **Temp, indirect and perm roots:** the GC's lock-based liveness test, for a round trip.
- **Adding to the store:** SQLite writes racing nix-daemon and the GC lock; one bad row
  spreads fleet-wide through vcache.
- **Builds:** already delegated, since vbuild is the daemon's build hook.
- **GC:** the GC lock and every root.

## Stopping: the drain (#224)

A switch that changes the proxy restarts it while builds (vci's, a user's) may be connected
through it. On SIGTERM the proxy:

1. stops accepting. systemd keeps the socket listening, so new clients wait in its
   backlog and are served by the next start, never refused;
2. gives the open connections `DRAIN_SECS` (25 s) to finish, checking every 200 ms on an
   id_effect Schedule;
3. closes whatever is still open, then returns normally, so `run_main`'s finalizers
   write the totals and the exit is 0 (before #224, SIGTERM ended it by signal, exit 143,
   with no totals).

The unit's `TimeoutStopSec` is 40 s: 15 s above the drain, for the finalizers.

## Tests

- **Crate:** cargo test, also the package's checkPhase.
- **VM tests** (features/nix/vdaemon-proxy):
  - `vdaemon-proxy-vm`: the base test;
  - `-native-vm`, `-conformance-vm`;
  - `-live-switch-vm`: switched in and out of a running system, and a restart that drains
    a build connected through the proxy while a new client is queued and served.
