# 00: Per-program compartments: synthesis

Research date 2026-11-27. This document distils reports 01–04 in this directory into one design
direction. Every number cited here has its source URL in the report it comes from.

## The ask

The goal is a fleet where **every program runs in its own hardware-isolated compartment**,
reaches only the channels it has been granted, and holds only the resources it needs. The policy
is **derived from types**: the `R` of id_effect programs, plus type descriptions we write
ourselves for foreign software. The bar is world class, ahead of QubesOS. Servers and agents
come first; the desktop stays on the host OS for now. A smaller trusted computing base (TCB) is
better. This epic is blocked by Industrial/nixos-dotfiles#417.

## Owner decisions (2026-11-27)

| Question | Decision |
|---|---|
| Granularity | **One compartment per program.** Overhead is accepted. Extra compute may be rented VPS whose results are shared back to the fleet. |
| Foreign software | We write its capability types by hand. Policy is still derived from types. |
| Scope | Servers and agents first. The desktop runs on the host OS for now and must work eventually. |
| Trusted computing base | The smaller the better. |
| Epic structure | A separate epic, blocked by #417. |
| id_effect | The work goes into the id_effect release train before the API freeze. |

## Design direction

### 1. Substrate: start on KVM, target seL4 (report 01)

- **Target: seL4**, using the Microkit framework, the libvmm VM library, the sDDF driver
  framework and rust-sel4. Its static system description, which lists protection domains,
  memory regions and channels, already says "only the granted channels". The strongest proofs
  (functional correctness plus integrity and confidentiality) are for **aarch64 running as
  hypervisor**. x86_64 has C functional correctness only: no VT-x proof and no confidentiality
  proof. No configuration on any architecture has proofs covering the IOMMU, multicore or boot.
- **x86 Linux guests on seL4 are not ready yet.** Guests get one vCPU, and PCIe passthrough is
  a prototype targeted at Q4 2026. libvmm and LionsOS are still alpha.
- **Start on:** a stripped NixOS host running KVM and cloud-hypervisor (crosvm where a GPU is
  needed). Drivers go in their own VMs behind VFIO and the IOMMU, and each device back-end is a
  separate jailed process.
- **Rule:** generate one **static, flat system description** of compartments, memory regions
  and channels, in the spirit of seL4's capDL. It needs two backends from day one: the KVM
  realiser, and seL4 Microkit's `.system` format. Moving to seL4 then means retargeting, not
  rewriting.
- **Fleet fact:** drakkar is a Ryzen 9 7950X, an x86 consumer part with a TPM 2.0 and no
  SEV-SNP. The verified seL4 path needs aarch64 hardware the fleet does not have yet.

### 2. Density: one per program is affordable (report 02)

The guest OS is the cost, not the VMM. Firecracker's VMM costs about 3 MB and cloud-hypervisor's
about 13 MB, while stock Kata+Firecracker costs about 94 MB per sandbox. RunD shows that under
20 MB is reachable in production: more than 2,500 sandboxes on a 384 GB node.

| Guest form | RAM per compartment | On a 64 GB host |
|---|---|---|
| Minimal microVM: shared pre-patched kernel, program as PID 1 | ~38 MB | ~1,500 |
| The same, started from a snapshot template (REAP/FaaSnap-style working-set prefetch) | ~30 MB | ~1,900 |
| Hermit unikernel, for fork-free id_effect services | ~18 MB | ~3,100 |
| Hyperlight micro-VM, for the wasm-portable id_effect core and untrusted parsers | VM in 1–2 ms, calls in µs | n/a |
| seL4 protection domain (estimate) | 20–40 KiB, IPC ~750 cycles | horizon |

At a few hundred programs per host, the binding costs are I/O and channel crossings, programs
that fork helpers, and cgroup overhead. RAM is not. Nix builders get one throwaway VM per build.
Databases get a dedicated VM with NVMe and hugepages.

Hard rules:

- **KSM stays off** between compartments (Flush+Reload, Dedup Est Machina, Flip Feng Shui).
- Share only public, read-only bytes.
- Every clone made from a snapshot is reseeded.
- Simultaneous multithreading is off, or each core is assigned to one compartment.

