# 04: Compartments, build, delivery, attestation and mesh

Research for the "every program in its own hardware-isolated compartment" epic. This epic is
blocked by Industrial/nixos-dotfiles#417 (NixOS as IaC on Voltaic + id_effect, emitting `.drv`
files that `nix-store-core` / `vbuild` realise).

Status: research and proposal only. Nothing was installed, built or changed. External facts
carry URLs. Statements marked **[verify]** are things I believe but could not confirm from a
primary source during this pass.

---

## 0. Thesis in one paragraph

A compartment is **one closure, one image, one identity**. The build (Voltaic → `.drv` →
`vbuild`) produces, per compartment, a read-only **erofs + dm-verity image of exactly that
closure**. It also produces a **UKI** (kernel + minimal Rust init + cmdline carrying the verity
root hash and the compartment's wiring manifest digest), and the **expected launch measurement**
as a build output. The measurement is therefore a pure function of the derivation, and the
compartment's identity *is* its derivation. Locally, the host's compartment manager derives a
per-compartment key **DICE-style** from a TPM-sealed host secret and that measurement. On rented
VPS, the guest is a **confidential VM** (SEV-SNP first, TDX second), and the same measurement
is checked by a fleet verifier before the verifier issues a mesh certificate. Compartments talk
only over **encrypted, mutually-attested channels** (vsock locally, QUIC across hosts). Each
channel is typed by an **id_effect_rpc contract with a content digest**. Channels are **statically
wired** by the system description (measured), with **attenuated capability passing** allowed
only from those roots. A VM is a supervised process: `CompartmentSupervisor` is an
`id_effect_process` `ChildSpec` whose `start` boots a VM. Secrets never touch the store. A
vault compartment releases them to attested identities, and per-compartment state lives on
dm-crypt+integrity volumes keyed by a **sealing** identity that survives upgrades.

---

## 1. Threat model and TCB layering

Threats (from the 2026-11-26 security decisions): supply chain + agents, opportunistic network,
theft/physical, compliance evidence. To these the epic adds **an untrusted VPS provider**.

| Layer | Local host (drakkar, mimir, huginn, muninn) | Rented VPS |
|---|---|---|
| Hardware root | TPM2 + Secure Boot (planned after #292) | AMD-SP / Intel TDX module (+ quoting enclave) |
| In TCB | firmware, host kernel + KVM, compartment manager, VMM (per-VM, sandboxed) | CPU vendor firmware, guest firmware (if ours), guest kernel, guest init |
| Not in TCB | other compartments, guest-to-guest network | provider's host kernel, VMM, disks, network, **but see TEE.fail (§3.6)** |

The host kernel is the TCB floor on Linux/KVM hosts, and only the seL4 track (§2.5) moves below
it. Everything above that is engineering to keep the host-side per-VM code small, in a memory-safe
language, and sandboxed: VMM, virtio device backends, compartment manager.

---

## 2. Building compartments

### 2.1 Prior art

**microvm.nix.** A NixOS module set that turns a NixOS config into a runner for one of several
VMMs (qemu, cloud-hypervisor, crosvm, firecracker, kvmtool, alioth, stratovirt). The two store
options that matter here are `microvm.shares` (virtio-fs/9p shares, typically the host's
`/nix/store` read-only) and `microvm.storeOnDisk`, which boots with a store disk image "unless
the host's /nix/store is a microvm.share". It also exposes `microvm.credentialFiles` (systemd
credentials) and cloud-hypervisor `platformOEMStrings`.
<https://microvm-nix.github.io/microvm.nix/microvm-options.html>.
microvm.nix is the right **bootstrap substrate**: it already works, and the 2026-11-26 decision
picked it for agent VMs on drakkar. It is not the end state: it builds *full NixOS guests*, its
default store path is the shared host store, and its generator is Nix-the-language, which #417
replaces.

**Ghaf (TII).** A hypervisor host built on NixOS + microvm.nix, with system VMs `netvm`,
`guivm`, `adminvm` (plus storage VMs), composed in three layers (base module → platform profile
→ orchestration handing the evaluated config to microvm.nix) via `extendModules`. Inter-VM
control runs over **GIVC**, a gRPC framework.
<https://ghaf.tii.ae/ghaf/overview/arch/system-architecture/>,
<https://ghaf.tii.ae/ghaf/dev/architecture/vm-composition/>,
<https://ghaf.tii.ae/ghaf/dev/technologies/hypervisor_options/>,
<https://ghaf.tii.ae/givc/overview/arch/>. Lessons: per-role VMs, typed RPC between VMs, and
"compose the VM from modules" all work at product scale. But Ghaf VMs are coarse-grained (one
VM per *role*, not per program), and they are full NixOS systems with systemd.

**Spectrum OS.** Each application runs in its own cloud-hypervisor VM, with a netvm as the
system VM and crosvm only as the virtio-gpu / cross-domain Wayland backend. Spectrum's ADR 005
picks cloud-hypervisor as primary VMM, citing snapshotting and live migration.
<https://www.spectrum-os.org/design.html>,
<https://spectrum-os.org/git/spectrum/tree/Documentation/decisions/005-virtual-machine-monitor.adoc>,
<https://spectrum-os.org/git/spectrum/tree/Documentation/about/architecture.adoc>.
Spectrum is the closest philosophical match ("each application in its own VM", s6-style
supervision, a minimal host). Its mailing list is candid about **virtiofsd sandboxing**: a
separate PID/mount namespace and uid per VM helper, and the virtiofsd cache-mode resource-leak
trade-off. <https://lists.spectrum-os.org/archives/list/devel@spectrum-os.org/thread/5PF72BVCRTLRQUVFAMKVWRCTKPE7YIMI/>.
Its logs also record a virtio-fs export for one VM being mountable from another, a
misconfiguration class worth designing out. <https://logs.spectrum-os.org/spectrum/2020-08-28>.

**seL4 + Nix + Rust.** `rust-sel4` provides Rust bindings for the seL4 API, a root-task runtime
and a **Microkit protection-domain runtime**, and its `hacking/` tree develops and tests the
crates under Nix. <https://github.com/sel4/rust-sel4>,
<https://docs.sel4.systems/projects/rust/how-to-use.html>. Microkit builds *static* systems
from a system description of PDs, memory regions and channels. <https://github.com/sel4/microkit>.
sDDF (driver framework, ships a Nix flake) and LionsOS (componentised OS on seL4 with virtio
console/block/net) supply drivers and Linux driver-VMs.
<https://github.com/au-ts/sddf>, <https://trustworthy.systems/projects/LionsOS/>,
<https://trustworthy.systems/projects/drivers/devvirt>. DLR-FT maintains Nix expressions for
the seL4 ecosystem, including a Microkit dev shell. <https://github.com/DLR-FT/seL4-nix-utils>.

### 2.2 Shared `/nix/store` over virtio-fs: why not, as the end state

| Concern | Detail |
|---|---|
| **Confinement** | Sharing the host store exposes *every* store path to every guest: other compartments' code, configs, and anything that leaked into the store (the store is world-readable by design). A guest is not confined to its closure. |
| **Host attack surface** | virtiofsd is a host-side FUSE server parsing guest requests on every file op. It is Rust and can be sandboxed, but it is a large, chatty, per-VM privileged-ish surface, and the hardest piece of the host to minimise. |
| **Side channels** | Shared host page cache across sandboxes that map the same files via virtio-fs is demonstrated as a cross-VM leakage channel. <https://arxiv.org/pdf/2607.17518> |
| **Performance** | Metadata ops over virtio-fs are much slower than over virtio-blk because the host remains the metadata authority. <https://modal.com/blog/vm-sandbox-filesystem> |
| **Migration** | virtio-fs historically blocked live migration, and virtiofsd migration support is pre-copy-only work in progress. <https://listman.redhat.com/archives/virtio-fs/2021-March/002933.html>, <https://issues.redhat.com/browse/RHEL-40135> |
| **CVMs** | Pointless for confidential guests: the host serves the files, so integrity must be re-established inside the guest anyway. |

Confining a virtio-fs share to "exactly the closure" is possible: build a per-compartment
directory of bind mounts of `closureInfo` paths and share only that. It still keeps virtiofsd,
the page-cache channel and the metadata cost. It is acceptable only for the **dev/agent tier**
(agent sessions that need a writable worktree anyway).

### 2.3 Per-closure read-only images (recommended)

Options:

1. **erofs image of the closure + dm-verity hash tree (block device).** One `virtio-blk`
   read-only disk per compartment. erofs is designed as an auditable image filesystem, mountable
   without loop devices. <https://erofs.docs.kernel.org/en/latest/imagefs.html>. dm-verity
   gives a single root hash that commits to every byte. nixpkgs already has the plumbing:
   `image.repart.verityStore` (verity-protected store partition) and
   `boot.initrd.systemd.dmVerity` with a `nix-store-veritysetup` generator reading
   `storehash=` from the cmdline. <https://code.fizz.buzz/talexander/nixpkgs/commit/942588c6866d55a252bdb3a7a0d4eef84162e987>,
   <https://github.com/nikstur/nix-store-veritysetup-generator>.
2. **composefs (erofs metadata + fs-verity'd content-addressed backing store).** Dedups
   identical files across images while keeping full data+metadata integrity, with the image
   digest in the cmdline/UKI. <https://github.com/containers/composefs/blob/main/README.md>,
   <https://lwn.net/Articles/933616/>. Better for disk use when many compartments share glibc
   etc. But the backing store must reach the guest, which brings back a shared filesystem
   (virtio-fs) or a shared block device.
3. **squashfs + dm-verity.** Works, but erofs is faster and is the direction the kernel and
   composefs took. No reason to prefer it.

**Recommendation:** option 1 for every production compartment. Disk cost is controlled two
ways. First, most compartments are small static Rust binaries plus a shared kernel, so closures
are tiny. Second, the host can dedup at the filesystem level (reflinks / btrfs/xfs), which never
crosses the trust boundary. Option 2 is a later optimisation, and only for a "fat" class where
the guest is trusted to see the shared backing store.

The image derivation, emitted by Voltaic (#417) and realised by `vbuild`:

```
compartment-<name>.drv  →  $out/
  root.erofs           # exactly closureInfo(<entrypoint>) + /etc generated from the manifest
  root.verity          # hash tree (or appended)
  uki.efi              # shared kernel + compartment-init + cmdline:
                       #   verity.root=<hash> manifest=<digest> init=/nix/store/…/bin/<entry>
  manifest.json        # contracts provided/required, channels, volumes, resources, trust tier
  measurement.json     # expected launch digests: local-DICE, SNP (per vCPU count/firmware), TDX MRTD/RTMR
  provenance.json      # drv path, output paths, NAR hashes, builder id, signatures (in-toto/SLSA style)
```

### 2.4 Guest shape: smaller than NixOS

Ghaf and microvm.nix guests are full NixOS with systemd. For a small TCB:

- **One guest kernel config** for the whole fleet (per arch): no modules, `lockdown=confidentiality`,
  only virtio-blk, virtio-vsock, virtio-rng, and virtio-net *only for compartments that hold a
  network capability*. No virtio-fs in production.
- **`compartment-init`** (Rust, id_effect, a few thousand lines) as PID 1. It verifies the verity
  root and mounts it. It reads the manifest, brings up vsock, obtains identity (§3), mounts and
  unlocks volumes (§5) and execs (or supervises in-process) the single program. Its exit reason
  goes to the host over a system vsock port. systemd is not needed for one program.
- **VMM:** cloud-hypervisor for general compartments (Rust, rust-vmm, Spectrum's choice); crosvm
  only where GPU/Wayland is needed (per-device jailed backends). Each VMM runs under its own uid,
  in its own mount/PID namespace, with seccomp, launched by the compartment manager.
  **Firecracker** is the minimal-device alternative if we never need virtio-gpu in a compartment.
- **CVM guests on VPS:** the VMM is *outside* the TCB, so use whatever the provider (or QEMU on
  rented bare metal) offers. QEMU has measured direct-kernel boot for SNP: kernel, initrd and
  cmdline hashes are placed in a page that becomes part of the launch measurement and checked by
  OVMF. <https://qemu.googlesource.com/qemu/+/c1996992cc882b00139f78067d6a64e2ec9cb0d8>,
  <https://github.com/AMDESE/AMDSEV/issues/93>. cloud-hypervisor's SEV-SNP support targets MSHV,
  and its TDX-on-KVM support has been in flux. **[verify]** against current releases before
  relying on it.

### 2.5 seL4 track (horizon, not v1)

The world-class endpoint replaces "Linux host + KVM" as the TCB floor with **seL4 + Microkit**.
Pure-Rust compartments become Microkit PDs using `rust-sel4`'s PD runtime. Anything needing
Linux (drivers, legacy programs) runs as a Linux VM under the seL4 VMM, using sDDF/LionsOS virtio
backends. A Microkit system description (PDs, memory regions, channels) is *exactly* the static
wiring manifest of §4.3, so the same Voltaic system description can target both backends.
Prerequisites on the id_effect side: a `no_std + alloc` core and a runtime without tokio. ADR
0017 "Portable by default" (wasm32 audit, tokio behind a native-only feature) is the first step;
the seL4 target is a second consumer of the same split. Nix tooling exists (rust-sel4 `hacking/`,
sDDF flake, DLR-FT seL4-nix-utils), so Voltaic needs to emit `.drv`s for the Microkit SDK
toolchain, not invent one.

---

## 3. Identity and attestation

### 3.1 What a compartment *is*, cryptographically

```
CompartmentMeasurement = H( uki.efi )             # kernel + init + cmdline
                       ⊇ verity.root              # every byte of the closure
                       ⊇ manifest digest          # contracts, channels, volumes, tier
```

Bind to the Nix store: the store path hash of input-addressed derivations is a hash of *inputs*,
not content, so it is not a measurement. The **verity root is the content measurement**, and
`provenance.json` (signed by the builder) maps `drv → output path → NAR hash → verity root →
measurement`. The attestation policy is then literally "the peer runs the output of derivation
D as built by builders {B…}". If the image derivation is made content-addressed (CA derivations
in `nix-store-core`), the output path itself becomes content-derived and the mapping simplifies.

**Reproducibility is part of attestation.** For results computed on untrusted hardware, and as
a supply-chain check on the build, a measurement is only trusted if k of n independent builders
produced the same NAR/verity root (drakkar + a VPS builder, say).

### 3.2 Local hosts: DICE-style derivation in the compartment manager (recommended)

Open DICE: each layer derives the next layer's **CDI** from its own CDI and the next layer's
code measurement. There is an **attestation CDI** over all inputs and a **sealing CDI** over
stable inputs only, which survives updates, and every layer issues a certificate for the next
layer's key. <https://pigweed.googlesource.com/open-dice/+/refs/heads/main/docs/specification.md>.
Android AVF does exactly this for pVMs: `pvmfw` verifies the payload and hands it a DICE chain and
CDIs only that instance can derive, and Microdroid refuses to boot (or boots clean) if its
`instance.img` was modified outside the guest. <https://source.android.com/docs/core/virtualization>,
<https://source.android.com/docs/core/virtualization/security>.

Fleet version:

1. Host measured boot (Secure Boot + TPM2, already planned) unseals a **host UDS** only if PCRs
   match, so a tampered host cannot get it.
2. Compartment manager computes `CDI_attest(c) = KDF(host_CDI, measurement(c) ‖ config)` and
   `CDI_seal(c) = KDF(host_CDI, contract-identity(c) ‖ signer ‖ instance-id)`.
3. It derives an Ed25519 keypair from `CDI_attest(c)` and issues a short X.509/CBOR cert chained
   to the host's DICE cert (itself attested by the TPM quote). The private key and `CDI_seal`
   are delivered to the guest over a host-only vsock port before the program starts, then the
   manager forgets them.
4. Peers verify the chain, the measurement and the manifest. No shared cookie.

Alternative: **swtpm vTPM per guest.** It is standard, but swtpm is a large C process per VM
in the host TCB, and DICE is a few hundred lines of KDF + signing. Use vTPM only for guests that
need TPM APIs (legacy software).

### 3.3 Rented VPS: confidential VMs

| Tech | Root of trust / evidence | Measurement of our image | Availability |
|---|---|---|---|
| **AMD SEV-SNP** | AMD-SP signs report with VCEK (chain to AMD ARK/ASK); 64-byte `REPORT_DATA` | launch digest covers firmware + (with measured direct boot) kernel/initrd/cmdline hashes | Azure DCasv5/ECasv5 (+v6), GCP N2D, IONOS; OVH bare metal with BIOS toggle and **our own hypervisor**. <https://techcommunity.microsoft.com/t5/azure-confidential-computing/azure-confidential-vms-dcasv5-ecasv5-using-amd-sev-snp/ba-p/2993530>, <https://docs.cloud.google.com/confidential-computing/confidential-vm/docs/supported-configurations>, <https://docs.ionos.com/cloud/home/compute-services/confidential-computing-vm>, <https://www.ovhcloud.com/en/bare-metal/uc-confidential-computing/> |
| **Intel TDX** | TDREPORT (64-byte REPORTDATA) → Quote via quoting enclave | MRTD (initial config + firmware), RTMRs (kernel, cmdline, initrd, ACPI) | major clouds **[verify per region]**. <https://docs.kernel.org/6.6/arch/x86/tdx.html> |
| **Arm CCA** | Platform token (HES) + Realm token (RMM, signed with RAK), EAT profile | Realm Initial Measurement (RIM) + REMs | mostly emulated/early hardware. Veraison has Rust token decoding and a verifier. <https://datatracker.ietf.org/doc/draft-ffm-rats-cca-token/>, <https://github.com/veraison/rust-ccatoken>, <https://learn.arm.com/learning-paths/servers-and-cloud-computing/cca-veraison/> |

Key distinction: on **public-cloud CVMs** (Azure, GCP), the guest firmware, and on Azure a
paravisor/vTPM, are the provider's. The measurement then includes provider-supplied components
whose reference values we have to take from the provider. That is weaker, though still useful.
On **rented bare metal with SNP enabled** (OVH), we run our own hypervisor and supply our own
OVMF/IGVM, so the launch digest is fully computed by our build (`measurement.json`). That is the
preferred VPS shape for the "world-class" bar. **COCONUT-SVSM** adds an in-guest, VMPL-isolated
vTPM. It is ephemeral today, with the EK bound into the SNP report, and persistent state is
proposed via a key from a remote attestation server.
<https://fosdem.org/2025/events/attachments/fosdem-2025-5412-updates-on-coconut-svsm-secure-services-and-stateful-devices-for-confidential-virtual-machines/slides/236799/FOSDEM_20_X5nuOWj.pdf>,
<https://kvm-forum.qemu.org/2024/KVMForum_2024_SVSM_attestation.v2_N45MQqI.pdf>.
Use it if TPM semantics are wanted inside the CVM; otherwise the raw SNP report plus our DICE
layer in `compartment-init` is smaller.

Note: CVMs generally **cannot live-migrate**. IONOS states that SNP hardware prevents live
migration and in-guest warm restarts, and that host maintenance causes downtime.
<https://docs.ionos.com/cloud/home/compute-services/confidential-computing-vm/confidential-vm-faq>.

### 3.4 Remote attestation flow (RATS background-check model)

Roles per RFC 9334 (<https://www.rfc-editor.org/rfc/rfc9334>): Attester = `compartment-init` in
the CVM; Verifier = fleet **attestation compartment** (local, on mimir/drakkar); Relying Party
= vault, mesh CA, and peers. Trustee/KBS is the reference design for "verify evidence → release
resource by policy, deny by default".
<https://docs.nvidia.com/datacenter/cloud-native/confidential-containers/latest/attestation.html>.

```
CVM boot ─ firmware measures UKI (kernel+init+cmdline{verity.root, manifest})
  │
  ├─ init: verity-mount root, generate ephemeral keypair K
  ├─ init → Verifier (QUIC over the internet, server-authenticated):  Hello, want nonce
  ├─ Verifier → init: nonce N
  ├─ init: report = SNP_GET_REPORT(REPORT_DATA = H(K.pub ‖ N ‖ manifest))
  ├─ init → Verifier: report, VCEK chain (or TDX quote), K.pub, provenance ref
  ├─ Verifier checks: vendor chain → TCB version ≥ policy → measurement ∈ reference values
  │     from measurement.json of a derivation that the fleet built reproducibly (k-of-n)
  │     → manifest digest matches → policy(tier=cvm-snp) permits this contract on VPS
  ├─ Verifier → init: mesh cert for K  (SPIFFE-style ID
  │     idm://fleet/<contract>@<measurement-prefix>/<instance>, TTL ~1h, renew by re-attest)
  └─ init → Vault (mesh, mutual cert): fetch secrets / volume key  (§5)
```

The mesh cert's extension carries the measurement and contract digests, so a relying peer can
check them offline (passport model) without calling the verifier per connection.

### 3.5 Binding identity end to end

`derivation D` → (vbuild, reproducible on ≥k builders) → `verity.root`, `manifest digest` →
embedded in UKI cmdline → in **launch measurement** (SNP), **RTMR** (TDX), or **DICE input**
(local) → in **mesh cert** → checked by every peer and by the vault. The chain has no unmeasured
links.

### 3.6 The physical caveat (provider with hands on the box)

TEE.fail (Oct 2025): a sub-$1000 DDR5 bus interposer exploits the deterministic AES-XTS memory
encryption to extract keys from SEV-SNP guests (even with Ciphertext Hiding) and **attestation
keys from TDX, enabling forged quotes**. AMD and Intel consider physical attacks out of scope.
Earlier DDR4 work (WireTap, Battering RAM) is in the same line.
<https://thehackernews.com/2025/10/new-teefail-side-channel-attack.html>,
<https://www.ieee-security.org/TC/SP2026/downloads/posters/sp2026posters-final75.pdf>,
<https://schneier.com/blog/archives/2025/11/new-attacks-against-secure-enclaves.html>.
Consequence for the design: a CVM on rented hardware raises the cost of attack. It does **not**
make the provider trusted. So:

- **Results from VPS are claims, not facts.** Build outputs are accepted into the fleet store
  only if reproducible: rebuilt and matched on a second provider, or spot-checked locally. This
  fits `vbuild` + NAR hashes naturally.
- **Secrets on VPS are minimal and scoped:** short-lived tokens, never long-term fleet keys or
  the vault master.
- Placement policy (§4.6) encodes a `trust tier`, and classified data never leaves `local-hw`.

---

## 4. Mesh: from same-binary FLAME to a heterogeneous, typed compartment mesh

### 4.1 What exists today (id_effect 0.13.x)

- `id_effect_node::transport::{Transport, Listener, Connection}`
  (`/data/Code/rust/id_effect/crates/id_effect_node/src/transport/mod.rs`): byte-frame pipes,
  `connect(&str)`/`listen(&str)`, and `Connection::channel_binding() -> Option<[u8;32]>` (TLS
  exporter). Implementations: in-memory (deterministic, scripted partitions), TCP+mutual TLS,
  QUIC (quinn, ALPN `idm/1`). Plaintext requires the `insecure-plaintext-tcp` feature and is
  recorded in the posture registry (ADR 0013).
- Handshake (`handshake.rs`, protocol v3): `Hello{version,node}` → `Challenge` →
  `ChallengeReply` → `Welcome`. **Authentication is an HMAC over the transcript keyed by a
  shared cluster cookie**, bound to the TLS channel. `NodeId = name + 128-bit time-ordered
  incarnation`.
- `BehaviorRegistry` (`registry.rs`): remote spawn by **behaviour name registered in the
  binary** ("FLAME model"; ADR 0009 principle 2: "Every node runs the same image").
- Semantics: at-most-once remote send by default; opt-in at-least-once with per-sender-incarnation
  dedup (`delivery.rs`, Amendment 1); monitors (exactly one `Down`), links, `noconnection`, AP
  groups (ORSWOT), CP singleton (PG lease), `DistributedSupervisor`, Fabric placement
  (`placement.rs`).
- **`id_effect_rpc` already has the typed-contract layer**: `contract.rs`
  (`id-effect.rpc.contract/1`, services × versions × procedures with kinds and JSON schemas,
  golden snapshots, `id-effect rpc check`), and `transport/mesh.rs`, which serves an
  `RpcGroup` as a mesh process under a global name, stamps the verified calling node as principal
  (`MeshPeer`, `RpcPrincipal("mesh:<node>")`, `MeshPeerGuard`), with per-peer call limits,
  deadlines, credits and heartbeats.

### 4.2 What breaks under "each compartment is a different binary"

| ADR 0009 assumption | Why it fails | Replacement |
|---|---|---|
| Shared cookie authenticates membership | any one compromised compartment holds the secret that admits *any* identity; no per-peer authz | per-compartment attested identity cert (§3); handshake proves the key and presents evidence |
| Remote spawn = registered behaviour in the same binary | the peer does not contain your behaviours | "spawn" = **ask the compartment manager to boot an image** by derivation/measurement; in-compartment processes are not remotely spawnable by default |
| Pid is location-transparent; any node can send to any pid | ambient authority: knowing a pid = being able to message it | messages only flow on **granted channels**; a pid is reachable only via a capability that names it |
| Membership is SWIM gossip among equals | a leaf compartment should not learn the topology | **hub-and-spoke per host**: compartments talk to their host's router/manager (or directly to wired peers); gossip only among host managers |
| Same protocol major cluster-wide | a fleet of independently-built images will skew | per-channel **contract version negotiation**; protocol major per link, not per cluster |
| Byzantine faults are a non-goal | VPS compartments and compromised leaves *are* Byzantine | every input is schema-decoded (already true), authz is per channel, and resource limits are per peer (partly true in rpc mesh) |

### 4.3 Wiring model: static roots, attenuated capability passing

Options:

- **Static wiring** (Microkit system file, Spectrum/Ghaf VM configs). Every channel is declared
  in the system description, measured, and checked at build time. Easy to audit, and every
  channel is in the measurement. But it cannot express "the file-picker hands the editor one
  file".
- **Capability passing** (Cap'n Proto level 1+: object references + promise pipelining; OCapN:
  CapTP + **signed three-party handoffs** that only the intended recipient can redeem).
  <https://capnproto.org/rpc.html>, <https://github.com/ocapn/ocapn>,
  <https://www.spritely.institute/news/introducing-ocapn-interoperable-capabilities-over-the-network.html>.
  Expressive, POLA-native, but harder to audit statically, and three-party handoff across
  machines is where implementations are immature (Cap'n Proto C++ still lacks it).

**Recommendation: hybrid.**
1. The **system description** (Voltaic, #417) declares each compartment's *bootstrap
   capabilities*: typed channel endpoints `(contract digest, peer measurement-or-role, rights)`.
   These are in the manifest, so they are in the measurement. The builder checks
   `provider.contract ⊇ consumer.required` with the existing `id-effect rpc check` and **fails
   the build** on a mismatch or an unwired requirement.
2. At runtime a compartment may **pass** a capability it holds, attenuated: fewer procedures,
   shorter TTL, caveats in the style of macaroons/biscuit. It may also pass **object
   capabilities it mints itself** (e.g. a handle to one open file). Passing to a third compartment
   uses an OCapN-style **handoff certificate**, signed by the granter, naming the recipient's
   identity key, and redeemable only on a mutually-authenticated channel by that key.
3. **No ambient pids.** A `Pid` received over the wire is inert unless it comes with a capability.

### 4.4 Contract identity and versioning

- `ContractId = (service name, major) + digest = SHA-256(canonical contract JSON)`. The canonical
  form already exists: sorted, stable JSON (`contract.rs`).
- Compatibility = the existing `rpc check` rules (added optional fields, new procedures OK;
  removals and type narrowing break). The **digest pins the exact contract**; the
  `(name, major)` pair says what is substitutable.
- Handshake per channel: each side sends `{contract name, major, digest, minor-features}`. The
  link opens on the highest common minor and is refused across majors. The digests go into the
  mesh cert, so an attested peer cannot claim a contract it was not built with.
- Wire stays postcard (already the mesh RPC codec). JSON schema stays for docs and checks.

### 4.5 Transports

- **vsock transport** (`id_effect_node::transport::vsock`, feature `vsock`): `AF_VSOCK` in the
  guest (`vsock://<cid>:<port>`), and on the host either `AF_VSOCK` (vhost-vsock) or
  cloud-hypervisor/Firecracker **hybrid vsock**: a host UNIX socket, `CONNECT <port>\n` for
  host→guest, and `<socket>_<port>` listeners for guest→host. Cloud-hypervisor supports stream
  sockets only. <https://git.phyllo.me/External/cloud-hypervisor/src/tag/v43.0/docs/vsock.md>,
  <https://www.man7.org/linux/man-pages/man7/vsock.7.html>. vsock has **no crypto and no peer
  identity beyond CID**. For local non-CVM guests the hypervisor is trusted, so a CID is a weak
  identity hint. For **CVM guests vsock traverses the untrusted host**. So, always:
- **Encrypted, attested session layer over every transport.** Run TLS 1.3 (the existing rustls
  path; the TLS-over-a-byte-stream code in `tls_tcp.rs` generalises) or Noise XX (smaller) over
  the vsock byte stream. Certificates come from §3, and `channel_binding()` keeps working, so the
  handshake binds to it as today. Recommendation: reuse rustls so there is one crypto stack. A
  Noise transport is an optional later TCB cut.
- **Cross-host:** QUIC as today, with mesh certs from the fleet CA (or DICE chains) replacing
  cookie+static certs. Tailscale stays as the underlay, not the trust anchor.
- **seL4 later:** a Microkit channel + shared-memory-region transport implementing the same
  `Connection` trait (notify + ring buffer).

### 4.6 Semantics, supervision, placement, migration

**Delivery semantics.** Keep ADR 0009's normative table unchanged. Compartment restart = new
incarnation, so pending reliable sends fail with `PeerRestarted`, which is correct. Mutations
carry `Idempotency-Key`, which already exists in `id_effect_rpc::idempotency`. Exactly-once
stays in `id_effect_jobs`/outbox. Add one row: **"Channel revoked"**. When a capability is
revoked or its cert expires, in-flight calls fail with a typed `Revoked`, and monitors get
`Down{reason: revoked}`.

**Supervising VMs as processes.** A `CompartmentSupervisor` is an `id_effect_process`
supervision-tree node whose children are `ChildSpec { start: boot_vm(image, manifest),
restart: Permanent|Transient|Temporary, shutdown: Timeout(d), kind: Worker }`.
- `start` calls a `Hypervisor` capability: a Layer with impls for cloud-hypervisor's REST API,
  crosvm, QEMU (CVM), Firecracker, and an in-process fake for tests.
- Liveness has three sources: VMM process exit (pidfd), vsock heartbeat on the system port, and
  the guest init reporting the program's `ExitReason` (mapped to `Cause`) over the system
  channel. The VM is "up" only after init reports `Ready` *and* (when required) attestation
  succeeds.
- Shutdown protocol: system-channel `Stop` → wait `shutdown` on `Clock` → ACPI power-off →
  kill VMM. This mirrors ADR 0009's cancel → timeout → interrupt.
- Restart intensity on the injected `Clock` gives deterministic tests with `TestClock` + fake
  hypervisor + in-memory transport, which is the ADR 0009 acceptance bar.
- Strategies make sense at VM granularity: `RestForOne` for "vault must be up before
  consumers", `OneForAll` for a tightly-coupled group.
- Host-level: the compartment manager is itself a systemd unit (the host's only long-lived
  service besides the VMMs). It is the root supervisor and exposes `DrainRequest`/`ClusterStatus`
  via the existing `control.rs` types.

**Placement.** Extend `placement.rs` (`PlacementScorer`, `ClusterResourcePolicy`) with *hard
constraints* before scoring:
- `trust_tier ∈ {local-hw-attested, cvm-own-firmware, cvm-provider-firmware, untrusted}` per
  host/VPS, and a minimum tier per compartment (from the manifest);
- `data_labels` (e.g. `personal`, `trading`, `secret-material`), allowed tiers per label;
- hardware features (`kvm`, `gpu`, `snp`, `tdx`), and `pinned` (never move: mimir trading);
- cost/latency as soft scores; VPS capacity as an elastic pool. ScaleOut creates a VPS (a
  provider API capability), waits for attestation, then admits it.

**Live migration.** Recommendation: **no live migration in v1; crash-only restart-elsewhere
plus state hand-off by contract.** Reasons: CVMs cannot migrate (IONOS FAQ above); virtio-fs
blocks migration; cloud-hypervisor migration runs over UNIX sockets unencrypted, so it would
need our own encrypted tunnel (<https://listman.redhat.com/archives/libvir-list/2022-August/233362.html>);
and a migrated VM keeps its identity keys in RAM, which complicates revocation. For local
non-CVM compartments with large warm state, offer cloud-hypervisor **snapshot/restore over an
attested mesh channel** later, as a `Migrate` placement action that re-attests on the target.
For most programs: drain → the old instance hands state over a `Handoff` contract or flushes to
its volume → boot on the target → re-attest → re-wire.

---

## 5. Secrets and storage

### 5.1 Secrets: never in the store, released to attested identities

Options:

| Option | Fit |
|---|---|
| systemd credentials via SMBIOS OEM strings / fw_cfg (`microvm.credentialFiles`, `platformOEMStrings`) | Fine for the bootstrap and agent tier. Visible to the host and VMM, so useless for CVMs. |
| sops-nix inside each guest | Puts the age key in the guest image or its credentials. Every compartment holding a decryption key for a shared file breaks POLA. |
| **Vault compartment over the mesh (recommended)** | One small id_effect service holds the sops/age master (now) or a TPM-sealed master (later). It releases secret `S` only to a peer whose cert says `contract ∈ allowed(S) ∧ measurement ∈ allowed(S) ∧ tier ≥ min(S)`. Deny by default; log every release. |

Vault design:
- It runs on mimir (always on) with a standby on drakkar, as a `ClusterSingleton` for writes,
  readable from both.
- Secrets are typed per contract (`VaultSecrets` contract: `get(name) -> Sealed<Bytes>`,
  `lease(name, ttl)`, `rotate`). Short-lived derived tokens (GitHub App installation tokens,
  1 h, per the 2026-11-26 decision) are minted by the vault rather than stored.
- Delivery happens in `compartment-init` before the program runs. The secret lands in memory or
  in a tmpfs inside the guest, never on a host-visible disk.
- Bootstrap circularity: the vault itself gets its master key from the host TPM (local), so the
  vault is `local-hw-attested` only and never placed on VPS.
- The current sops-nix setup stays as the *storage format* of the vault's backing file during
  migration, so the change from "sops on hosts" to "sops in the vault" is mechanical.

### 5.2 Per-compartment persistent state

- One **virtio-blk volume per (compartment role, instance)** as an LV or raw file on the host,
  declared in the manifest (`volumes: [{name, size, sealing: role|instance}]`).
- **Encrypted and integrity-protected in the guest**: dm-crypt + dm-integrity (AEAD), or
  `dm-crypt` with `aes-gcm-random`, so the host (or VPS provider) can neither read nor silently
  modify data. Plain dm-crypt XTS gives confidentiality without tamper detection, which is not
  enough against an untrusted host.
- **Volume key:**
  - local: `KDF(CDI_seal(c), volume name)`. The sealing CDI excludes the code hash (it uses
    contract identity + signer), so **an upgraded image keeps its data**, while a different
    compartment, or the same code on another host, cannot derive it. This is exactly Open DICE's
    sealing-CDI rationale.
  - VPS: random key wrapped by the vault and released after attestation (§3.4), as Trustee/KBS
    does for encrypted rootfs.
- **Rollback protection:** a monotonic per-volume generation counter held by the vault. The
  guest refuses a volume whose header generation is older than the vault's record. dm-integrity
  alone does not stop whole-volume replay.
- **Backups:** ciphertext only, shipped to mimir's storage. Restore needs the vault, which is
  intended.
- Shared data (e.g. mimir's `/data`) is **not** mounted into compartments. It is served by a
  storage compartment over a `Files` contract with per-capability path scoping. This is
  Ghaf's storage-VM idea, typed.

---

## 6. id_effect changes (candidate ADRs / release items)

Each item gives 2-4 lines of scope. Proposed numbering continues after ADR 0017.

1. **ADR 0018: Heterogeneous mesh (amends ADR 0009, retires the FLAME assumption as a
   requirement).** Nodes may run different binaries. Remote spawn becomes optional, per-node.
   Reachability is by capability, not by pid. Cluster-wide protocol major becomes per-link
   negotiation. Defines trust tiers and the Byzantine-leaf threat model.
2. **Attested identity handshake (`id_effect_node::handshake` v4).** Replace the shared-cookie
   HMAC with a signature over the transcript by a per-node key whose certificate (X.509 or CBOR,
   DICE chain or fleet-CA) carries measurement, manifest and contract digests. Keep the cookie
   as a dev-only posture opt-out (ADR 0013 R10 registry). Channel binding is unchanged.
3. **`Identity` / `Attester` / `Verifier` capabilities (new crate `id_effect_attest`).**
   Evidence types for SEV-SNP reports, TDX quotes, CCA tokens and DICE chains. A verifier Layer
   with policy (TCB floor, reference measurements, k-of-n reproducibility). A fake attester for
   deterministic tests. Wraps vendor crates; ships no crypto of its own.
4. **vsock transport (`transport::vsock`, feature `vsock`).** `AF_VSOCK` client/listener plus
   the cloud-hypervisor/Firecracker hybrid-vsock UNIX `CONNECT` protocol. Mandatory TLS (rustls
   over the stream) with `channel_binding`. Conformance tests shared with TCP/QUIC/in-memory.
5. **Channel capabilities and handoff (`id_effect_node::cap`, ADR 0019).** Typed channel
   capabilities `(contract digest, target, rights, caveats, expiry)`, attenuation, revocation
   (`Down{revoked}`), and OCapN-style signed three-party handoff certificates bound to the
   recipient's key. No ambient pid reachability when the feature is on.
6. **Contract identity and per-channel negotiation (`id_effect_rpc::contract`).** A
   `ContractId` digest over the canonical contract JSON. A per-channel `{name, major, digest,
   minor}` exchange. `rpc check` exposed as a library call so the Voltaic system builder can
   fail builds on unwired or incompatible channels.
7. **`CompartmentSupervisor` + `Hypervisor` capability (`id_effect_process` or new
   `id_effect_vm`).** A `ChildSpec` whose start boots a VM. Liveness from pidfd + vsock
   heartbeat + guest exit report mapped to `Cause`. Shutdown protocol Stop → timeout → ACPI →
   kill. Hypervisor impls: cloud-hypervisor API, crosvm, QEMU (CVM), Firecracker, fake.
8. **Placement constraints (`placement.rs`, Fabric).** Hard constraints before scoring: trust
   tier, data labels, hardware features, pinning. VPS elastic pool with a provider capability.
   ScaleOut waits for attestation before admitting a node.
9. **`compartment-init` reference runtime (example + small crate).** PID 1 for guests: verity
   mount, manifest parse, identity bootstrap (DICE local / SNP/TDX remote), secret fetch, volume
   unlock, program supervision, exit reporting. Must build without tokio's full feature set and
   stay small.
10. **Vault building blocks (`id_effect_auth`/`id_effect_storage`).** A `VaultSecrets` contract,
    policy evaluation over attested principals, lease/rotate, and monotonic volume-generation
    records. Exposed as library pieces so the vault compartment is a thin binary.
11. **Revocation and cert lifetime semantics in delivery tables (ADR 0009 Amendment 2).** A
    `Revoked` failure, re-attestation renewal, and behaviour of reliable sends and monitors
    across identity rotation.
12. **`no_std + alloc` core for seL4 Microkit PDs (extends ADR 0017).** After the wasm32 split,
    add an `aarch64/x86_64-sel4` target class, a runtime on Microkit notifications, and a
    shared-memory `Connection` transport. Horizon item: document the boundary now, ship later.

---

## 7. dotfiles changes

Ordered by dependency. Each is a feature path under `features/catalog.nix`, enabled by option,
with host facts in `common/fleet.nix` per AGENTS.md.

1. **`common/fleet.nix`: per-host compartment facts.** Add `trustTier`, `cpu.{vendor,sev-snp,tdx}`
   and `tpm2` per host, plus a `vps` section for rented nodes (provider, tier, ephemeral = true).
   Check whether drakkar/mimir's AMD CPUs are EPYC: consumer Ryzen has no SEV-SNP, so local hosts
   are expected to be `local-hw-attested` via TPM, not CVM hosts **[verify]**. huginn and muninn
   are Intel N200-class laptops/tablets, so there is no TDX there.
2. **`features/virtualisation/microvm-host` (bootstrap, now).** microvm.nix host with
   cloud-hypervisor, a per-VM uid, systemd sandboxing of VMMs, read-only **closure-scoped**
   virtio-fs for agent VMs (per the 2026-11-26 decision), and vsock enabled. This is the tier
   where shared-store virtio-fs is acceptable.
3. **`features/compartments/image` (Voltaic generator, after #417).** A Voltaic function
   `compartment { entry, contracts, channels, volumes, tier }` → `.drv` producing `root.erofs`,
   verity, `uki.efi`, `manifest.json`, `measurement.json` and `provenance.json`. Realised by
   `vbuild`, cached by `vcache`, signed (store signing on, per #116 leftovers). Initial
   implementation can lean on nixpkgs `image.repart.verityStore` and the `nix-store-veritysetup`
   generator for reference.
4. **`features/compartments/manager` (host service).** The id_effect compartment manager:
   root `CompartmentSupervisor`, DICE derivation from a TPM-sealed host UDS, vsock router,
   `ClusterStatus`/`Drain` control plane. It replaces per-VM systemd units from microvm.nix in
   production. Depends on Secure Boot + TPM2 rollout (#292).
5. **`features/compartments/guest-kernel`.** One minimal, module-less, lockdown guest kernel
   config per arch, shared by all compartments (one measurement input to keep stable).
6. **`features/compartments/vault`.** The vault compartment on mimir (standby on drakkar),
   importing the existing sops files as backing store, minting GitHub App tokens. Tier
   `local-hw-attested` only.
7. **`features/compartments/attestation`.** The verifier compartment: reference values from
   `measurement.json` of reproducibly built derivations, AMD/Intel collateral caching, mesh CA
   issuing short-lived certs.
8. **`features/compartments/vps`.** Provisioning for rented nodes (OVH bare metal with SNP
   preferred; Azure/GCP CVMs as the "provider-firmware" tier), a minimal host image for
   bare-metal VPS, and an ingest gate in `vbuild`/`vpush` that accepts VPS-built outputs only on
   k-of-n NAR-hash agreement.
9. **Migration of existing services into compartments**, one at a time, per "replace means
   take-over" (each with a live-switch test, never on mimir's trading services without explicit
   approval). Order: stateless leaf tools (vexporter, vhealth) → network-facing (vcache) →
   stateful (monitoring) → trading last.
10. **Assay suites** for each feature (`*.assay.nix`): image contains exactly the closure (no
    extra store paths), measurement file matches the UKI, channels in manifest ⊆ contracts
    checked, no virtio-fs in production tier, and no secrets in any image (scan).

---

## 8. Phasing

| Phase | Deliverable | Depends on |
|---|---|---|
| P0 | microvm.nix agent VMs (closure-scoped RO store, vsock), id_effect vsock transport | — |
| P1 | ADR 0018/0019 accepted; attested handshake v4 with fleet-CA certs; contract digests | P0 |
| P2 | Voltaic compartment image generator (erofs+verity+UKI+measurement) | #417 |
| P3 | compartment manager + DICE + CompartmentSupervisor; first leaf services migrated | P1, P2, #292 |
| P4 | vault + per-compartment encrypted volumes; sops moves behind the vault | P3 |
| P5 | VPS tier: SNP bare metal, verifier, k-of-n ingest, placement constraints | P3, P4 |
| P6 | seL4/Microkit target for pure-Rust compartments | ADR 0017 split, P2 |

## 9. Open questions for the owner

1. Is a **fleet CA** (in the attestation compartment) acceptable, or should identity be **pure
   DICE chains** to the TPM/vendor roots with no CA? (A CA makes revocation and VPS admission
   simpler.)
2. Which VPS shape first: **OVH bare metal + own hypervisor** (full measurement control, more
   ops) or **Azure/GCP CVM** (provider firmware in the measurement, less ops)?
3. Do any VPS workloads need secrets at all, or can VPS be restricted to "pure build/compute
   with verifiable outputs"? The answer decides whether VPS ever talks to the vault.
4. Is live migration a hard requirement for any service, or is crash-only + state hand-off
   acceptable fleet-wide?
5. Agent VMs: do they move to the production image format later, or stay on the shared-store
   dev tier permanently?

## Sources (consolidated)

- microvm.nix options: <https://microvm-nix.github.io/microvm.nix/microvm-options.html>
- Ghaf: <https://ghaf.tii.ae/ghaf/overview/arch/system-architecture/>, <https://ghaf.tii.ae/ghaf/dev/architecture/vm-composition/>, <https://ghaf.tii.ae/ghaf/dev/technologies/hypervisor_options/>, <https://ghaf.tii.ae/givc/overview/arch/>, <https://ghaf.tii.ae/ghaf/overview/arch/variants/>
- Spectrum: <https://www.spectrum-os.org/design.html>, <https://spectrum-os.org/git/spectrum/tree/Documentation/decisions/005-virtual-machine-monitor.adoc>, <https://spectrum-os.org/git/spectrum/tree/Documentation/about/architecture.adoc>, <https://lists.spectrum-os.org/archives/list/devel@spectrum-os.org/thread/5PF72BVCRTLRQUVFAMKVWRCTKPE7YIMI/>, <https://logs.spectrum-os.org/spectrum/2020-08-28>
- seL4: <https://github.com/sel4/rust-sel4>, <https://docs.sel4.systems/projects/rust/how-to-use.html>, <https://github.com/sel4/microkit>, <https://github.com/au-ts/sddf>, <https://trustworthy.systems/projects/LionsOS/>, <https://trustworthy.systems/projects/drivers/devvirt>, <https://github.com/DLR-FT/seL4-nix-utils>
- Images: <https://erofs.docs.kernel.org/en/latest/imagefs.html>, <https://github.com/containers/composefs/blob/main/README.md>, <https://lwn.net/Articles/933616/>, <https://code.fizz.buzz/talexander/nixpkgs/commit/942588c6866d55a252bdb3a7a0d4eef84162e987>, <https://github.com/nikstur/nix-store-veritysetup-generator>, <https://discourse.nixos.org/t/boot-time-integrity-checks-for-the-nix-store/36793>
- virtio-fs risks: <https://arxiv.org/pdf/2607.17518>, <https://modal.com/blog/vm-sandbox-filesystem>, <https://virtio-fs.gitlab.io/design.html>, <https://listman.redhat.com/archives/virtio-fs/2021-March/002933.html>, <https://issues.redhat.com/browse/RHEL-40135>
- DICE / AVF: <https://pigweed.googlesource.com/open-dice/+/refs/heads/main/docs/specification.md>, <https://source.android.com/docs/core/virtualization>, <https://source.android.com/docs/core/virtualization/security>
- SEV-SNP: <https://qemu.googlesource.com/qemu/+/c1996992cc882b00139f78067d6a64e2ec9cb0d8>, <https://github.com/AMDESE/AMDSEV/issues/93>, <https://documentation.ubuntu.com/server/how-to/virtualisation/sev-snp>, <https://www.amd.com/content/dam/amd/en/documents/epyc-technical-docs/tuning-guides/58207-using-sev-with-amd-epyc-processors.pdf>
- TDX: <https://docs.kernel.org/6.6/arch/x86/tdx.html>
- CCA: <https://datatracker.ietf.org/doc/draft-ffm-rats-cca-token/>, <https://github.com/veraison/rust-ccatoken>, <https://learn.arm.com/learning-paths/servers-and-cloud-computing/cca-veraison/>
- SVSM: <https://fosdem.org/2025/events/attachments/fosdem-2025-5412-updates-on-coconut-svsm-secure-services-and-stateful-devices-for-confidential-virtual-machines/slides/236799/FOSDEM_20_X5nuOWj.pdf>, <https://kvm-forum.qemu.org/2024/KVMForum_2024_SVSM_attestation.v2_N45MQqI.pdf>, <https://arxiv.org/pdf/2303.16463.pdf>
- Cloud CVMs: <https://techcommunity.microsoft.com/t5/azure-confidential-computing/azure-confidential-vms-dcasv5-ecasv5-using-amd-sev-snp/ba-p/2993530>, <https://docs.cloud.google.com/confidential-computing/confidential-vm/docs/supported-configurations>, <https://docs.ionos.com/cloud/home/compute-services/confidential-computing-vm>, <https://docs.ionos.com/cloud/home/compute-services/confidential-computing-vm/confidential-vm-faq>, <https://www.ovhcloud.com/en/bare-metal/uc-confidential-computing/>
- Physical attacks: <https://thehackernews.com/2025/10/new-teefail-side-channel-attack.html>, <https://www.ieee-security.org/TC/SP2026/downloads/posters/sp2026posters-final75.pdf>, <https://schneier.com/blog/archives/2025/11/new-attacks-against-secure-enclaves.html>
- RATS / KBS: <https://www.rfc-editor.org/rfc/rfc9334>, <https://docs.nvidia.com/datacenter/cloud-native/confidential-containers/latest/attestation.html>
- Capabilities: <https://capnproto.org/rpc.html>, <https://github.com/ocapn/ocapn>, <https://www.spritely.institute/news/introducing-ocapn-interoperable-capabilities-over-the-network.html>, <https://www.capnproto.org/news/2020-04-23-capnproto-0.8.html>
- vsock: <https://git.phyllo.me/External/cloud-hypervisor/src/tag/v43.0/docs/vsock.md>, <https://www.man7.org/linux/man-pages/man7/vsock.7.html>
- Migration: <https://listman.redhat.com/archives/libvir-list/2022-August/233362.html>
- id_effect (local): `/data/Code/rust/id_effect/docs/adrs/0009-process-mesh.md`, `crates/id_effect_node/src/{transport/mod.rs,handshake.rs,registry.rs,id.rs,delivery.rs,placement.rs}`, `crates/id_effect_rpc/src/{contract.rs,transport/mesh.rs}`
