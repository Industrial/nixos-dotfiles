# 01 — Smallest credible TCB substrate for a compartmentalised NixOS server/agent fleet

Research date: 2026-11-27. Read-only research; every number has a URL. Where a source was
a secondary summary rather than the primary document, that is said.

## 0. Bottom line

* **The smallest credible substrate is seL4.** It is the only one whose kernel has
  machine-checked functional correctness *and* isolation proofs (integrity + confidentiality),
  and the kernel is ~10k lines. **That claim holds fully on AArch64 (and AArch32/RISC-V), not on x86_64.**
  On x86_64 the proof is C functional correctness only. It excludes VT-x, the fastpath, and
  integrity/confidentiality. No configuration on any architecture covers the IOMMU/SMMU, SMP, or boot.
* **On x86_64 today, seL4 cannot yet host the Linux side of this fleet in production.**
  libvmm x86 guests are single-vCPU, x86 PCIe passthrough is a "working prototype, not ready
  for public use" (target Q4'26), and LionsOS is at alpha release 0.4.0.
* **What can run today is KVM plus a Rust VMM** (cloud-hypervisor / crosvm / Firecracker). The
  host Linux kernel stays in every guest's TCB, and that kernel is where the TCB is large. Android's
  pKVM is the one mainstream design that takes the host kernel out of guest TCB. It is
  arm64-only, and upstream it still lists IOMMU DMA isolation as "Unimplemented".
* **Recommended path:** start on NixOS + KVM + Rust VMMs, with the host stripped down and
  device back-ends in driver VMs. Shape every interface (typed channels, static capability
  manifests, shared-memory queues) as a 1:1 image of the seL4 Microkit / sDDF model. Move
  aarch64 nodes to seL4 (verified) or pKVM first. Move x86 nodes to seL4 + libvmm once
  multi-vCPU guests and PCIe passthrough land. Details are in §5.

## 1. Framing: what "TCB" means here

For a given compartment C, TCB(C) = privileged kernel/hypervisor + every component that can
read or write C's memory or forge its channel traffic (VMM, device back-ends, multiplexers on
its path) + boot chain + firmware/SMM/ME/PSP + the CPU. Two consequences:

1. The firmware/CPU floor is shared by **every** option below. A verified kernel shrinks the
   software above the floor. It does nothing about microarchitectural side channels. seL4's
   confidentiality proof is explicitly about the model and holds only between domain-scheduler
   domains: "confidentiality holds between security domains of seL4's domain scheduler, not
   between arbitrary threads" ([seL4 proofs](https://sel4.systems/Verification/proofs.html)).
2. In a hosted design (KVM), the host kernel *and* the VMM process serving C are in TCB(C).
   In a microkernel design, only the kernel plus C's own per-VM VMM and the drivers it shares
   are. This difference is usually larger than the difference between hypervisors.

## 2. Substrate by substrate

### 2.1 seL4 and its ecosystem