### 3. Policy from types (report 03)

The best model to copy is **Fuchsia's use/offer/expose capability routing**. Its weakness is
that the manifests are written by hand; ours are generated.

- **Keep three things separate:**
  - the *kind* of capability, from `R`;
  - which *provider instance* fills it, from the Voltaic topology;
  - *how much* it may do: restrictions, quotas and allowlists.

  Qubes merges all three into string rules, and its policy drifts.
- **`use` is generated** from the program's remaining `R`. The build fails on a route that is
  unsatisfied, unused or disallowed.
- **Policy is a build output:** a flat system description checked by a **small, independent
  checker**, and the only input the host realiser accepts. This follows the seL4 chain
  CAmkES → capDL → proven initialiser. Ghaf fetching policy from URLs at runtime is the
  anti-pattern.
- **Pass capabilities, not names.** Use Cap'n Proto/OCapN semantics: narrowable, revocable, and
  delegated by three-party handoff. This removes the confused deputy that comes with qrexec's
  string-named services.
- **Reachability is not information flow.** Each compartment carries a secrecy label and an
  integrity label. Every channel is checked against those labels across the whole graph.
  Declassification happens only in explicit declassifier compartments. A deputy that serves
  several labels runs as one instance per label. The analysis covers the whole Layer graph, so
  authority a Layer captures internally is counted.
- **Genode-style quota donation:** the client pays for the session state it causes in the
  server. This gives DoS protection by construction. Each session also carries a label the
  program cannot forge.
- **Make `R` nearly sound inside a compartment:**
  - lints against ambient std authority;
  - cap-std-style handles;
  - no dynamic environment (`DynEnv`) at the roots;
  - seccomp and Landlock profiles generated from the manifest as defence in depth.
- **Closest prior art for the whole plan: Singularity**: sealed processes, typed channel
  contracts, and manifests generated from code and checked at install time.

### 4. Channels

- **Transport:** typed RPC that carries capabilities, generated from the capability traits.
  - Between trust levels it is a *copying* channel: vsock with TLS and channel binding.
  - Shared-memory rings (vhost-user, IVSHMEM, seL4 shared memory with notifications) are a
    speed tool *within* a trust label. They invite double-fetch bugs, so they are not a
    boundary.
- **Wiring:** fixed top-level wiring comes from the system description, and narrower
  capabilities are handed out at runtime. A portal compartment mediates user files.

### 5. Build, identity and attestation (report 04)

