# 03 — Prior art: compartment architectures, policy from types, inter-compartment channels

Research date: 2026-11-27. Read-only research. Sources are primary where possible; where a claim
comes from memory of a paper rather than a fetched page it is marked *(recalled)*, so check it
before relying on it.

Question: what does prior art teach about (1) whole-system compartmentalisation, (2) deriving or
checking least-privilege policy from types or manifests, and (3) inter-compartment channels, for
a fleet where every program runs in its own hardware-isolated compartment, programs are
id_effect `Effect<A, E, R>`, and policy comes from `R`?

---

## 0. What `R` actually is (id_effect ADRs 0002–0005, 0011)

Read from `/data/Code/rust/id_effect/docs/adrs/`:

- Since 0.7 (ADR 0003 Amendment 1, ADR 0011), `R` is a **typed HList** `HCons<A, HCons<B, …HNil>>`.
  Membership is checked at compile time (`R: Selector<T, I>`). Only `Effect<_, _, HNil>` is
  runnable, so a program's *residual* `R` (what is left after all `provide`s) is a compile-time
  fact.
- Providers are `Layer<Out, E, In>` values (`merge`, `provide_to`, `fresh`, `scoped`). A Layer's
  `In` is the capabilities it needs to build `Out`.
- A capability is **identified by its Rust type**. Two instances of one service need two newtypes
  (named variants were dropped from typed `R`).
- `Embed<Sub, Is>` projects any subset in any order; `narrow::<Wide,_>()` is compile-checked.
- `DynEnv` survives as an explicit, fallible escape hatch for plugin wiring whose keys are not
  known at compile time.

Consequences that shape everything below:

1. `R` names **what kind** of authority (a service trait), not **which instance** or **how much**
   (`HttpClient`, not "HTTPS to api.example.com, GET only"). Every surveyed system that got
   least privilege right separates the *shape* of a capability from the *instance routed to it*.
2. `R` is the authority a program needs **from outside its Layer graph**. Authority captured
   inside a Layer (service `Signer` built from `In = caps!(Keystore, Http)`) disappears from the
   `R` of its consumers. That is exactly right for the compartment boundary, and exactly wrong
   for information-flow reasoning (§5): you need the Layer graph, not just the root `R`.