**Kernel size.** The original verified kernel was 8,700 lines of C and 600 lines of assembler.
7,500 lines of C were verified; assembly and boot code (~1,200 lines) were not
([Klein et al., CACM 2010](https://cacm.acm.org/?p=30656); [TS numbers page](https://trustworthy.systems/projects/OLD/l4.verified/numbers)).
Proof: ~200k lines of Isabelle in 2009, ~500k lines by 2015 (same TS page). The figures are
old; today's kernel is larger per-arch, but still on the order of 10k SLOC per configuration.

**Proofs per architecture** (primary source: [verified configurations](https://docs.sel4.systems/projects/sel4/verified-configurations.html)):

| Arch / config | Functional correctness (C) | Fastpath in proof | Integrity + availability | Confidentiality | Binary correctness | capDL initialiser | Hyp mode in proof | FPU |
|---|---|---|---|---|---|---|---|---|
| AArch32 `ARM` | yes | yes | yes | yes | **yes** | yes | no | no |
| AArch32 `ARM_HYP` (EL2) | yes | yes | – | – | – | – | yes | no |
| **AArch64** (EL2) | yes | yes | **yes** | **yes** | not yet ("further properties under development") | – | **yes** | yes |
| RISC-V 64 | yes | no fastpath | yes | yes | – | – | no (no H-ext) | no |
| **x86_64 `X64`** | **yes** | **no fastpath** | **no** | **no** | no | no | **no (VT-x not verified)** | yes |

Unverified on every architecture: "none of our verified configurations take into account
address translation for devices (System MMU or IOMMU), debug/profiling/printing interfaces, or
the kernel startup at boot" (same page). MCS (mixed-criticality scheduling): C verification is done
for RISC-V, AArch64 is due Q3/27. Multikernel (the path to verified multicore) is due Q3/28
([roadmap](https://sel4.systems/roadmap.html)). SMP seL4 uses a big kernel lock, and its
verification is "on hold" ([TS multicore page](https://trustworthy.systems/projects/OLD/multicore-sel4)).
So **every multi-core seL4 deployment today runs an unverified configuration**. The
proof-preserving way to use many cores is the static multikernel (one kernel instance per core,
resources partitioned), which is what Proofcraft is verifying
([multikernel roadmap slides, 2024](https://sel4.systems/Summit/2024/slides/multikernel-roadmap.pdf)).

x86 features exist in the kernel but sit outside the proof: `KernelVTX` (default off),
`KernelIOMMU` (VT-d, default on), `KernelMaxNumNodes` for SMP
([configurations](https://docs.sel4.systems/projects/sel4/configurations.html)).

**seL4 Microkit** (static system description of protection domains, channels and memory
regions). The current release is 2.4.0, on seL4 17.0.0. It fixed x86-64 VMs so that more than one VM
per system works, including in SMP `x86_64_generic_vtx`. It also closed two capability-leak bugs:
reply caps could carry grant, and PDs could forge fault IPCs to their parent
([2.4.0 notes](https://docs.sel4.systems/releases/microkit/2.4.0.html)). The platform list includes
`x86_64_generic` and `x86_64_generic_vtx`, although the same page still says "x64 support is on the
roadmap" ([platforms](https://docs.sel4.systems/projects/microkit/platforms.html)). Treat x86
as early.

**libvmm** (Microkit VMM library). ARM: Linux guests, multi-vCPU via PSCI, hardware GIC
virtualisation. x86: ACPI, Linux and OVMF/EFI guests, software-virtualised xAPIC. Limitations:
"x86 guests are limited to a single vCPU" and "DMA-capable device passthrough isn't isolated by
an IOMMU on ARM". The README says it is "not ready for production use"
([libvmm README](https://raw.githubusercontent.com/au-ts/libvmm/main/README.md)).
One VMM runs per guest, unprivileged, as its own PD. Guest escape reaches only that VMM's
capabilities, which is the structural advantage over KVM+QEMU.

**sDDF / LionsOS.** Drivers, "virtualisers" (multiplexers) and clients are separate PDs
connected by lock-free shared-memory queues with a model-checked signalling protocol.
The system is static ([LionsOS](https://lionsos.org)). Status: release 0.4.0. Ethernet drivers and
the Tx virtualiser have functional-correctness proofs. Pancake (verified-language) drivers exist
for serial, Ethernet is in progress. x86-64 PCIe passthrough is a prototype (Q4'26). Multi-vCPU x86 guests
are planned. Windows 11 boots on x86-64. 0.5.0 is due end of 2026
([status & roadmap](https://lionsos.org/docs/status_and_roadmap/)).

**CAmkES** is the older component framework, still documented with CAmkES-VM, but new work
(LionsOS, libvmm, rust-sel4 Microkit crates) targets Microkit
([docs nav / roadmap](https://sel4.systems/roadmap.html)).

**rust-sel4** (seL4 Foundation). It supports "all configurations ... supported by the kernel itself,
except those based on 32-bit x86". The Microkit crates support all Microkit configurations
([supported configurations](https://docs.sel4.systems/projects/rust/supported-configurations.html);
[source](https://github.com/seL4/rust-sel4)). It is `no_std` + `alloc` oriented. An
std-dependent runtime (id_effect, if it needs threads, `std::sync`, or an async reactor) needs a
port onto Microkit's event loop. That port is the main engineering cost of "native Rust on seL4".

**License / production.** Kernel GPLv2, user-level BSD. Users include DARPA HACMS (Boeing
ULB helicopter), HENSOLDT TRENTOS, and NIO vehicles ([who uses seL4](https://sel4.systems/use.html)).
I found no public seL4 deployment as a general-purpose x86 *server* hypervisor.

### 2.2 Genode / Sculpt OS

Genode is a component framework with strict, parent-mediated **session routing**: a child
can reach a service only along routes its parent's policy grants. This is the closest
existing design to "typed channels, explicitly granted"
([Genode Foundations](https://genode.org/documentation/genode-foundations/)). Kernels:
base-hw (Genode's own), NOVA, seL4, plus Linux for development. **Sculpt OS 26.10 (30 Oct 2026)
is "the first version based on Genode's custom microkernel instead of relying on a 3rd-party
kernel"**. The stated reason is that it "solves long-standing deficiencies concerning CPU
scheduling and kernel-memory management". VMs run in VirtualBox 7, with the Seoul VMM as a lightweight option
([Genode news 2026](https://genode.org/news/2026); [Phoronix](https://phoronix.com/news/Sculpt-OS-26.10)).
Sculpt on seL4 was "preliminary" on x86 notebooks as of the 2025 seL4 Summit
([slides](https://sel4.systems/Summit/2025/slides/sculpt-os.pdf)). Implication: the default
Genode kernel is unverified, and Genode's move away from NOVA/seL4 shows how hard *dynamic*
systems are on a third-party kernel. AGPLv3 / commercial. Its focus is the desktop.

### 2.3 NOVA / Hedron / BedRock (BlueRock)

NOVA is a microhypervisor (Udo Steinberg, now with BlueRock Security). It runs on x86-64
(VT-x+EPT, optional VT-d; AMD-V+NPT) and ARMv8-A, with optional CET and TXT measured launch,
under GPLv2 ([NOVA repo](https://github.com/udosteinberg/nova)). Size is about **17 KLOC with
15 hypercalls**, per a BlueRock paper as summarised in search results. The FOSDEM 2025 deck gives the
NOVA *specification* at ~7 KLOC and a hardware model at ~11 KLOC, written in Coq/Iris separation logic. The proofs
are on a `proof` branch ([FOSDEM 2025](https://fosdem.org/schedule/event/fosdem-2025-5083-a-formal-specification-of-the-nova-microhypervisor);
[BlueRock tech report](https://bluerock-io.github.io/formal-methods/tech_reports/towards-modular-specification-and-verification-of-concurrent-hypervisor-based-isolation.pdf)).
Unlike seL4's, the verification targets *concurrent* (SMP) code, but it is not complete end-to-end.
**Hedron** (Cyberus fork) has a public mirror with its last push in Oct 2023. Cyberus now sells a Cloud-Hypervisor/KVM
product instead ([ecosyste.ms metadata](https://awesome.ecosyste.ms/projects/github.com%2Fcyberus-technology%2Fhedron);
[Cyberus](https://cyberus-technology.de/en/cloud/cloud-hypervisor)). That is a market signal:
a microhypervisor vendor moved to KVM for ecosystem reasons.

### 2.4 Muen (SPARK separation kernel)

x86-64 only for production (preliminary ARM64 on Zynq US+). Written in SPARK 2014 and "formally
proven to contain no runtime errors at the source code level". Functional-correctness proofs are
"ongoing". Static resource assignment, fixed cyclic scheduling, multicore, SMP Linux VMs,
VT-d DMAR+IR passthrough. GPLv3. Developed by codelabs with secunet
([muen.sk](https://muen.sk/); [AdaCore](https://www.adacore.com/highlights/muen-project)).
An academic functional-correctness model of Muen including VT-x exists
([Haque et al. 2020](https://ar5iv.arxiv.org/html/2001.10328)). It is very small and its x86 server story
is real, but it is fully static (a policy is compiled into the image) and its community is small. No Rust.

### 2.5 Xen (and why Qubes chose it)

Qubes: "the Xen architecture allows for the creation of more secure systems (i.e. with a much
smaller TCB ...)". Qubes also keeps QEMU "outside of the TCB" by putting it in stub domains, and
relies on untrusted driver domains via VT-d ([Qubes FAQ](https://doc.qubes-os.org/en/latest/introduction/faq.html)).
Size: the hypervisor grew from 45k (2.0) to 121k (3.0) to **270k LOC (4.0)**, and the total TCB with
dom0 and tools is ~8.5 MLOC for 4.0, per a 2012 paper as summarised in search results
([Springer](https://link.springer.com/content/pdf/10.1007/978-3-642-31540-4_23.pdf)). It is dated, but the
order of magnitude still holds. Support matrix for 4.23-unstable: x86 VT-d and AMD IOMMU "Supported". Arm SMMUv3 is
"Tech Preview". Dom0less is listed for Arm only. Driver-domain disaggregation is "Supported, with
caveats". FLASK XSM is "Experimental". Argo is "Tech Preview"
([SUPPORT.md](https://xenbits.xen.org/docs/unstable/SUPPORT.html)). x86 Hyperlaunch (boot
without a dom0 superuser) has a design merged in 2021, but x86 shipping status is unclear
([design](https://xenbits.xen.org/docs/latest/designs/launch/hyperlaunch.html)).
Edera Protect rebuilds the Xen control plane in Rust for container-per-VM ("zones").
It is adding a KVM backend in 2026 ([Edera docs](https://docs.edera.dev/technical-overview/architecture/overview/);
[arXiv 2501.04580](https://arxiv.org/abs/2501.04580)). Xen is the most proven *disaggregated*
design on x86 today, but it has no proofs, and its hypervisor is an order of magnitude larger than seL4/NOVA/Muen.

### 2.6 KVM + Rust VMMs; pKVM; Hyperlight

* **Firecracker**: ~50k LOC Rust, "96% fewer lines than QEMU" (QEMU >1.4 MLOC). It started as a
  crosvm fork, runs ~3 MB per microVM, and uses the jailer + seccomp
  ([Amazon Science](https://www.amazon.science/blog/how-awss-firecracker-virtual-machines-work);
  [NSDI'20 paper](https://css.csail.mit.edu/6.566/2023/readings/firecracker.pdf)). Production: Lambda, Fargate.
* **crosvm**: "A process per virtual device", each jailed with minijail (namespaces + seccomp)
  ([crosvm book](https://crosvm.dev/book/architecture/overview.html)). It is the VMM for ChromeOS and AVF
  ([Android blog](https://android-developers.googleblog.com/2023/12/virtual-machines-as-core-android-primitive.html)).
* **cloud-hypervisor**: Rust, built on rust-vmm. x86-64 + AArch64 (riscv64 experimental). KVM and MSHV.
  virtio, hot-pluggable VFIO passthrough, vhost-user offload
  ([repo](https://github.com/cloud-hypervisor/cloud-hypervisor)).
* **TCB caveat for all three:** the host Linux kernel (KVM is ~150k LOC by itself,
  per a vendor blog, [Edera](https://www.edera.dev/stories/xen-vs-kvm-why-xen-offers-superior-security-in-virtualization))
  plus all reachable host subsystems are in every guest's TCB.
* **pKVM / AVF**: after boot "the kernel is deprivileged and it's no longer considered trusted
  by the hypervisor". Guest memory is "unmapped from the host" via stage-2. "pKVM requires
  IOMMU hardware for every DMA-capable device". "Currently this implementation is limited to
  ARM64". On x86_64 AVF runs non-protected VMs only
  ([AVF architecture](https://source.android.com/docs/core/virtualization/architecture)). The EL2
  code base is "~50x" smaller than the Linux kernel ([Android blog](https://android-developers.googleblog.com/2023/12/virtual-machines-as-core-android-primitive.html)).
  Upstream Linux calls pKVM "experimental", and DMA isolation using an IOMMU and pvmfw are
  "Unimplemented" upstream (they live in Android's tree)
  ([kernel docs](https://docs.kernel.org/next/virt/kvm/arm/pkvm.html)). An x86 port (Intel
  `pKVM-IA`) exists as an RFC for Linux 6.2, evaluated for ChromeOS in 2023. I found no evidence it has been merged
  ([RFC](https://spinics.net/lists/kvm/msg307648.html); [follow-up](https://spinics.net/lists/kvm/msg317320.html)).
* **Hyperlight** (Microsoft, CNCF sandbox, Apache-2.0): an embeddable Rust VMM for micro-VMs with
  "No kernel or OS in the VM". Guests are `no_std` Rust/C ELF binaries. It runs on KVM/MSHV/WHP/HVF across
  x86-64 + AArch64, is pre-1.0, and is "not designed for ... full Linux guest workloads"
  ([repo](https://github.com/hyperlight-dev/hyperlight)). It is the closest off-the-shelf match for
  "a native Rust component in its own hardware domain" on KVM.
* **Confidential VMs (x86 analogue of pKVM)**: Intel TDX / AMD SEV-SNP take the host out of a
  guest's confidentiality/integrity TCB, at the cost of trusting the TDX module or PSP firmware and the
  side-channel record. Paravisors in Rust: OpenHCL/OpenVMM and COCONUT-SVSM
  ([OpenHCL](https://techcommunity.microsoft.com/blog/windowsosplatform/openhcl-the-new-open-source-paravisor/4273172)).
  They protect the guest *from* the host, not the host from the guest. That half matters when the host
  is the thing being shrunk.

### 2.7 Frontier systems (research or embedded; not hosting Linux guests today)

* **Atmosphere** (SOSP'25): an L4-style microkernel in Rust, functional correctness via Verus. "6K lines
  of executable code", proof:code 3.32:1, <2.5 person-years, verification in <20 s. Multi-CPU (big
  lock), IOMMU, containers ([paper](https://mars-research.github.io/doc/2025-sosp-atmo.pdf)).
  For comparison, seL4 took 11 person-years plus 9 for tooling (same paper). No isolation/noninterference theorem
  equivalent to seL4's, no binary proof.
* **Asterinas** (ATC'25): a Linux-ABI framekernel in which only OSTD may use `unsafe`. TCB is 14.0% of the codebase,
  against Tock 43.8%, Theseus 62.4%, RedLeaf 66.1%. >210 syscalls
  ([USENIX](https://www.usenix.org/conference/atc25/presentation/peng-yuke); [arXiv](https://arxiv.org/abs/2506.03876)).
  The isolation is language-based, not hardware-based, so it does not meet "hardware-isolated" by itself.
* **Theseus / RedLeaf** (OSDI'20): language-based single-address-space designs, also not hardware-isolated.
* **Hubris** (Oxide, MPU-based static tasks on microcontrollers) and **Tock** (embedded). Both are good
  models for static, manifest-driven task images, but neither is a server substrate
  ([Hubris](https://hubris.oxide.computer); [Tock](https://www.tockos.org)).
* **CHERI**: first CHERIoT silicon (SCI ICENI) shipped in 2026. Morello remains a prototype. CheriBSD
  is research-grade, and its FreeBSD upstreaming is planned through Feb 2027. No x86 CHERI is on any public
  roadmap ([CHERIoT](https://cheriot.org/silicon/2026/03/04/cheriot-first-silicon.html);
  [Cambridge](https://cheri.cst.cam.ac.uk/); [CHERI Alliance assessment](https://cheri-alliance.org/introducing-the-cheri-adoption-global-ecosystem-assessment-q1-2026/)).

## 3. Comparison table

| Substrate | Privileged TCB size | Verification | x86_64 | aarch64 | IOMMU / passthrough | SMP | Linux guests | Native Rust | Maturity / prod users | License |
|---|---|---|---|---|---|---|---|---|---|---|
| **seL4 + Microkit + libvmm/sDDF** | ~10k SLOC kernel ([CACM](https://cacm.acm.org/?p=30656)); per-VM VMM unprivileged | x86: FC only, no VT-x/fastpath; AArch64: FC + integrity + confidentiality; AArch32: + binary ([cfgs](https://docs.sel4.systems/projects/sel4/verified-configurations.html)) | VT-x unverified; Microkit x86 early | **best** | VT-d in kernel, unverified; x86 PCIe passthrough prototype; ARM passthrough without SMMU isolation ([libvmm](https://raw.githubusercontent.com/au-ts/libvmm/main/README.md), [LionsOS](https://lionsos.org/docs/status_and_roadmap/)) | BKL, unverified; multikernel proof Q3/28 | x86 1 vCPU; ARM multi-vCPU | rust-sel4, all configs ([docs](https://docs.sel4.systems/projects/rust/supported-configurations.html)) | Defence/auto embedded; not general servers | GPLv2 kernel / BSD |
| **Genode (base-hw) / Sculpt** | own µkernel (size not published here) | none on base-hw | yes | yes | yes (desktop-grade) | yes | VirtualBox 7, Seoul | possible, not first-class | Sculpt desktop; Genode Labs | AGPLv3 / commercial |
| **NOVA** | ~17 KLOC, 15 hypercalls (BlueRock, via search summary) | Coq/Iris spec + proofs in progress, concurrent ([FOSDEM'25](https://fosdem.org/schedule/event/fosdem-2025-5083-a-formal-specification-of-the-nova-microhypervisor)) | VT-x/AMD-V, VT-d | yes | VT-d | yes | yes, via user VMM | user-level, small ecosystem | BlueRock products; Hedron dormant | GPLv2 |
| **Muen** | small SPARK kernel (SLOC not published) | absence of runtime errors (SPARK); FC ongoing ([muen.sk](https://muen.sk/)) | **yes, primary** | preliminary | VT-d DMAR+IR | yes, static | yes, SMP | no (Ada/SPARK subjects) | secunet/high-assurance | GPLv3 |
| **Xen (+dom0less/Hyperlaunch)** | 270k LOC hypervisor (4.0) + dom0 ([Springer](https://link.springer.com/content/pdf/10.1007/978-3-642-31540-4_23.pdf)) | none (MISRA work) | yes | yes | x86 IOMMU supported; Arm SMMUv3 tech preview ([SUPPORT](https://xenbits.xen.org/docs/unstable/SUPPORT.html)) | yes | yes | Rust control plane (Edera) | Qubes, AWS (legacy), XCP-ng, auto | GPLv2 |
| **KVM + Rust VMM** | Linux host kernel (millions of LOC reachable) + ~50k LOC VMM ([Firecracker](https://www.amazon.science/blog/how-awss-firecracker-virtual-machines-work)) | none | yes | yes | VFIO, mature | yes | yes, best | Hyperlight kernel-less guests ([repo](https://github.com/hyperlight-dev/hyperlight)) | AWS, Google, everyone | GPLv2 / Apache |
| **pKVM (AVF)** | EL2 "~50x smaller than Linux" ([blog](https://android-developers.googleblog.com/2023/12/virtual-machines-as-core-android-primitive.html)) | none; host deprivileged by design | non-protected only; pKVM-IA RFC | **yes** | SMMU required; upstream "Unimplemented" ([docs](https://docs.kernel.org/next/virt/kvm/arm/pkvm.html)) | yes | yes (Microdroid / Linux) | crosvm, pvmfw | Pixel / Android 14+ | GPLv2 |
| **Atmosphere** | 6K exec LOC ([SOSP'25](https://mars-research.github.io/doc/2025-sosp-atmo.pdf)) | FC via Verus | yes (research) | – | IOMMU | big lock | no | all-Rust | research | research |

## 4. Frontier / unsolved

1. **No verified x86 hypervisor configuration exists anywhere.** seL4's x86 proof excludes
   VT-x, and NOVA's is in progress. Muen proves absence of runtime errors, not isolation.
2. **No substrate has verified IOMMU/SMMU handling.** seL4 states this explicitly. Device DMA is
   the weakest link of every design, and driver VMs plus an IOMMU are an engineering mitigation, not a proof.
3. **Verified multicore.** seL4 SMP is unverified. The multikernel (static per-core partitioning) is
   the planned proof route (Q3/28). Designs that want proofs to apply should assume static core
   partitioning, not a shared scheduler across cores.
4. **Boot and firmware.** seL4 excludes kernel startup, and SMM, ME/PSP and UEFI are outside every TCB above.
   The best available mitigations are measured launch (TXT/SKINIT or DRTM, which NOVA supports) and
   minimal firmware (coreboot). Neither is proven.
5. **Microarchitectural channels.** Confidentiality proofs are about the abstract machine. seL4
   timing-channel work (time protection) is research. Static core and cache partitioning is the
   practical answer.
6. **Dynamic systems on a static, proof-friendly kernel.** LionsOS is static by design. Genode
   built its own kernel partly for kernel-memory management and scheduling. An agent fleet that spawns
   sandboxes on demand needs a verified-friendly story for creating compartments at runtime ("PD templates" in
   Microkit are early).
7. **Host-kernel removal on x86.** pKVM-on-x86 is not merged. TDX/SEV-SNP remove the host only
   from the guest's confidentiality TCB.
8. **Rust with std on seL4.** rust-sel4 is `no_std`-first, so an effect runtime that expects std
   needs a port onto Microkit's notified/protected event model.
9. **Rust verification of the substrate itself** (Atmosphere, Verus) is now practical at
   ~6 KLOC, but there is no isolation theorem, no binary proof, and no Linux-guest support yet.

## 5. Ranked recommendation for this project

**Rank (target substrate, by TCB credibility × fitness for servers + agent sandboxes):**

1. **seL4 (Microkit + libvmm + sDDF, rust-sel4)** is the **destination**. It has the only isolation theorem,
   the smallest kernel, a per-VM unprivileged VMM, and a static capability description (Microkit SDF /
   capDL) that is literally "explicitly granted typed channels". Use **aarch64 first**, where the
   integrity + confidentiality proofs and hyp mode are verified. Use x86_64 later, accepting
   functional correctness only and treating VT-x as unverified.
2. **KVM + Rust VMMs on a minimal NixOS host** is the **starting point** for x86 today. It is the only
   option here with production-grade Linux guests, VFIO, SMP and the Nix ecosystem. It has the largest TCB of the
   serious options, so the design work is to make its TCB *replaceable*, not to accept it.
   On aarch64, prefer **pKVM**: the host leaves the guest TCB, and Android ships it at scale.
3. **Muen** is the best *x86-native* small-TCB option if a static x86 partition must exist before
   seL4-x86 matures. It costs GPLv3, Ada/SPARK, and no dynamic compartments.
4. **NOVA**: small, x86 + ARM, concurrent verification in progress. Its ecosystem is thin
   (Hedron dormant, Genode moved off it). Watch BlueRock's proofs.
5. **Xen** is the proven disaggregated x86 design (Qubes, Edera). It is clearly behind 1/3/4 on TCB size and has no proofs.
   Pick it only if driver-domain disaggregation on x86 is needed *now* and KVM's host kernel is unacceptable.
6. **Genode/Sculpt**: the best *design reference* for session routing. Its default kernel is now
   unverified and its focus is the desktop. Borrow its routing model, not the platform.

**Realistic path ("start on X, design so we can move to Y"):**

* **Phase A (now, x86 + aarch64):** NixOS host trimmed to KVM + VFIO + virtio-vsock, with no network
  stack exposed to guests. One cloud-hypervisor or crosvm VMM per compartment, seccomp/landlock
  jailed, one process per device (crosvm model). Driver VMs (NIC, NVMe) behind VFIO + IOMMU serve
  vhost-user back-ends to client VMs, which is the sDDF driver/virtualiser/client split rendered on KVM.
  Native Rust (id_effect) components run as **kernel-less micro-VMs (Hyperlight-style)** or minimal
  unikernel guests, so the component ABI is already "a VM with only channels". On aarch64 hosts,
  enable pKVM protected VMs where the platform supports it.
* **Design invariants that make Phase B a re-target, not a rewrite:**
  - The system description is a *static manifest* of compartments, memory regions and typed
    channels, generated from Nix. Make it emit Microkit SDF/capDL as a second backend from day one.
  - Channels are shared-memory SPSC queues plus notifications (the sDDF protocol). On KVM, map them
    to ivshmem/vhost-user/vsock. On seL4 they become Microkit channels. No component may assume
    sockets, a filesystem or a shared clock unless granted as a channel.
  - The id_effect runtime gets a `no_std + alloc` "platform" layer with one event loop
    (notification → effect), so it can sit on rust-sel4's Microkit handler model.
  - Cores are allocated statically per compartment class (matches the seL4 multikernel proof route and
    limits side channels).
* **Phase B (aarch64 first, 2027):** seL4 Microkit + libvmm on aarch64 servers. Linux guests are
  multi-vCPU. Watch for IOMMU-isolated passthrough, because libvmm says ARM passthrough is not IOMMU-isolated today.
  Native Rust components become Microkit PDs.
* **Phase C (x86, gated):** move x86 nodes once libvmm has multi-vCPU x86 guests and PCIe passthrough
  (LionsOS target Q4'26 for passthrough). Re-evaluate if NOVA's proofs complete or pKVM-x86 merges first.
* **Gates to track:** AArch64 MCS proofs (Q3/27), multikernel proofs (Q3/28), LionsOS 0.5.0 (end
  2026), any IOMMU verification work, and Atmosphere/Verus gaining an isolation theorem.

## 6. Sources (all accessed 2026-11-27)

- seL4 verified configurations: https://docs.sel4.systems/projects/sel4/verified-configurations.html
- seL4 proofs overview: https://sel4.systems/Verification/proofs.html
- seL4 roadmap: https://sel4.systems/roadmap.html
- seL4 configurations: https://docs.sel4.systems/projects/sel4/configurations.html
- seL4 users: https://sel4.systems/use.html
- Klein et al. CACM 2010: https://cacm.acm.org/?p=30656 ; TS numbers: https://trustworthy.systems/projects/OLD/l4.verified/numbers
- Multicore seL4: https://trustworthy.systems/projects/OLD/multicore-sel4 ; multikernel slides: https://sel4.systems/Summit/2024/slides/multikernel-roadmap.pdf
- Microkit platforms: https://docs.sel4.systems/projects/microkit/platforms.html ; 2.4.0: https://docs.sel4.systems/releases/microkit/2.4.0.html
- libvmm: https://raw.githubusercontent.com/au-ts/libvmm/main/README.md
- LionsOS: https://lionsos.org ; status: https://lionsos.org/docs/status_and_roadmap/
- rust-sel4: https://docs.sel4.systems/projects/rust/supported-configurations.html , https://github.com/seL4/rust-sel4
- Genode: https://genode.org/news/2026 , https://genode.org/documentation/genode-foundations/ , https://phoronix.com/news/Sculpt-OS-26.10 , https://sel4.systems/Summit/2025/slides/sculpt-os.pdf
- NOVA: https://github.com/udosteinberg/nova , https://fosdem.org/schedule/event/fosdem-2025-5083-a-formal-specification-of-the-nova-microhypervisor , https://bluerock-io.github.io/formal-methods/tech_reports/towards-modular-specification-and-verification-of-concurrent-hypervisor-based-isolation.pdf
- Hedron: https://awesome.ecosyste.ms/projects/github.com%2Fcyberus-technology%2Fhedron ; Cyberus: https://cyberus-technology.de/en/cloud/cloud-hypervisor
- Muen: https://muen.sk/ , https://www.adacore.com/highlights/muen-project , https://ar5iv.arxiv.org/html/2001.10328
- Qubes FAQ: https://doc.qubes-os.org/en/latest/introduction/faq.html
- Xen: https://xenbits.xen.org/docs/unstable/SUPPORT.html , https://xenbits.xen.org/docs/latest/designs/launch/hyperlaunch.html , https://link.springer.com/content/pdf/10.1007/978-3-642-31540-4_23.pdf
- Edera: https://docs.edera.dev/technical-overview/architecture/overview/ , https://arxiv.org/abs/2501.04580 , https://www.edera.dev/stories/xen-vs-kvm-why-xen-offers-superior-security-in-virtualization
- Firecracker: https://www.amazon.science/blog/how-awss-firecracker-virtual-machines-work , https://css.csail.mit.edu/6.566/2023/readings/firecracker.pdf
- crosvm: https://crosvm.dev/book/architecture/overview.html
- cloud-hypervisor: https://github.com/cloud-hypervisor/cloud-hypervisor
- pKVM/AVF: https://source.android.com/docs/core/virtualization/architecture , https://docs.kernel.org/next/virt/kvm/arm/pkvm.html , https://android-developers.googleblog.com/2023/12/virtual-machines-as-core-android-primitive.html
- pKVM on Intel RFC: https://spinics.net/lists/kvm/msg307648.html , https://spinics.net/lists/kvm/msg317320.html
- Hyperlight: https://github.com/hyperlight-dev/hyperlight
- OpenHCL: https://techcommunity.microsoft.com/blog/windowsosplatform/openhcl-the-new-open-source-paravisor/4273172
- Atmosphere: https://mars-research.github.io/doc/2025-sosp-atmo.pdf
- Asterinas: https://www.usenix.org/conference/atc25/presentation/peng-yuke , https://arxiv.org/abs/2506.03876
- Hubris: https://hubris.oxide.computer ; Tock: https://www.tockos.org
- CHERI: https://cheriot.org/silicon/2026/03/04/cheriot-first-silicon.html , https://cheri.cst.cam.ac.uk/ , https://cheri-alliance.org/introducing-the-cheri-adoption-global-ecosystem-assessment-q1-2026/

### Confidence notes
- NOVA "17 KLOC / 15 hypercalls" and Xen "270k LOC" come from search-result summaries of the cited
  papers. I did not read them in the primary PDFs. Re-check them before quoting externally.
- KVM "~150k LOC" is from a vendor (Edera) blog.
- Microkit's platform page lists x86_64 boards and also says "x64 support is on the roadmap". It is inconsistent.