- **One closure, one image, one identity.** Per compartment, Voltaic (#417) emits:
  - a read-only **erofs image with dm-verity** containing exactly that closure;
  - a UKI whose command line carries the verity root hash and the manifest digest;
  - `measurement.json` and `provenance.json`.

  The provenance chain is derivation → output → NAR hash → root hash → measurement, so a
  compartment's identity is its derivation.
- **Reconciling the store's isolation with density.** Report 02 favours one read-only DAX
  virtio-fs store shared by all guests. Report 04 shows that a shared `/nix/store` exposes every
  path to every guest, needs a large host-side file server, leaks through the shared page
  cache, and blocks migration. The synthesis: the **per-closure verity image is the boundary**.
  Density comes from sharing only *content-identical, public* read-only blobs, such as the
  guest kernel, libc and the id_effect runtime, as DAX-mapped devices, which erofs supports
  through multi-device blobs and chunk deduplication. **Validate this with measurements first.**
- **Development tier only:** agent VMs on microvm.nix with a closure-scoped read-only
  virtio-fs share and vsock (the 2026-11-26 decision). This tier is the bootstrap, not the end
  state.
- **Local hosts:** measured boot with Secure Boot and TPM2 (#292). Per-compartment keys are
  derived DICE-style from a host secret sealed in the TPM. This is smaller than a vTPM per
  guest.
- **Rented VPS:** prefer SEV-SNP bare metal running our own hypervisor (for example OVH), so
  the measurement is computed entirely by our build. Cloud confidential VMs are a lower tier.
  **The VPS provider stays untrusted** even so: TEE.fail (October 2025) extracted keys from
  SEV-SNP and forged TDX quotes with a cheap memory-bus interposer. VPS outputs therefore enter
  the fleet only on **k-of-n agreement of NAR hashes** across independent builders, and VPS
  nodes hold minimal secrets or none.
- **Vault compartment:** on mimir, with a standby on drakkar. It runs on local, TPM-attested
  hardware only, with today's sops files as its backing store. It releases secrets only to
  attested identities.
- **Volumes:** each compartment gets an encrypted, tamper-detecting volume. Its key comes from
  an identity that survives upgrades, and a rollback counter is kept in the vault.

### 6. Mesh: what id_effect has to change

ADR 0009's same-binary assumption ("FLAME") fails in four places:

- membership rests on a shared cookie;
- remote spawn by behaviour name assumes the other node has the code;
- any process ID can be messaged by anyone who knows it;
- the protocol is versioned cluster-wide.

`id_effect_rpc`'s typed contracts and RPC over the mesh, with the verified calling node as
principal, are the base to build on. The full list of changes is in the release plan below.

## Release plan

### id_effect

The compartments work is inserted **before** the API freeze, because it shapes the mesh, RPC and
capability APIs. The later releases are renumbered by +2:

| Release | Name | Content |
|---|---|---|
| 0.13.1 | Portable | in progress |
| 0.14.0 | Sweep & promote + Warden | Warden's agents are the first workloads to get compartments |
| **0.15.0** | **Compartments I: Sealed** | <ul><li>ADR 0018 heterogeneous mesh</li><li>ADR 0019 channel capabilities</li><li>contract identity</li><li>vsock transport</li><li>attested handshake v4</li><li>capability manifest export from `R` (use/offer/expose)</li><li>lints against ambient authority</li><li>`CompartmentSupervisor` and the `Hypervisor` capability</li><li>`compartment-init`</li><li>ADR 0009 Amendment 2</li></ul> |
| **0.16.0** | **Compartments II: Attested** | <ul><li>`id_effect_attest`</li><li>placement constraints</li><li>vault building blocks</li><li>channel quotas and session labels</li><li>information-flow labels and the declassifier check</li><li>a `no_std + alloc` core and shared-memory transport for seL4 Microkit</li></ul> |
| 0.17.0 | Medium items + AppHost | was 0.15 |
| 0.18.0 | Scale | was 0.16 |
| 0.19.0 | Ergonomics & cloud | was 0.17 |
| 0.20.0 | Consolidation | was 0.18 |
| 0.21.0 | Adoption & release candidate | was 0.19 |
| 1.0.0 | Stability | |

### dotfiles

The dotfiles epic is blocked by #417. Its phases:

| Phase | Deliverable | Depends on |
|---|---|---|
| P0 | microvm.nix host with closure-scoped agent VMs | — |
| P1 | Per-host trust facts in `fleet.nix` | P0 |
| P2 | The Voltaic compartment image generator | #417 |
| P3 | Compartment manager, guest kernel, first leaf services migrated | P1, P2, #292 |
| P4 | Vault and per-compartment volumes | P3 |
| P5 | Attestation verifier and the VPS tier | P3, P4 |
| P6 | Migration of every service, then seL4/Microkit targets | — |

## Open questions for the owner

1. **Identity:** a fleet CA in the attestation compartment, or pure DICE chains to TPM and
   vendor roots with no CA? A CA makes revocation and VPS admission simpler.
2. **VPS shape:** OVH SEV-SNP bare metal with our own hypervisor, or cloud confidential VMs? And
   is the VPS tier compute-only with verifiable outputs, so it never talks to the vault?
3. **Live migration:** is it required anywhere, or is crash-only plus state hand-off acceptable
   fleet-wide?
4. **Hardware:** buy aarch64 servers for the verified seL4 path, which is where the strongest
   proofs are, or wait for seL4 on x86 to mature?
5. **Agent VMs:** do they move to the production image format, or stay on the shared-store
   development tier?

## Unverified figures

The reports flag these; check them before quoting externally:

- the line counts for NOVA (17k), Xen (270k) and KVM (~150k);
- Microkit's x86 support status;
- round-trip latency of vsock;
- per-VM figures for Hermit and crosvm;
- the cycle costs of a VM exit;
- the items marked *(recalled)* in report 03.
