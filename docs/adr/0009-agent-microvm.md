# ADR-0009: One microVM per agent session

**Status:** Accepted
**Date:** 2026-11-27
**Issue:** #353, a sub-issue of the compartments epic #419 (its P0 development tier)
**Relates to:** ADR-0007 (the operator stays a trusted Nix user on the host; this ADR keeps
agents from inheriting that), ADR-0008 (muninn is the test host),
`docs/research/compartments/00-synthesis.md` (PR #433). Credentials: #354 (GitHub App tokens),
#402 (LLM egress gateway).

## Context

Agent sessions (Claude Code with its MCP servers and hooks) run as the operator. They can read
`~/.ssh`, both GitHub logins, `~/.claude/.credentials.json` and, once they exist, the sops keys.
They reach the whole tailnet, including mimir, and they talk to the host's Nix daemon as a
trusted user, which is root-equivalent (ADR-0007, decision 2). The likeliest way into the fleet is
not a network attacker. It is a poisoned package, MCP server, README or web page that steers an
agent holding all of that.

The owner's decisions (2026-11-26 and 2026-11-27, #353 and #419) are: one microVM per agent
session, built on microvm.nix; agents are the first workload to get compartments; KVM with
cloud-hypervisor now, seL4 later; muninn is the first host. The synthesis fixes the development
tier's shape: a store share limited to the session's closure (read-only, not the whole
`/nix/store`), vsock, no tailnet or LAN route, an egress allowlist, and no ssh keys or long-lived
tokens in the guest. This tier is the bootstrap. The end state is a compartment image that
Voltaic (#417) generates; this ADR does not try to be that.

## Threat model

**In scope.** The agent and everything it runs are hostile: the model's own tool calls, MCP
servers, hooks, build scripts, `npm`/`cargo`/`pip` post-install code and test suites. Any of them
may hold root inside the guest. The adversary wants to:

1. read the operator's secrets (ssh keys, GitHub logins, the Anthropic login, sops keys);
2. reach other hosts (tailnet, LAN, mimir's trading services);
3. run code on the host, either through a VMM or device-backend bug, or through a channel the
   host trusts (the Nix daemon, git hooks, files the operator later executes);
4. persist across sessions;
5. exfiltrate the repository's working state, or push changes the operator did not review;
6. exhaust the host (memory, disk, CPU) until oomkiller or the kernel takes down real work.

**Out of scope for this tier.** Microarchitectural side channels between guests and host
(muninn keeps SMT on; the synthesis's SMT rule applies from P3); a compromised host kernel,
cloud-hypervisor itself (we take its seccomp filters as they are); GitHub or Anthropic as
adversaries; the operator pasting secrets into a guest. A malicious change that the operator
reviews and merges is a review problem, not an isolation one.

## Decisions

### 1. microvm.nix for the guest and its runner; our own host units

The guest is a NixOS system built with `microvm.nixosModules.microvm`, and it is started by
microvm.nix's generated runner (`config.microvm.declaredRunner`, `bin/microvm-run`) used as it is.
We do **not** use microvm.nix's host module (`microvm.host`, `microvm.vms`). It runs every VM as
one shared user `microvm` in group `kvm`, and it runs virtiofsd as root under supervisord. One
shared uid means one guest that escapes its VMM can open every other guest's disks and sockets,
and a root virtiofsd is the largest piece of host code a guest can talk to.

Instead, `features/virtualisation/microvm-host` declares, per VM:

- a **static system user of its own** (`agent-vm-<n>`), which owns only that VM's state
  directory, its tap device and its sockets;
- the VMM unit, running the runner as that user with systemd's sandboxing: `ProtectSystem=strict`,
  `ProtectHome=yes`, `PrivateTmp`, `NoNewPrivileges`, an empty `CapabilityBoundingSet`,
  `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK`, `DeviceAllow` limited to
  `/dev/kvm` and `/dev/net/tun`, and `MemoryMax`/`TasksMax`/`CPUQuota` limits (decision 9);
- one virtiofsd per share, as the same user, in its own unit with the same sandbox and
  `TemporaryFileSystem=/` plus a bind of the share alone, so a path escape out of the share finds
  an empty root;
- a root oneshot that creates the tap as a persistent device owned by that user (the only root
  step, and it does not touch guest data).

**Hypervisor: cloud-hypervisor**, as the synthesis chose: a Rust VMM with seccomp filters on by
default (`--seccomp true` in the runner), about 13 MB per VM, hybrid vsock over a Unix socket, and
virtio-fs. Firecracker has no virtio-fs; QEMU is a much larger host TCB.

### 2. The store: the session's closure only, on a read-only image

The guest does **not** get the host's `/nix/store`. microvm.nix's `storeOnDisk` builds an erofs
image of exactly the guest's closure and attaches it read-only. That is the synthesis's
"closure-scoped read-only share", and it already has the shape of the end state (an erofs image
per closure). It also removes a whole class of leaks: a shared `/nix/store` makes every path on the
host readable in the guest, so any secret that ever reached the store (#340) would be in every
agent's reach.

Builds write to an **overlay** (`microvm.writableStoreOverlay`) on a per-session ext4 volume,
deleted and recreated at every session start. Nothing written to the overlay reaches the host's
store.

### 3. The build path: the guest builds for itself

This is the hard question. Four options were weighed.

| Option | What the guest can do to the host | Verdict |
|---|---|---|
| **The host daemon's socket**, forwarded into the guest | As a trusted user: root on the host (`--option` overrides, store writes). As an untrusted user it still chooses which derivations the host builds, so attacker-chosen code runs on the host in the build sandbox, with network access for fixed-output derivations; it adds paths to the store every host process trusts; and it exposes the C++ daemon's whole protocol parser, which has had memory-safety bugs. | **Rejected.** |
| **vbuild** (`rust/tools/vbuild`, the fleet's load-aware build hook) | vbuild hands builds to fleet builders over ssh as a trusted user. The guest would need an ssh key and a route to the builders: both are things this ADR exists to remove. | **Rejected.** |
| **vcache only**: the guest substitutes and never builds | Nothing, but it cannot do the job. Every changed derivation, every devenv shell and every crate a ticket touches needs a build. | **Rejected** as the only path; kept as a substituter. |
| **A builder VM** per build, the guest asking a host broker to start it | Nothing beyond what a guest can already do, if the broker is small and the builder VM is as locked down as the guest. This is the synthesis's end state ("Nix builders get one throwaway VM per build"). | **Deferred** to P2/P3: it needs the image generator (#417) and a typed channel, neither of which exists yet. |
| **The guest's own daemon** on the overlay store | Nothing: the guest is already a throwaway VM, so a build inside it *is* a build in a throwaway VM. | **Chosen.** |

So the guest runs its own `nix-daemon` against its overlay store. It substitutes from
cache.nixos.org and nix-community.cachix.org through the egress proxy. Its temporary build
directories are on the session volume, not in guest RAM. Results leave the guest only as a git
branch (decision 6), and CI builds them again. drakkar's vcache stays out of reach for now: it
listens on the tailnet, and the guest has no tailnet route. Offering it read-only on a bridge
address is a follow-up, worth doing on drakkar and of no use on muninn, which serves no cache.

### 4. Network: no route, one proxy per VM, an allowlist by name

- Each VM has one tap device, `agvm<n>`, on its own /24 (`10.233.<n>.0/24`; host `.1`, guest `.2`).
  The guest has **no default route and no DNS server**. The host does not forward for these
  interfaces (FORWARD drops them both ways), so a guest cannot reach the LAN, the tailnet,
  another guest or the internet by address.
- The host firewall admits exactly one port from each tap: that VM's own proxy.
- **The proxy is tinyproxy**, used as it is, one instance per VM, listening on that VM's host
  address. Its filter is a default-deny allowlist of host names: GitHub (`github.com`,
  `api.github.com`, `codeload.github.com`, `*.githubusercontent.com`), the Nix caches, Anthropic's
  API, and the crates.io, npm and PyPI registries. HTTPS goes through `CONNECT`, so the proxy sees
  the name, not the content. Git, Nix, cargo, npm and Claude Code all honour `https_proxy`.
- **The proxy itself cannot reach private addresses.** Its unit carries
  `IPAddressDeny=` for 10/8, 172.16/12, 192.168/16, 100.64/10 (the tailnet), 169.254/16,
  127/8 except its own listener, fc00::/7 and fe80::/10, with `IPAddressAllow=` for its own /24
  only. So an allowlisted name that resolves to a fleet address still goes nowhere.
- **The proxy resolves names through public resolvers** (Quad9), from a `resolv.conf` bound into
  its unit, with `nscd` hidden from it. It never sees MagicDNS or the LAN resolver, so fleet names
  do not resolve.

A domain allowlist needs a proxy; nftables or iptables alone can only filter addresses, and
GitHub's and Anthropic's addresses change.

### 5. vsock: readiness and the operator's terminal

Each guest has vsock. cloud-hypervisor exposes it on the host as a Unix socket in the VM's state
directory (hybrid vsock), so no CID is global and every guest can use the same one. That is part
of why every slot runs one and the same guest system: the tap, the address and the agent's host
uid are supplied at run time by the slot's units, and the host evaluates one guest, not N. The
vsock carries two things and nothing else:

- systemd's readiness notification (microvm.nix's notify socket), so the VM unit is "started"
  only once the guest has booted. That is also how start-up time is measured.
- **ssh over vsock** for the operator's terminal. systemd's ssh generator in the guest binds sshd
  to `vsock::22` only; sshd has no TCP listener. The launcher connects with
  `ssh agent@vsock-mux/<state dir>/notify.vsock` (systemd-ssh-proxy). The key pair is **made per
  session by the launcher**, on the host, and deleted at teardown. The guest receives the public
  half only. No private key and no operator key is ever inside a guest; "no ssh keys in the guest"
  holds in the sense that matters, which is that nothing in the guest opens anything else.

The socket is group-accessible to the `agent-vm` group (the operator). Other users of the host,
and other VMs' users, cannot connect to it.

### 6. The working copy is a clone, not a host git worktree

The issue says "worktree". A `git worktree` keeps its `gitdir` in the host repository
(`.git/worktrees/<name>`), so mounting it would mean sharing the host's `.git` too. A guest that
can write the host's `.git/config` or `.git/hooks` runs code as the operator on the next host
`git` command: `core.hooksPath`, `core.fsmonitor`, `core.sshCommand` and the hooks themselves are
all commands. So:

- **The guest's working copy is a fresh clone of the base ref from GitHub, made inside the guest**
  at session start, into `/work/repo`. The host writes no repository content into the share.
- **The host never runs git inside the share.** The launcher reads exactly one file the guest
  writes, a `git bundle` of the session branch, and only when the operator asks to export.
  It fetches that bundle into the operator's repository (pack parsing is the same exposure as
  fetching from any untrusted remote) and pushes it to **`agent/<session>`**, a prefix the launcher
  enforces; the guest cannot name the target branch.
- `/work` is a host directory owned by the VM's own user, the only read-write share. It holds the
  clone, the guest user's home (and so the session's Claude Code transcripts), and the session's
  inputs. It is emptied when the next session in that slot starts.

### 7. Credentials

- **GitHub.** In this tier the guest holds **no GitHub credential at all**. It clones the public
  repository anonymously, and its work leaves through the launcher's export (decision 6), which
  pushes with the operator's own login on the host. When #354's App exists, a guest may receive a
  one-hour installation token, scoped to the session's repository, for API calls such as opening
  a PR. It arrives in the session inputs, is never written outside `/work`, and expires on its
  own. Pushes stay on the export path either way, so the prefix rule keeps holding.
- **Anthropic.** The target is that the login never enters the guest. #402's gateway runs on the
  host side of the tap, the guest gets `ANTHROPIC_BASE_URL` pointing at it and a random
  per-session bearer, and the gateway swaps in the real credential. Until #402 exists, **the guest
  logs in for itself** (`claude /login`, a separate OAuth grant from the operator's). The grant
  lives in `/work/home/.claude`, so it is gone when the slot is next used, and it can be revoked
  at claude.ai on its own. This is the one place where P0 falls short of "no long-lived tokens in
  the guest": a session-scoped grant of a refresh token. It is recorded here as an accepted
  exception that ends with #402, not as the design. The host's `.credentials.json` is never
  shared, mounted or copied.
- **Transcripts** stay on the host, under the VM's `/work`, outside the public claude-setup tree.
  The launcher copies them, without following symlinks, to
  `~/.local/state/vagent/transcripts/<session>/` at teardown.

### 8. What is deliberately still shared

- The host kernel and KVM, and cloud-hypervisor's device emulation: a VMM or KVM bug is a host
  compromise. This is the synthesis's starting substrate; seL4 is the answer, later.
- virtiofsd, one per VM, unprivileged and sandboxed. It is the largest piece of host code the
  guest talks to. The share is one directory owned by that VM's user.
- The tinyproxy binary and the public resolvers (each VM has its own proxy process).
- **GitHub, as an exfiltration channel.** Anything that may fetch from GitHub may post to a gist
  or an issue anywhere. An allowlist by name cannot stop that; #402 and per-path policy can
  narrow it later.
- **CI on agent branches.** Pushing `agent/*` runs the repository's push-triggered workflows with
  the code the guest wrote. Workflows that hold secrets must not run on `agent/*`; a ruleset for
  the prefix is a follow-up.
- CPU caches and SMT siblings (muninn keeps SMT on).
- The public part of the guest closure is built from the same nixpkgs as the host, so the host's
  store holds every guest path. That is harmless (the image is read-only), and it is how the
  erofs image is built at all.

### 9. Resource limits

Each VM is a slot with fixed limits, set by `features.ai.agent-vm`:

| | Default | Why |
|---|---|---|
| Guest memory | 4096 MiB, with a virtio balloon that deflates on guest OOM | Enough for Claude Code, its MCP servers and a cargo build; the host sees it as the VMM's resident memory |
| VMM unit `MemoryMax` | guest memory + 1024 MiB | The VMM and its page tables; the cgroup, not oomkiller's whole-host view, is what stops one VM |
| vCPUs | 4 (`CPUQuota=400%`) | Three VMs fill muninn's 12 threads without starving the desktop entirely |
| Session volume | 32 GiB sparse ext4 | The overlay store and build directories; created per session |
| `TasksMax` | 512 per VMM, 256 per virtiofsd | virtiofsd threads plus the VMM's vCPU and I/O threads |
| Slots | 3 on muninn | 3 × (4 + 1) GiB = 15 GiB of muninn's 31 GiB, at the top of the range |

KSM stays off between VMs: virtio-fs needs shared memory, which cloud-hypervisor does not mark
mergeable, and the synthesis forbids KSM across compartments anyway.

### 10. The launcher is Voltaic + id_effect

`rust/tools/vagent` (Voltaic 0.3.0, id_effect 0.13.0, flat `src/*.vlt`, `build.rs`).
`vagent run --slot <n> --branch <name> [--base main]` writes the session inputs, starts the slot's
units, waits for readiness, attaches the terminal over vsock, and on exit copies the transcripts,
optionally exports the branch, and stops the slot. Acquire and release are one bracket, so a
crash or Ctrl-C still stops the VM and deletes the session key. The operator may start and stop
only the `agent-vm-*` units, granted by a polkit rule to the `agent-vm` group; no sudo.

The way back to a host session is plain `claude` on the host, which this ADR leaves untouched.

## Consequences

- An agent in a guest cannot read `~/.ssh` or any host secret, cannot reach a fleet host or a
  name outside the allowlist, cannot write outside `/work`, and cannot talk to the host's Nix
  daemon. A NixOS VM test checks each of these from inside a guest, on a host that imports the
  real STIG test-host profile, and switches the feature in and out live.
- Sessions are slower to start (a VM boot, a fresh clone, cold substitution) and builds happen
  twice (in the guest, then in CI).
- One more class of host code (cloud-hypervisor, virtiofsd, tinyproxy) is now reachable by
  hostile input.
- Rollout is muninn first, as #419's 2026-11-27 decision says; drakkar follows once three
  concurrent sessions run cleanly there. #353's "drakkar only" is amended accordingly.
- Rollback: `features.ai.agent-vm.enable = lib.mkForce false;` on the host; the feature is off
  everywhere by default.

## Follow-ups

- #402: the credential-injecting gateway, which ends the Anthropic exception in decision 7.
- #354: App tokens for API calls from a guest.
- vcache on a bridge address for guests on drakkar.
- A ruleset for `agent/*` and a CI rule that secret-bearing workflows do not run there.
- Live terminal resize and a session longer than the token lifetime.
- Builder VMs and the image generator (P2/P3 of #419) replace the in-guest daemon and the
  microvm.nix image.