3. Rust is not an object-capability language. `std::fs`, `std::net`, `std::process`, `unsafe`,
   FFI and `DynEnv` are ambient authority that `R` does not see. So `R` can *propose* a policy
   but cannot *enforce* one; the compartment boundary has to enforce it ("types propose, the
   hypervisor disposes").

---

## 1. Whole-system compartmentalisation — per-system lessons

### 1.1 Lessons table

| System | Got right | Got wrong / limits | Steal |
|---|---|---|---|
| **QubesOS** (Xen, dom0, qrexec) | Security by compartmentalisation as a product, not a research demo. dom0 has **no network**; net, USB and GUI pushed into service qubes (sys-net, sys-usb, sys-gui). qrexec: every inter-VM call is a named service + argument, decided by a central policy in dom0 (`service +arg source target allow/deny/ask`, tokens `@anyvm`, `@dispvm`, `@tag:…`, `@default`; files in `/etc/qubes/policy.d/`, new format since 4.1). `ask` makes the human an explicit policy decision point. Disposables. Split-GPG/split-SSH: secret holder offers an operation, never the key. Inter-VM bytes go over vchan, not a network. | Policy is **stringly-typed and global**: service names and arguments are strings, the payload is an untyped byte stream each service re-parses. Policy is hand-written, separate from the program, so it drifts. Granularity is the *VM*, which holds many apps (template-based AppVMs), so least privilege is per-trust-domain, not per-program. dom0 is big (Fedora + Xen toolstack + GUI in 4.x unless sys-gui), and Xen itself is a large TCB with a long XSA history (https://www.qubes-os.org/security/xsa/). X11 GUI protocol, clipboard and file copy are user-mediated but *data-unaware*: Qubes documents that it does not stop you leaking data you copy (https://doc.qubes-os.org/en/r4.3/user/security-in-qubes/data-leaks.html). Heavy on RAM, no hardware breadth. | The **policy decision point outside every compartment**, default deny, `ask` as a typed "human declassifier". Service = (name, argument) pairs → we get the typed version for free. dom0-without-network as an invariant. Disposables per *taint*, not per app. Split-X pattern ("offer the operation, never the secret") as the default shape for every secret. |
| **Spectrum OS** (Alyssa Ross; KVM + Cloud Hypervisor, Nixpkgs but *not* NixOS) | **VM per application**, not per trust domain (https://spectrum-os.org/design.html). Wayland forwarded via virtio-gpu cross-domain (no X11). Rust VMM. Single global user filesystem with VMs granted *subsets*, and dynamic grants via the XDG File Chooser portal (a powerbox). Reproducibility treated as a security property. | Still pre-1.0 research system; small team. Deliberately not NixOS, which the design page attributes to wanting a different base; it gives up the NixOS module ecosystem. Static configuration is acknowledged as needed but not the focus; no typed policy language. | VM-per-app is feasible with Cloud Hypervisor + shared read-only store (DAX/virtiofs) — exactly the Nix store shape. **Powerbox** (portal) for files: authority granted by user designation at runtime, not by manifest. |
| **Ghaf** (TII; NixOS + microvm.nix) | Closest to our stack: NixOS host, microVMs (net-vm, gui-vm, admin-vm, audio-vm, app VMs), Rust VMMs, minimal host. GIVC: a gRPC control channel with TLS and identity-bound peers, and *documented* rationale that inter-VM links must be explicit, minimal and auditable (https://ghaf.tii.ae/ghaf/overview/arch/inter-vm-communication-control/). Default-deny networking per interface. | Policy is NixOS options + firewall rules + gRPC service config — three places, none derived from the programs. Policy management fetches policy files from **remote URLs at runtime** and applies them to running VMs (https://ghaf.tii.ae/ghaf/overview/arch/policy/), which detaches running policy from the reproducible build. Communication is largely IP networking between VMs, so the "channel" is a network, and per-channel typing is gRPC-level only. Granularity is still a VM per role, several apps per VM. | microvm.nix patterns, net-vm/gui-vm split, Nix store sharing into guests. Do **not** steal runtime policy fetch: policy must be a build output with the same provenance as the system. |
| **ChromeOS crosvm / Crostini / sommelier** | crosvm: **process per virtual device**, each in a minijail (namespaces, seccomp) (https://crosvm.dev/book/architecture/overview.html); the VMM is not one big trusted blob. Rust. Termina VM + LXD containers. sommelier: a Wayland compositor proxy per guest over virtio-wl/cross-domain, so the host compositor sees a filtered protocol. Chrome's Mojo: typed IPC with explicit guidance that the less-privileged side is always untrusted (https://chromium.googlesource.com/chromium/src/+/main/docs/security/mojo.md). | Crostini is one VM with many containers inside: the hard boundary is coarse. sommelier is a large protocol proxy on the trusted side (a parsing surface). | **Disaggregate the VMM**: every device backend is its own sandboxed process — and the next step, its own VM (virtio-vhost-user, §3). Mojo's rules for typed IPC review ("validate in the privileged process; never trust an ID from the less privileged side"). |
| **Android AVF / Microdroid** (pKVM) | Protected VMs whose memory **the host cannot read** (pKVM at EL2) (https://source.android.com/docs/core/virtualization). Minimal Microdroid guest, payload from a signed APK, DICE-based identity chain and sealing secrets bound to the measured payload. Binder RPC over vsock reuses Android's typed IDL (AIDL). | Narrow use cases (isolated compute, keystore-like); not a general desktop. The *permission manifest* side of Android is the cautionary tale: hand-written `uses-permission` lists bloat — Felt et al. found about a third of apps over-privileged *(recalled; "Android Permissions Demystified", CCS 2011, https://dl.acm.org/doi/10.1145/2046707.2046779)*. | Treat the **host as untrusted by the compartment** where hardware allows (pKVM/SEV/TDX), measured identity per compartment, secrets sealed to measured payload. And: *derive* manifests, do not hand-write them for our own code. |
| **Fuchsia Component Framework** | The best production model of capability routing. Every capability is explicitly declared: a child `use`s, a parent `offer`s to children, a child `expose`s to its parent; component_manager resolves routes only within a realm; no ambient authority, no global namespace (https://fuchsia.dev/fuchsia-src/concepts/components/v2/capabilities, CML reference https://fuchsia.dev/reference/cml). Capabilities are typed by FIDL protocol name. `availability: optional/required`, dictionaries for bundles. **Static route verification at build time** (`ffx scrutiny verify routes`, https://fuchsia.dev/reference/tools/sdk/ffx) plus security-policy allowlists for sensitive capabilities. | Manifests are hand-written JSON5 *beside* the code; they drift and are verbose (hence `include` shards). Isolation is process-level on Zircon, not hardware. Routing is hierarchical (parent must offer), which makes cross-tree wiring verbose. | **use/offer/expose** as the policy algebra. Build-time "every use is satisfied, every offer is used" check. Allowlist of who may receive dangerous capabilities, separate from routing. Capability *name* = protocol identity; *route* = instance choice. |
| **Genode** (session routing, recursive structure) | Recursive parent/child: every service request (session) is routed by the parent's `<route>` policy (`<service name="…"><child name="…"/></service>`, `<parent/>`, `<any-service>`) (https://genode.org/documentation/genode-foundations/). **Resource quota donation**: the client pays the RAM/caps for the server's session state, so a client cannot exhaust a server. Session labels are prepended by every parent on the path and cannot be forged by the child, so servers apply per-label policy. Sculpt OS shows it is usable. Runs on seL4, NOVA, its own kernel. | C++, niche, small ecosystem; configuration is XML with string labels; policy correctness relies on authors. | **Quota donation** is the best answer anyone has to inter-compartment DoS. **Unforgeable path labels** (the server learns *who* asked from the routing structure, not from the client's claim). Recursive realms: a compartment may host sub-compartments under a policy it controls but cannot exceed. |
| **OpenXT** (Xen, measured launch, stub domains) | Hardened Xen client for government use; measured launch (TXT), device-model stub domains, **Argo/V4V**: hypervisor-mediated, *copying* inter-VM messaging with a hypervisor-enforced firewall, no shared memory between untrusted peers (https://xenbits.xen.org/docs/unstable/designs/argo.html, https://openxt.org/). | Small community, slow; Xen client is a hard sell. | Hypervisor-mediated *copy* channels (Argo) as the high-assurance channel class: no TOCTOU, policy enforced by the lowest layer. |
| **MILS / separation kernels** (Rushby 1981; Alves-Foss et al. 2006) | The original idea: a **separation kernel** whose only job is spatial/temporal partitioning and controlled channels, with security functions in small trusted partitions above it. NEAT: Non-bypassable, Evaluatable, Always invoked, Tamper-proof *(recalled; https://www.csl.sri.com/papers/sosp81/)*. Policy is a static channel matrix verified once. Temporal partitioning addresses timing covert channels. | Static, embedded-scale; hostile to general software; certification-driven. | The channel matrix as a *static, checkable artefact*. Small trusted "guards" (cross-domain solutions) as the only place information moves down a lattice. Temporal isolation for the few compartments where covert channels matter. |
| **seL4 CAmkES / capDL / Microkit** | Architecture described once (CAmkES ADL: components, interfaces, connections), compiled to **capDL** (exact distribution of every capability), and an initialiser that **provably** puts the system into the capDL state; with seL4's integrity/confidentiality proofs this gives properties of the *composed* system (HACMS, "Formally verified software in the real world", https://cacm.acm.org/research/formally-verified-software-in-the-real-world/; capDL https://docs.sel4.systems/projects/capdl/). Microkit: simpler "protection domains + channels + memory regions" with a verified-mapping effort (https://trustworthy.systems/projects/microkit/2212-1-capdl-map.pdf). | Static; driver and Linux-VM stories are heavy; the proofs cover the kernel and the initialiser, not the components. | The pipeline **architecture description → flat capability distribution (capDL-like) → realiser**, with the middle artefact checkable. Translation validation per build instead of proving the generator. |
| **Kata Containers / Confidential Containers** | VM per pod with a container UX; CoCo adds TEEs. **genpolicy** auto-generates the kata-agent policy (Rego) *from the Kubernetes pod spec*, so the guest refuses host API calls the manifest did not imply (https://github.com/kata-containers/kata-containers/blob/main/src/tools/genpolicy/README.md). | The agent API between untrusted host and guest is wide; the policy has to enumerate it. Pod spec is a weak description of need. | **Generated policy from a manifest the workload already has** — exactly our plan with `R`. And: the guest must police the host's control API, not only the host policing the guest. |

### 1.2 Cross-cutting lessons

1. **Granularity drives everything.** Qubes and Ghaf isolate *trust domains*; Spectrum and Fuchsia
   isolate *programs*. Per-program isolation only scales if policy is derived, not written (Android
   permission bloat; Qubes policy drift).
2. **Separate the three questions**: *what shape* of authority (type/protocol), *which instance*
   (route), *how much* (attenuation/quota/allowlist). Fuchsia separates them; Qubes merges them
   into one string rule.
3. **The policy decision point lives outside every policed compartment, and is small.** Qubes dom0
   without network, Genode parent, Fuchsia component_manager, seL4 capDL initialiser.
4. **Static topology, dynamic leaves.** All mature systems wire roots statically, then let
   authority flow dynamically *only through already-granted channels* (Fuchsia handles in FIDL
   messages, Genode sessions, Spectrum portals, Cap'n Proto capabilities).
5. **Policy is a build artefact.** Ghaf's runtime-fetched policy and Qubes' hand-edited dom0 files
   are the anti-patterns; capDL and Fuchsia scrutiny are the patterns.
6. **The VMM is part of the TCB unless disaggregated.** crosvm process-per-device; pKVM makes the
   host untrusted.

---

## 2. Policy from types and manifests — prior art

| Line of work | What it is | Lesson for `R` |
|---|---|---|
| **E / object capabilities** (Miller, "Robust Composition", http://www.erights.org/talks/thesis/) | Authority only via references; no ambient authority; attenuation by wrapping; POLA by construction. CapTP: caps over the network with promise pipelining. | `R` is ocap-shaped (DI = authority by introduction). Missing pieces: no ambient authority (Rust has it), and attenuation (wrapping a cap to narrow it) as a first-class Layer pattern. |
| **Caja / Joe-E** (Mettler & Wagner, NDSS 2010 *(recalled)*) | Tame a mainstream language into an ocap subset by banning ambient APIs and mutable globals; verifier checks the subset. | The Rust equivalent: `#![forbid(unsafe_code)]`, clippy `disallowed_methods`/`disallowed_types` on `std::fs`/`std::net`/`std::process`/`std::env`, `cap-std` (https://github.com/bytecodealliance/cap-std) for capability-based fs/net handles. This turns `R` from "advisory" into "approximately sound" inside the compartment. |
| **Pony** reference capabilities & object capabilities (https://tutorial.ponylang.io/object-capabilities/) | `AmbientAuth` is a value passed to `Main`; everything else must be derived from it (e.g. `TCPConnectAuth(auth)`) — authority attenuates through typed tokens. | Model the root of authority as a *value* handed to the compartment's `main` by the realiser, and require authority-bearing Layers to be built from it. |
| **Austral** (https://austral-lang.org/spec/spec.html, "capability-based security" section) | Linear capability types; the root capability is given to the entry point; libraries cannot do I/O without being handed a capability, giving **supply-chain** protection. | Linearity is not needed for least privilege, but the *supply-chain* argument is the strongest argument for typed `R`: a dependency deep in the tree cannot reach the network without the type changing. |
| **Capsicum** (Watson et al., USENIX Sec 2010, https://www.usenix.org/legacy/event/sec10/tech/full_papers/Watson.pdf) / **CloudABI** (archived, https://github.com/NuxiNL/cloudabi) | Capability mode: after `cap_enter()` no global namespaces, only held descriptors with rights masks. CloudABI made this the *only* ABI; programs got their descriptors from a launcher config (YAML) — i.e. a manifest. | Per-compartment kernel enforcement of "no global namespace" is cheap defence in depth inside a VM guest (Landlock/seccomp on Linux). CloudABI died for ecosystem reasons, not technical ones: foreign software needs a compatibility path. |
| **WASI / Component Model, WIT worlds** (https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md) | A component's `world` declares typed `import`s and `export`s; the host or a composer (wac) links imports to exports; nothing is ambient; resources are unforgeable handles. | The closest existing thing to "derive the manifest from `R`": a WIT world is literally the residual imports. Steal: (a) typed interface packages with versioning, (b) *composition* as a separate step producing a closed world, (c) resources (handles) as capability values crossing boundaries. Also a possible *second, finer* compartment tier (Wasm in VM). |
| **Singularity** channel contracts (Fähndrich et al., EuroSys 2006, https://www.microsoft.com/en-us/research/publication/language-support-for-fast-and-reliable-message-based-communication-in-singularity-os/) | Processes are sealed; communicate only over typed channels whose contracts are **state machines** (session types); manifests describe a process's channels and the OS checks them at install time. | The nearest ancestor of the whole plan: manifests *generated from code*, checked by the system, channels typed by protocol state machines. |
| **Information-flow type systems**: Jif (DLM, https://www.cs.cornell.edu/jif/), FlowCaml, Paragon (Chalmers), LIO (Stefan et al., Haskell 2011) | Labels on data; type system or monadic runtime prevents high→low flows; explicit `declassify`/`endorse` with authority. LIO: a monad with a *current label* that floats up as you read; writes are checked against it — dynamic IFC as a library. | LIO is the right mental model for id_effect: an `Effect` that reads `Secret<L>` raises its label; a `Sink` capability may only be used below its clearance. Can be a *type-level* property of the HList (§5). Lesson from Jif: fine-grained static IFC is unergonomic and implicit flows are hard; apply IFC at the **compartment/channel granularity**, not per-variable. |
| **OS DIFC**: Asbestos, HiStar (OSDI 2006, https://www.usenix.org/legacy/event/osdi06/tech/full_papers/zeldovich/zeldovich.pdf), Flume (SOSP 2007, https://pdos.csail.mit.edu/papers/flume-sosp07.pdf), DStar (NSDI 2008) | Processes carry secrecy/integrity labels made of tags; `t+`/`t-` capabilities to add/remove a tag; the kernel (or a reference monitor) checks every message against labels; endpoints per process. DStar extends across machines. | The compartment-granularity IFC we want *already exists as a design*: label each compartment, check each channel. Flume's "endpoint" safety rule and its handling of shared deputies (spawn per-label instances) map directly onto VMs/disposables. |
| **Session types** (Honda; Rust: Ferrite https://arxiv.org/abs/2009.13619, Kokke's `sesh` https://arxiv.org/abs/1909.05970; multiparty: Rumpsteak) | The channel type is a protocol (send A, then receive B, then choose…); duality guarantees no protocol errors; multiparty types give deadlock freedom for choreographies. | Use **binary session types or simple request/response + streams** for channel types; full MPST is heavy. The useful payoff is *protocol state* checking at the boundary (e.g. "auth before read") and generated parsers. |
| **Effects as capabilities**: Koka (row-polymorphic effects, https://koka-lang.github.io/koka/doc/book.html), Effekt (Brachthäuser et al., OOPSLA 2020, "Effects as Capabilities", https://dl.acm.org/doi/10.1145/3428194), Scala 3 capture checking (https://docs.scala-lang.org/scala3/reference/experimental/cc.html, CC<:◻ https://arxiv.org/pdf/2207.03402) | Koka: the effect row says what *may happen*. Effekt: effects are second-class capabilities passed implicitly, cannot escape their scope. Scala CC: a function's type records which capabilities it **captures**, so a closure holding `IO` is visibly `{io} A => B`. | id_effect's `R` is a Koka/ZIO row. Its blind spot is **capture**: a Layer that captures `Http` into a `Signer` hides `Http` from `Signer`'s users. Scala CC is the formal fix (types record captured caps). For us: compute capture transitively over the Layer graph at build time (§4, option D). |
| **seL4 CAmkES/capDL, Cogent** (https://trustworthy.systems/projects/cogent/) | ADL → capDL → proved initialiser. Cogent: a *certifying* compiler that emits a proof that the C refines the functional spec per compilation. | Voltaic → system description should be **certifying**: emit, alongside the config, evidence a small independent checker validates (translation validation), rather than trusting the compiler. |
| **AADL → seL4 (HAMR / BriefCASE)** (https://hamr.sireum.org/) | Architecture model (AADL) with typed ports compiled to CAmkES/Microkit configs, glue code and component skeletons. | Proof that "compile an architecture description to isolation configs + generated typed glue" works in practice. Our twist: the architecture is partly *inferred from code*. |
| **CoCo genpolicy** (above) | Generates guest-side policy from a workload manifest. | Same direction as us, on the weakest possible input. |
| **Android permissions** (above) | Hand-written manifests over-grant. | Hand-written manifests for foreign software will bloat; mitigate with observation-assisted drafting and review. |

---

## 3. Inter-compartment channels

### 3.1 Comparison

| Mechanism | How | Performance (order of magnitude) | Who can confuse whom | DoS | Covert channels |
|---|---|---|---|---|---|
| **virtio-vsock** (AF_VSOCK; `man 7 vsock`) | Stream/seqpacket sockets addressed by (CID, port); host VMM/vhost-vsock relays. Used by Firecracker, Kata, Ghaf, AVF (binder RPC). | Several Gbit/s and tens of µs latency for vhost-vsock *(recalled; measure)*. | Guest cannot spoof its CID (host assigns). Guest↔guest traffic needs a host relay, so the **host sees and mediates everything** — a policy point, and a trusted party. Payload is an untyped byte stream: the receiver parses untrusted bytes. | Connect floods, unbounded buffers in the relay; need per-peer credit. | Low–medium (timing, queue occupancy). |
| **vhost-user** (https://qemu-project.gitlab.io/qemu/interop/vhost-user.html) | Device backend in a separate host process; VMM passes guest memory fds over a Unix socket. | Near-native for net/blk/fs (virtiofsd). | The **backend maps all of the guest's memory** (unless IOMMU/vIOMMU mode is used). A compromised backend owns the guest; a malicious guest can attack the backend via virtqueue contents (double fetch from shared rings). | Guest can spin the backend. | High (shared memory). |
| **virtio-vhost-user** (https://wiki.qemu.org/Features/VirtioVhostUser) | A *VM* acts as the vhost-user backend for another VM ("device VM", "driver domain"). | Close to vhost-user. | Moves device backends out of the host into compartments — the KVM analogue of Xen driver domains. Same memory-exposure caveat between the two VMs. Not upstream-mainstream; check status. | as above | High. |
| **IVSHMEM** (https://www.qemu.org/docs/master/system/devices/ivshmem.html) | A shared memory region as a PCI BAR, optional doorbell interrupts (ivshmem-doorbell). | Highest throughput, lowest latency; zero-copy. | **No mediation at all**: both sides read/write concurrently, so every field is TOCTOU-exposed; the protocol must copy-then-validate. Neither side can be policed by the host after setup. | Either side can corrupt rings forever; only teardown helps. | Very high bandwidth. |
| **Xen grant tables + libvchan** | A domain *grants* specific pages to a specific peer; vchan builds a ring + event channel on them. qrexec runs on vchan. | High; page-granular sharing. | Granter controls exactly which pages; still shared-memory TOCTOU: XSA-155 ("paravirtualized drivers incautious about shared memory contents", double fetch) *(recalled)*. | Event-channel storms. | High. |
| **Xen Argo / V4V** (OpenXT) | Hypervisor copies messages between rings it owns; hypervisor-enforced firewall. | Lower than shared memory (copy), still fast. | No shared memory between peers → no TOCTOU between them; policy enforced by the hypervisor. | Ring sizes bound memory. | Low–medium. |
| **seL4 shared memory + notifications / endpoints (Microkit channels)** | Static memory regions mapped into two PDs; notifications are badged binary semaphores; protected procedure calls via endpoints. | Fastest IPC with a verified kernel (sub-µs). | Kernel guarantees only the configured PDs share; the protocol on the region is still the components' problem (copy-then-validate). | Notifications coalesce, so no queue to flood; PPC has priority rules. | Kernel proofs cover storage channels; timing channels are partially addressed (time protection research). |
| **Zircon channels + FIDL** (https://fuchsia.dev/fuchsia-src/reference/kernel_objects/channel) | Kernel-mediated message queues carrying bytes **and handles**; handles are *moved*, rights can only be reduced on duplicate; FIDL generates typed bindings and validates encoding. | µs-level; copies messages. | Receiver gets kernel-validated handles, cannot forge them; FIDL decoder validates wire format. The classic confusion — names instead of handles — is avoided by design. | Channel has bounded message size; queue depth limits; peer-closed signals. | Low–medium. |
| **Cap'n Proto RPC** (https://capnproto.org/rpc.html) | Typed schema; interface references are capabilities you can pass in messages; promise pipelining; capabilities die with the connection; levels 1–4 (three-party handoff and equality are the higher levels; check the current implementation status in your chosen implementation). | Zero-copy encoding; one round trip for chains of calls. | Authority = possession of a reference on this connection, so the confused deputy is avoided by *designation*. The parser must survive hostile messages: the traversal limit and nesting limit are DoS controls, and the C++ implementation has had security advisories in the decoder *(recalled; check the project's CVE list)*. Without 3PH, A→B→C capability passing proxies through B, which then sees all traffic. | Traversal limits, per-connection flow control (streaming), call queues need quotas. | Low–medium. |

### 3.2 Channel lessons

1. **Shared memory is a performance optimisation, never a security primitive.** Every shared-ring
   design (vhost-user, IVSHMEM, grant tables, seL4 regions) needs copy-then-validate discipline
   in the receiver; XSA-class double-fetch bugs are the result when it is missing. Use shared
   memory only between compartments of the **same label** or behind a generated, audited ring
   library.
2. **Mediated copy channels are the default for cross-label traffic** (vsock relay, Argo, Zircon
   channels). The mediator is a policy enforcement point; keep it tiny.
3. **Carry capabilities, not names.** Zircon handles and Cap'n Proto references remove the
   confused deputy by construction (Hardy, http://cap-lore.com/CapTheory/ConfusedDeputy.html).
   qrexec passes *strings*; that is why Qubes needs a global name-based policy.
4. **DoS needs accounting, not just bounds.** Genode's quota donation (client pays for server
   state) is the only design that makes a shared server robust against its clients by
   construction. Bounded queues + per-peer credit is the minimum.
5. **Typed decoding is the attack surface.** Generated decoders with traversal limits (Cap'n
   Proto, FIDL) and Mojo's rule "the privileged side validates everything" are the practice.
6. **Covert channels are a per-pair decision.** Accept them for ordinary compartments; for the
   few high-value pairs (secrets vault vs. internet-facing), use copy channels, no shared memory,
   separate cores/cache partitions where available, and fixed-rate or batched messaging.

---

## 4. How to derive policy from `R` types — design options with trade-offs

The pipeline every option shares:

```
Rust program (id_effect)          Voltaic topology             Realiser (host / VMM)
  root Effect<_, _, R_root>  ──►   compartments, routes  ──►   flat system description
  Layer graph (Out, In)            attenuations, labels         (capDL-like: VMs, devices,
        │                                 │                      channels, quotas, labels)
        └── extracted manifest ───────────┴──► checker ──► realised config + evidence
```

### Option A — Residual-`R` manifest ("WIT world from `R`")

At build time extract, for each compartment's entry effect, the residual `R` after locally
provided Layers: those are its **imports** (`use`). Layers the compartment publishes are its
**exports** (`expose`). Emit a manifest per compartment; the Voltaic topology supplies the
`offer`s. The checker fails the build on any unsatisfied import, any unused offer, and any
dangerous capability outside an allowlist (Fuchsia scrutiny).

- Extraction mechanism: an attribute macro on `main` or a generated `const MANIFEST` via a
  trait over the HList (`impl Manifest for HCons<H, T>` where `H: CapabilityDescriptor`), then
  read from the built artefact (custom ELF section) or a `build.rs`/test harness that prints it.
  Prefer reading from the **binary that will run**, not the source, so the manifest cannot
  diverge from what ships.
- Capability identity must be stable and global: `TypeId` is not. Each cross-compartment
  capability type needs a descriptor `{ package, name, major version, schema hash }` (WIT
  package / FIDL library style).
- Pros: zero extra authoring for our code; drift impossible; supply-chain change shows up as a
  manifest diff in review.
- Cons: `R` says *kind*, not *instance* or *amount* (needs B); hides captured authority (needs
  D); ambient Rust authority bypasses it (needs E + the compartment boundary).

### Option B — Shape from types, instance and attenuation from the topology

`R` fixes the *protocol* (`HttpClient`), the Voltaic route picks the *provider instance*
(`egress-proxy.api_example`) and an *attenuation* (`hosts = ["api.example.com"]`, `methods =
[GET]`, rate). Attenuations are implemented by an interposed proxy Layer or by the provider
honouring a per-session policy keyed by an unforgeable session label (Genode).

- Pros: matches Fuchsia/Genode; the program never chooses its own authority; same binary can be
  deployed with different authority.
- Cons: two sources of truth (code and topology) — but they are *complementary*, and the
  checker ties them (every route's protocol must equal the import's descriptor).
- Variant B′: **indexed capability types** — `HttpClient<Egress<ApiExample>>` with the
  destination as a type parameter, so attenuation is in `R` itself. Pushes policy into code
  (good for our own fixed-purpose services, bad for reuse); use sparingly, for authority whose
  scope is part of the program's meaning (e.g. `Keystore<SigningKey<Deploy>>`).

### Option C — Remotable capability traits with generated proxies

A capability crossing a compartment boundary must implement `Remote` (an IDL schema: Cap'n
Proto, FIDL-like, or WIT). Codegen produces a client Layer (`Layer<HttpClient, E, caps!(Channel<HttpClientProto>)>`)
and a server adapter. Inside the compartment, the program's `R` is unchanged; the realiser
provides the proxy Layer bound to the granted channel. Non-remotable capabilities (`Clock`,
`Random`, `Logger`) are provided by the compartment runtime from primitive grants.

- Pros: the boundary is invisible to program logic, and testable in-process with the same
  `R`; the wire type is generated from the same trait, so the channel is typed end to end.
- Cons: trait methods must be serialisable (no closures, no borrowed returns); async/streaming
  and capability-returning methods need IDL support — **Cap'n Proto-style capability passing
  is what makes dynamic leaves (open a file → get a `File` cap) possible**. Location
  transparency must stay explicit in types (latency/failure: Cap'n Proto's CORBA lesson — the
  remote error type must appear in `E`).

### Option D — Layer-graph closure (capture analysis)

Extract the *whole* Layer graph per compartment, not just the root `R`: nodes = Layers, edges
= `In → Out`. Compute, for each exported service, the set of external capabilities it
transitively captures. This is the Scala-capture-checking idea done as a build-time analysis.

- Needed for IFC (§5): "does `Signer` (exported to the mail compartment) capture `Internet`?"
- Pros: catches authority hidden inside services.
- Cons: needs Layers to be constructed declaratively enough to extract (no `Layer::from_effect`
  that grabs `DynEnv` at run time). Rule: `DynEnv` is forbidden in compartment roots, or
  everything reachable from it is treated as "all of R".

### Option E — Make `R` approximately sound inside the compartment

Without this, `R` is documentation. Enforce: `#![forbid(unsafe_code)]` except audited crates;
clippy `disallowed_methods`/`disallowed_types` for `std::{fs, net, process, env}` and raw
`libc`; capability-carrying I/O through `cap-std`-style handles that only the runtime can mint;
`cargo-vet`/`cargo-deny` for the dependency set; a link-time check that the binary imports no
syscall wrappers outside the runtime crate (symbol scan). Inside the guest: seccomp + Landlock
derived from the same manifest (CloudABI/Capsicum), so even unsafe code meets a wall.

- Pros: supply-chain protection (Austral's argument) and defence in depth.
- Cons: friction with the Rust ecosystem; FFI-heavy crates need exceptions.

### Option F — Foreign software: hand-written `R`

For programs not on id_effect, write the manifest in the same capability vocabulary (a
`foreign` compartment declares `imports = [Wayland<Toplevel>, FileChooser, Egress<"…">]`).
Enforcement is entirely the compartment boundary plus interposed proxies (Wayland filter like
sommelier/Spectrum, egress proxy, portal for files). Draft manifests by **observation**
(learning-mode run that records attempted accesses, à la AppArmor `aa-genprof`) and then
*review and minimise*; Android shows unreviewed manifests over-grant. Prefer powerbox grants
(user picks a file) over static grants for anything user-data-shaped.

### Option G — Certifying lowering and system-wide checks

Voltaic compiles topology + extracted manifests into a **flat system description** (capDL
analogue: every compartment, device, channel endpoint, quota, label, and attenuation, with no
abstraction left). A small independent checker (a few hundred lines, separately reviewed,
property-tested) validates: (1) the flat description implements the topology (translation
validation), (2) global properties: no unrouted imports, no unused offers, allowlists, the IFC
lattice (§5), no shared-memory channel across labels, dom0-equivalent has no NIC. The realiser
(host agent / VMM launcher) consumes only the flat description. Long term, this is where
formal proof can attach (capDL-style), without proving Voltaic itself (Cogent's certifying
approach).

### Trade-off summary

| Option | Authoring cost | Precision | Soundness depends on | Verdict |
|---|---|---|---|---|
| A residual-`R` manifest | none | kind only | E + boundary | **Core** |
| B shape/instance/attenuation split | topology only | high | proxies honouring attenuation | **Core** |
| B′ indexed cap types | per program | highest | type discipline | Selective |
| C remotable traits + proxies | IDL per cap | high | codegen + decoder | **Core** for cross-compartment caps |
| D Layer-graph closure | none (rules on Layers) | captures hidden authority | declarative Layers, no `DynEnv` | **Core** for IFC |
| E in-compartment soundness | lint config, exceptions | — | Rust ecosystem | Strongly recommended |
| F hand-written foreign manifests | per program | medium | boundary + proxies | Necessary |
| G certifying lowering + checker | one-off | — | small checker | **Core** |

---

## 5. Information flow beyond reachability

Reachability ("A has a route to B") is what capability routing checks. It does not stop data
moving *through* a compartment that legitimately holds two routes.

### 5.1 The failure modes

1. **Confused deputy.** `vault` offers `Sign` to `mail`; `mail` also holds `Internet`. A
   hostile email makes `mail` ask `vault` to sign attacker-chosen bytes; the signature leaves
   via `Internet`. Every edge was granted. Qubes' split-GPG mitigates with `ask` (a human
   checks each use) — a human declassifier.
2. **Transitive exfiltration.** `secrets → backup → object-store → internet`. Each hop is
   least-privilege; the path is not.
3. **Integrity inversion (Biba).** `internet → feed-reader → build → deploy`: low-integrity
   input reaches a high-integrity action.
4. **Hidden capture.** A service exported to a low compartment captures a high capability
   inside its Layer graph (§4 D).
5. **Covert/side channels** between co-resident compartments (cache, timing, shared rings).

### 5.2 Techniques and what to steal

- **Label the compartments, check the channels (Flume/HiStar/DStar at VM granularity).** Each
  compartment gets a secrecy label set S and integrity set I from a small lattice declared in
  Voltaic (`public < internal < secret:deploy-keys`, integrity `internet < user < build`). A
  channel A→B (data flowing to B) is legal iff `S(A) ⊑ S(B)` and `I(B) ⊑ I(A)`. Bidirectional
  RPC means *both* directions carry data: a request/response channel needs both directions to
  satisfy the rule, or an explicit declassifier/endorser on the edge. The checker (option G)
  enforces this over the whole graph, so path properties (2, 3) are global, not per edge.
- **Declassifiers and endorsers are compartments, and the only edges that go "down".** A
  `sign-gateway` that receives a *structured* signing request, validates it against a policy
  (only commits of repo X, only messages whose body hash the user saw), and returns a
  signature, is an explicit downgrade point (MILS "guard", Jif `declassify` with authority).
  The human-in-the-loop `ask` of Qubes becomes one kind of declassifier (a trusted-path prompt
  rendered by the GUI compartment, not by the requester).
- **Designation instead of ambient naming (Hardy).** Deputies should act on *capabilities the
  caller passes* (Cap'n Proto/Zircon style), not on names the caller supplies. Then a deputy
  cannot be tricked into using its own authority on the caller's behalf. Option C makes this
  natural: `Sign::sign(doc: DocumentCap)`, where `DocumentCap` is something the caller could
  only obtain legitimately.
- **Poly-instantiate deputies per label (Flume, Qubes disposables).** A service that must serve
  several labels runs one instance per label (a disposable compartment per taint), so it never
  holds high and low data at once. Cost is RAM; microVM + shared Nix store makes it cheap.
- **Typed labels in `R` (LIO-style, compile time).** Put labels on capability types:
  `Read<Secret<DeployKeys>>`, `Egress<Public>`. A trait bound on runnable effects —
  "no `R` contains both a read above L and a sink below L unless it also contains
  `Declassify<L>`" — is expressible over the HList with marker traits, so a single program
  cannot be *written* to hold both without the declassify capability being visible in review.
  Combine with option D so captured capabilities count. This is coarse (whole-program label,
  like LIO's floating label without dynamic checks), and that coarseness is the point:
  per-variable IFC (Jif/FlowCaml) is too costly for a fleet.
- **Integrity on inputs to actuators.** Mark actuating capabilities (deploy, switch, money,
  sending email as the user) as high-integrity sinks; anything with an internet-tainted import
  cannot hold them without an endorser.
- **Covert channels: decide per pair.** For pairs across the top of the lattice: copy channels
  only, no shared memory, separate physical cores (and cache partitioning where the CPU has
  it), batched/fixed-rate channels. Accept residual covert channels elsewhere and say so in the
  threat model; MILS shows full temporal isolation is an embedded-scale luxury.

---

## 6. Ranked recommendation

1. **Adopt Fuchsia's use/offer/expose algebra as the policy model, with `use` generated from
   residual `R` and exports from published Layers (options A + B).** Capability *shape* from
   types, *instance + attenuation* from the Voltaic topology, dangerous-capability allowlists
   separate from routing. The build fails on unsatisfied, unused or disallowed routes
   (Fuchsia scrutiny). Highest leverage, lowest authoring cost, kills policy drift.

2. **Lower to a flat, capDL-like system description checked by a small independent checker
   (option G).** The realiser consumes only that artefact; policy is a build output with the
   system's provenance (never fetched at runtime, unlike Ghaf). This is where IFC checks,
   shared-memory rules and formal assurance attach later.

3. **Typed, capability-carrying RPC as the one inter-compartment wire (option C)**, generated
   from the capability traits, over vsock (mediated by a tiny host relay) for cross-label
   traffic. Cap'n Proto semantics (or capnp itself) give designation, pipelining and dynamic
   leaves. Static roots, dynamic attenuated sub-capabilities, powerbox for user files
   (Spectrum portal, Qubes file copy).

4. **Compartment-level IFC lattice with explicit declassifier/endorser compartments, deputies
   poly-instantiated per label, and Layer-graph capture analysis (option D + §5).** This is
   what makes the result better than Qubes, whose policy is reachability with a human
   `ask`.

5. **Genode-style resource accounting on every channel**: quota donation or at least per-peer
   credit, bounded queues, unforgeable session labels assigned by the routing layer.

6. **Make `R` approximately sound inside each compartment (option E)** — lints, cap-std
   handles, no `DynEnv` at roots, seccomp/Landlock derived from the manifest. Supply-chain
   protection is the payoff.

7. **Compartment substrate: KVM microVMs with a disaggregated VMM** (crosvm/Cloud Hypervisor
   process-per-device, device backends moving into device VMs via virtio-vhost-user), a tiny
   admin compartment with no NIC (Qubes dom0 invariant), net/GUI/USB/audio as service
   compartments (Ghaf/Qubes), Wayland filtering per guest (sommelier/Spectrum), host-untrusted
   pVM/TDX/SEV where hardware allows (AVF/CoCo). Shared memory (IVSHMEM/vhost-user) only
   between same-label compartments or behind an audited ring library.

8. **Foreign software via hand-written manifests in the same vocabulary (option F)**, drafted by
   observation, reviewed for minimality, enforced only by the boundary and interposed proxies.

Explicitly **not** recommended: Qubes-style string policy files as the source of truth; runtime
policy fetching; a single shared network as the inter-compartment channel; full multiparty
session types or per-variable IFC (cost far above benefit at fleet scale); trusting `R` without
the boundary.

---

## 7. Open questions for the design

- Stable capability identity: who owns the descriptor namespace and versioning (WIT-package
  style), and how a breaking change to a capability trait is rolled across the fleet.
- Whether a second, finer tier (Wasm components inside one VM, WIT worlds generated from `R`)
  is acceptable for low-risk id_effect programs, given "hardware-isolated" is the stated bar.
- Where the human trusted path lives (GUI compartment rendering declassification prompts) on
  headless fleet hosts (drakkar/mimir have no user at the console).
- Whether Cap'n Proto (C++ reference, Rust `capnp-rpc`) or an id_effect-native IDL is the wire;
  either way the decoder is the attack surface and must be fuzzed.
- Measurement: vsock throughput/latency per channel class on the fleet's CPUs before choosing
  where shared-memory fast paths are worth their risk.
