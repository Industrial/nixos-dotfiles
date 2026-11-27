# 02 — How cheap can one-compartment-per-program be?

Research date: 2026-11-27. Read-only research; nothing installed or run on hosts.
Question: one hardware-isolated compartment per program (owner's decision). What
does each compartment cost in RAM, start latency, density and I/O, and what
techniques bring that cost down?

Conventions: every number has a URL. Numbers marked **[derived]** are
arithmetic on cited numbers. Numbers marked **[assumption]** are inputs to the
model that this fleet has to measure for itself.

---

## 1. Bottom line

- **The VMM is not the cost; the guest OS is.** Firecracker's VMM costs about
  3 MB per VM (≤5 MiB by spec). A stock Kata+Firecracker sandbox costs **94 MB**
  for a 128 MB guest, because of the guest kernel, the `struct page` arrays,
  the agent and the base OS.
  ([NSDI'20](https://files.usenix.org/s3fs-public/cdn/nsdi20-paper-agache.pdf),
  [spec](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md),
  [RunD ATC'22](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf))
- **Four known techniques cut the guest cost to under 20 MB per compartment:**
  a condensed kernel, a pre-patched template or snapshot, a shared read-only
  rootfs through virtio-fs/DAX, and pooled cgroups. RunD measured **<20 MB**
  per sandbox and **2,500 sandboxes on a 384 GB node**
  ([RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf)).
- **Unikernels and no-OS guests get to single-digit MB and about 1 ms boots.**
  Unikraft needs <10 MB of RAM and boots in ~1 ms plus VMM time.
  ([Unikraft EuroSys'21](https://arxiv.org/pdf/2104.12721)). LightVM ran
  3.6 MB guests, booted them in 2.3 ms, and held up to 8,000 per host
  ([LightVM SOSP'17](https://www.cs.utexas.edu/~witchel/380L/papers/manco17sosp-lightvm.pdf)).
  Hyperlight creates a VM in 1–2 ms and calls into it in microseconds
  ([MS blog](https://opensource.microsoft.com/blog/2024/11/07/introducing-hyperlight-virtual-machine-based-security-for-functions-at-scale/)).
- **For a fleet of a few hundred programs per host, RAM stops being the
  constraint at about 20–40 MB per compartment.** The real costs then move to
  I/O path overhead, cross-compartment IPC latency, programs that fork/exec
  helpers, and side channels from whatever you share.
- **Sharing memory and keeping secrets apart pull against each other.** KSM
  across compartments must stay off. Firecracker's production guide says so,
  and Flush+Reload, Dedup Est Machina and Flip Feng Shui are why. Share only
  public, read-only, content-addressed bytes: the `/nix/store` and
  kernel/program text. Never share anonymous memory, and reseed every clone
  of a snapshot.

---

## 2. Technique table (measured numbers)

### 2.1 Compartment substrates

| Substrate | Per-instance memory | Start / restore | Density / throughput | I/O & syscall notes | Source |
|---|---|---|---|---|---|
| **Firecracker** (KVM, Rust VMM) | VMM ≤5 MiB (spec), ~3 MB measured, flat in guest size | ≤125 ms InstanceStart → guest `/sbin/init`; p99 146 ms pre-configured | 150 microVMs/s/host (and 100 concurrent boots: p99 153 ms) | 2020: net ~15 Gb/s vs 44 Gb/s host tap; block ~13k IOPS serial vs 340k HW; 4 kB read +49 µs p99 | [spec](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md), [NSDI'20](https://files.usenix.org/s3fs-public/cdn/nsdi20-paper-agache.pdf) |
| Boot-time breakdown (same paper) | compressed minimal kernel 4.0 MB vs Ubuntu 6.7 MB + 44 MB modules | serial console logging costs up to 70 ms; kernel decompression ~40 ms; a static NIC +20 ms; Ubuntu kernel +900 ms | — | — | [NSDI'20](https://files.usenix.org/s3fs-public/cdn/nsdi20-paper-agache.pdf) |
| **cloud-hypervisor** | ~13 MB VMM overhead (2020) | p99 158 ms | — | net 23 Gb/s (better virtio than FC in 2020) | [NSDI'20](https://files.usenix.org/s3fs-public/cdn/nsdi20-paper-agache.pdf) |
| QEMU (contrast) | ~131 MB VMM overhead | slower; needs BIOS (qboot saves ~20 ms) | — | best block path in 2020 | [NSDI'20](https://files.usenix.org/s3fs-public/cdn/nsdi20-paper-agache.pdf) |
| crosvm | no comparable published per-VM figure found; its design runs each virtio device in its own minijail'd process, so expect more host processes per VM | — | — | — | (qualitative; measure) |
| **Kata + Firecracker, stock** | **94 MB** overhead for a 128 MB sandbox (Kata+QEMU 168 MB); falls to 71 MB per VM at 1,000 VMs via mmap'd shared kernel text | Kata-FC: 47.6 s to start 200 concurrently (virtio-blk/dm bottleneck) | >1,000 × 128 MB sandboxes fill a 384 GB host | — | [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf) |
| **RunD** (Kata derivative, Alibaba prod) | **<20 MB per sandbox**, flat in guest size; −75% vs Kata-FC at 1,000 VMs | 88 ms to app; 200 sandboxes in 1 s | **>2,500 per 384 GB node**; >2,000/node in prod, ~4 B invocations/day | condensed kernel −16 MB RAM, −4 MB image; rootfs prep 207 ms → 0.2 ms | [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf), [Alibaba blog](https://www.alibabacloud.com/blog/599753) |
| **Lupine Linux** (Kconfig-specialised Linux + KML) | 21 MB footprint; 4 MB image | 23 ms boot | — | syscall latency 20 µs figure cited for comparison; KML removes mode switch | [Lupine EuroSys'20](https://people.cs.vt.edu/djwillia/papers/eurosys20-lupine.pdf), [repo](https://github.com/hckuo/Lupine-Linux) |
| **LightVM** (Xen, noxs toolstack) | 480 KB on disk, **3.6 MB running** (unikernel) | **2.3 ms** boot (fork/exec = 1 ms); suspend/resume 30/25 ms | **up to 8,000 VMs/host** | — | [LightVM SOSP'17](https://www.cs.utexas.edu/~witchel/380L/papers/manco17sosp-lightvm.pdf) |
| **Unikraft** | images ~1 MB; **<10 MB RAM** | ~1 ms guest boot + VMM time (3–40 ms total) | — | 1.7–2.7× app throughput vs Linux guest (nginx, SQLite, Redis) | [Unikraft EuroSys'21](https://arxiv.org/pdf/2104.12721) |
| **OSv** | as low as 11 MB | ~5 ms on Firecracker | — | Linux-ABI-ish, single process | [OSv README](https://github.com/cloudius-systems/osv) |
| **Hermit** (Rust unikernel) | (no published per-VM number found; expect unikernel class, measure) | — | — | ships `tokio-minimal`, `axum-example`, `vsock`, `miotcp` examples; mio lists `x86_64-unknown-hermit` as a target | [hermit-rs examples](https://github.com/hermit-os/hermit-rs/tree/main/examples), [mio Cargo.toml](https://github.com/tokio-rs/mio/blob/master/Cargo.toml) |
| Nanos | — | — | — | single process, **no fork/exec** by design | [NanoVMs](https://nanovms.com/dev/tutorials/refactoring-nginx-worker-processes-multi-threaded), [memfd post](https://nanovms.com/dev/tutorials/introducing-memfd_create-anonymous-files-for-nanos-unikernel) |
| MirageOS (OCaml, Solo5 hvt/spt) | small; no comparable recent figure found | — | — | OCaml only, not our stack | [mirage.io](https://mirage.io/docs/arm64) |
| Nabla (Solo5 unikernel as a process) | — | — | — | host attack surface = 7 syscalls via seccomp; not a hardware boundary | [summary](https://systemadminspro.com/unikernel-ibm-nabla-full-review/) |
| **Hyperlight** (no guest OS, function-call VM) | no kernel; guest = `no_std` Rust/C ELF, memory sized by config | **1–2 ms** VM create (vs >120 ms optimised traditional VM); 0.0009 s avg demo call; `snapshot()/restore()` resets state | — | typed host↔guest function calls only; no FS/net by default | [intro](https://opensource.microsoft.com/blog/2024/11/07/introducing-hyperlight-virtual-machine-based-security-for-functions-at-scale/), [0.9 ms](https://opensource.microsoft.com/blog/2025/02/11/hyperlight-creating-a-0-0009-second-micro-vm-execution-time/), [README](https://github.com/hyperlight-dev/hyperlight) |
| X-Containers (Xen PV, LibOS) | — | — | — | up to **27×** raw syscall throughput vs Docker (seccomp + Meltdown patch dropped) | [ASPLOS'19](https://dl.acm.org/doi/abs/10.1145/3297858.3304016) |
| Dune (process in VMX non-root) | process-level | process-level | process-level | syscall interception **25× cheaper than ptrace** | [OSDI'12](https://www.usenix.org/system/files/conference/osdi12/osdi12-final-117.pdf) |
| **gVisor** (contrast; *not* hardware isolation of the Sentry) | empty sandbox 23.7 MB vs runc 4.1 MB, so **~20 MB overhead** | ~same as runc (1.14 s vs 1.19 s, docker-driven) | — | syscall ns: runc 1,939; runsc-ptrace 38,219; runsc-kvm 763 (gVisor's own CSV); Systrap replaces ptrace | [density.csv](https://gvisor.dev/performance/density.csv), [startup.csv](https://gvisor.dev/performance/startup.csv), [syscall.csv](https://gvisor.dev/performance/syscall.csv), [Systrap](https://gvisor.dev/blog/2023/04/28/systrap-release/) |
| **seL4 protection domain** (the extreme) | kernel objects: TCB 2–4 KiB, each paging level 4 KiB (PML4/PDPT/PD/PT), so **~20–40 KiB per PD + program image** **[derived]** | PD creation = object retypes (µs class) | bounded by RAM for program images | IPC call **744–787 cycles** on Skylake/Haswell x86_64 (~0.2 µs) | [seL4 perf](https://sel4.systems/performance.html), [x86_64 constants.h](https://github.com/seL4/seL4/blob/master/libsel4/sel4_arch_include/x86_64/sel4/sel4_arch/constants.h) |

### 2.2 Start-latency reducers (snapshot / template / fork)

| Technique | Number | Source |
|---|---|---|
| Firecracker snapshot restore | "a few milliseconds"; memory file is `MAP_PRIVATE`-mapped so pages load on demand, or through a userfaultfd handler | [FaaSnap](https://www.sysnet.ucsd.edu/~voelker/pubs/faasnap-eurosys22.pdf), [FC page-fault doc](https://github.com/firecracker-microvm/firecracker/blob/main/docs/snapshotting/handling-page-faults-on-snapshot-resume.md) |
| Lazy restore penalty | function from snapshot runs **95% slower** than memory-resident (page-at-a-time faults) | [REAP ASPLOS'21](https://arxiv.org/abs/2101.09355) |
| REAP (record and prefetch working set) | cold start **3.7×** faster than baseline snapshots | [REAP](https://arxiv.org/abs/2101.09355) |
| FaaSnap | up to **3.5×** faster than REAP; only **3.5%** slower than page-cache-resident snapshots | [FaaSnap EuroSys'22](https://www.sysnet.ucsd.edu/~voelker/pubs/faasnap-eurosys22.pdf) |
| SEUSS (unikernel snapshots + page sharing) | deploy 100s of ms → **<10 ms**; **50,000 cached instances vs 3,000** with standard OS | [SEUSS EuroSys'20](https://www.cs.bu.edu/~jappavoo/Resources/Papers/seuss.pdf) |
| Catalyzer (init-less restore + `sfork`) | **<1 ms** best-case start | [Catalyzer ASPLOS'20](https://ipads.sjtu.edu.cn/_media/publications/catalyzer-asplos20.pdf) |
| Nephele (Xen unikernel cloning) | 8× faster instantiation; 3× more active VMs | [EuroSys'23](https://dl.acm.org/doi/abs/10.1145/3552326.3587454) |
| Kernel self-modification vs templates | 10,012 KB of kernel text/rodata touched, **7,928 KB modified during boot**, so template sharing is defeated unless the kernel image is **pre-patched** | [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf) |

### 2.3 Memory reducers

| Technique | What it saves | Number / granularity | Risk | Source |
|---|---|---|---|---|
| mmap'd shared guest kernel image | kernel text/rodata shared across VMs | Kata-FC 94 → 71 MB per VM at 1,000 VMs | text is public; KASLR leaks if shared | [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf) |
| Condensed kernel (Kconfig) | drop ACPI, ftrace, i2c, ceph, graphics, loop | −16 MB RAM, −4 MB image | none (less attack surface) | [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf), [NSDI'20](https://files.usenix.org/s3fs-public/cdn/nsdi20-paper-agache.pdf) |
| Template / snapshot clone (CoW of pre-booted image) | private pages only for what each clone dirties | RunD <20 MB per sandbox, flat in guest size (page tables sized by used memory) | identical RNG/keys/ASLR in every clone | [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf), [Brooker uniqueness](https://arxiv.org/abs/2102.12892) |
| virtio-fs + **DAX** | guest page cache bypassed; host page cache mapped into guest, so one copy of `/nix/store` serves all guests | removes duplicate page cache (virtio-blk duplicates host and guest cache) | Flush+Reload / page-cache attacks on shared file pages | [virtio-fs](https://virtio-fs.gitlab.io/), [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf) |
| virtio-mem | hot(un)plug guest RAM with no balloon fragmentation | **2 MiB** granularity on Linux guests | none special | [virtio-mem](https://virtio-mem.gitlab.io/), [VEE'21](https://dl.acm.org/doi/10.1145/3453933.3454010) |
| virtio-balloon free page reporting | guest reports freed pages, host discards them | pageblock-order chunks (see doc); no deflate step needed | small: reveals guest free-memory pattern to host only | [kernel doc](https://docs.kernel.org/mm/free_page_reporting.html), [VIRTIO 1.3 §5.5.6.7](https://docs.oasis-open.org/virtio/virtio/v1.3/virtio-v1.3.pdf) |
| **KSM** (content dedup of anonymous memory) | identical pages across guests | (savings workload-dependent; CPU cost of `ksmd` scanning) | **Do not use across trust boundaries**: Flush+Reload, Dedup Est Machina, Flip Feng Shui (Rowhammer onto deduped page), remote dedup attacks | [FC prod guide](https://github.com/firecracker-microvm/firecracker/blob/main/docs/prod-host-setup.md), [Flush+Reload](https://eprint.iacr.org/2013/448), [FFS](https://www.vusec.net/projects/flip-feng-shui/), [Dedup Est Machina](https://scholar.google.com/citations?user=3-cZTbwAAAAJ&hl=en), [NDSS'22](https://www.ndss-symposium.org/wp-content/uploads/2022-81-paper.pdf) |
| Pooled cgroups | host-side cost at 10k cgroups | PELT iteration ate **7.6%** of node CPU; global cgroup mutexes serialise creation | none | [RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf) |

### 2.4 Exit / IPC costs (what crossing a boundary costs)

| Crossing | Cost | Source |
|---|---|---|
| Syscall inside a guest | native (no VM exit) | architecture |
| KVM kernel-only exit (vmcall) | ~1,300–1,400 cycles (~0.4 µs at 3.4 GHz **[derived]**) | [Bonzini 2015 LKML](https://lists.openwall.net/linux-kernel/2015/04/24/118) |
| Exit that reaches a userspace VMM | reported as roughly +13,000 cycles on older hardware (~4 µs **[derived]**); this figure is unverified, so measure it with kvm-unit-tests `vmexit` | background: [QEMU "Micro-Optimizing KVM VM-Exits"](https://www.qemu.org/2019/11/15/micro-optimizing-kvm-vmexits/) |
| seL4 IPC call | 744–787 cycles x86_64 | [seL4 perf](https://sel4.systems/performance.html) |
| gVisor syscall (ptrace / KVM platform) | 38 µs / 0.76 µs | [syscall.csv](https://gvisor.dev/performance/syscall.csv) |
| virtio-vsock round trip | no trustworthy published µs figure found; Linux 6.12 cut its latency further | [Phoronix](https://phoronix.com/news/Linux-6.12-Faster-VirtIO-Vsock), [LPC'23 slides](https://lpc.events/event/17/contributions/1626/attachments/1334/2674/VSOCK_%20From%20Convenience%20to%20Performant%20VirtIO%20Communication.pdf) — **measure with `vsock_perf`** |

Two consequences follow. Once the work is inside a compartment, Rust/tokio code
pays nothing extra for its own syscalls. All of the overhead sits on the
**channels**. The design lever is therefore to keep device and channel
backends in the kernel (vhost-net, vhost-vsock) or on shared-memory rings
(vhost-user, virtqueue-style typed channels). An exit that bounces through a
userspace VMM per message costs ~10× more.

---

## 3. Tokio / id_effect on a unikernel: is it real?

- **Hermit: yes, for the network-service subset.** The hermit-rs tree ships
  `tokio-minimal`, `axum-example`, `vsock`, `miotcp`/`mioudp` and `tls`
  examples, and mio carries a `target_os = "hermit"` dependency gate and lists
  `x86_64-unknown-hermit` in its targets
  ([examples](https://github.com/hermit-os/hermit-rs/tree/main/examples),
  [mio Cargo.toml](https://github.com/tokio-rs/mio/blob/master/Cargo.toml)).
  The README says "Rust applications that use the Rust runtime and do not
  directly use OS services are able to run on Hermit without modifications"
  ([README](https://github.com/hermit-os/hermit-rs)).
  - Caveats to verify before committing: Hermit is a lower-tier rustc target
    (expect nightly / `build-std`); crates using `libc`/`nix` directly, `fork`,
    `/proc`, signals or `io_uring` will not build; there is no process model;
    and the filesystem is limited (initramfs, virtio-fs/FUSE exist as examples).
- **Unikraft** runs Linux-ABI ELFs in binary-compatibility mode, which is the
  route for foreign software that happens to be single-process
  ([Unikraft](https://arxiv.org/pdf/2104.12721)).
- **Hyperlight is not a tokio host.** Guests are `no_std` with typed function
  calls ([README](https://github.com/hyperlight-dev/hyperlight)). It fits
  **id_effect's wasm-portable core**: run pure effect interpreters, parsers and
  policy evaluators as Hyperlight or Hyperlight-Wasm guests, with the tokio
  edge kept in a microVM.
- **The id_effect split maps onto this directly.** The effect core is portable
  (wasm, so Hyperlight-Wasm or a unikernel), and the Layer that provides
  capabilities (net, fs, clock) is the only place that touches the
  compartment's devices. Each granted capability becomes a typed channel
  (vsock or a shared ring) to another compartment.

---

## 4. Estimate model

Per-compartment resident cost:

```
C = V (VMM process) + K (guest kernel private) + T (page tables + struct page ≈ 1.6% of *used* guest RAM)
    + R (runtime/init) + W (program working set) − S (bytes served from shared, read-only mappings)
Host capacity N ≈ (M_host − M_reserved) / C
```

(`struct page` is 64 B per 4 KiB page, which is the 1.6% **[derived]**. RunD
shows that with templates T scales with used RAM, not configured RAM.)

Inputs (cited, with assumptions marked):

| Tier | Technique | V | K+T+R | per-compartment C (W = 15 MB **[assumption]** for a typical tokio service) |
|---|---|---|---|---|
| T0 | Kata+FC stock (distro kernel, agent, base OS) | 3–5 | ~90 | **~110 MB** ([RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf)) |
| T1 | FC + minimal Lupine-class kernel + program as PID 1 + `/nix/store` via virtio-fs DAX | 3–5 | ~15–21 | **~35–40 MB** ([Lupine](https://people.cs.vt.edu/djwillia/papers/eurosys20-lupine.pdf), [NSDI'20](https://files.usenix.org/s3fs-public/cdn/nsdi20-paper-agache.pdf)) |
| T2 | T1 + pre-patched snapshot template, CoW clones, free page reporting | 3–5 | <20 total overhead (RunD) | **~30 MB** ([RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf)) |
| T3 | Unikernel (Hermit/Unikraft) on FC/Solo5 | 3–5 | 2–6 | **~15–20 MB** (W shrinks too: no libc/init duplication) ([Unikraft](https://arxiv.org/pdf/2104.12721), [LightVM](https://www.cs.utexas.edu/~witchel/380L/papers/manco17sosp-lightvm.pdf)) |
| T4 | Hyperlight sandbox for leaf functions | in-process | guest heap/stack only | **~W** (1–2 ms create) |
| T5 | seL4 PD | — | ~0.03 | **~W** ([seL4](https://sel4.systems/performance.html)) |

Density on a **64 GB host with 8 GB reserved for the host** (56 GB usable)
**[derived]**:

| Tier | C | N programs/host | at 256 GB (248 usable) |
|---|---|---|---|
| T0 | 110 MB | ~510 | ~2,250 |
| T1 | 38 MB | ~1,500 | ~6,500 |
| T2 | 30 MB | ~1,900 | ~8,300 |
| T3 | 18 MB | ~3,100 | ~13,800 |
| T5 | 15 MB | ~3,700 | ~16,500 |

Sanity check against published densities: RunD put 2,500 × 128 MB sandboxes
on 384 GB, and LightVM held 8,000 unikernel VMs per host. The model is
consistent with both.

**Reading the model:** at the scale this fleet runs (tens to a few hundred
programs per host), even T1 costs **~4–12 GB** for 100–300 programs. Past T1
the wins come from start latency (snapshots) and channel cost, not from RAM.
Beyond ~1,000 compartments per host the binding limits become host-side:
cgroup and scheduler overhead (7.6% CPU at 10k cgroups), concurrent-boot
storms, and vCPU threads. These are not RAM limits.

CPU per idle compartment: a tickless guest (`NO_HZ_IDLE`) with no busy-poll
costs near zero. Rate-limit guest timers and avoid `virtio` busy-poll modes for
idle services (**[assumption]**: measure with `perf kvm stat` per idle guest).

---

## 5. What breaks at one-per-program, and the fix

| Pattern | Why it breaks | Fix |
|---|---|---|
| **Shared libraries** | every VM maps its own copy of glibc/openssl and so on: N × text | serve `/nix/store` read-only through **virtio-fs DAX** (one host page-cache copy), or bake an EROFS image and mmap it shared. Static Rust binaries are best: one text copy shared via DAX |
| **IPC-heavy programs** (chatty RPC, pipelines) | each message is a channel crossing, µs-class exits instead of ns function calls | batch on shared-memory rings (vhost-user / virtqueue-style typed channels); co-locate tightly coupled stages **inside one program** (same trust) rather than splitting them; seL4-class IPC is the asymptote (~0.2 µs) |
| **fork/exec helpers** (git, ssh, sh -c, nix) | unikernels (Nanos, Hermit, OSv) have no fork | give such programs a **Linux microVM** (T1/T2); helpers run inside the same compartment. Unikernel only for helper-free programs |
| **Nix builders** | spawn hundreds of processes, need namespaces, big ephemeral FS, high write I/O | one **ephemeral microVM per build** (or per derivation): store via virtio-fs, output via virtio-blk scratch; snapshot-restore a pre-booted builder template. Accept T1 cost; it's transient |
| **Databases** | need durable flush, high IOPS, hugepages, large RAM; 2020 Firecracker had serial block I/O (13k IOPS) and no flush | dedicated VM with **vhost-user-blk / NVMe namespace passthrough**, hugepages, no balloon or KSM; one database per compartment, clients talk over a typed channel. Verify flush semantics of the chosen VMM before trusting durability |
| Programs needing `/proc`, ptrace, perf, eBPF | absent in unikernels | Linux microVM |
| Many tiny CLIs (one-shot) | 125 ms boot per invocation | snapshot restore (few ms) or Hyperlight (1–2 ms) for pure ones |

---

## 6. Risks from sharing (side channels)

1. **KSM / anonymous-memory dedup: forbid across compartments.** It enables
   cross-VM Flush+Reload
   ([eprint 2013/448](https://eprint.iacr.org/2013/448)), write-timing
   disclosure and Rowhammer-on-shared-page (Flip Feng Shui,
   [vusec](https://www.vusec.net/projects/flip-feng-shui/);
   [USENIX Sec'16](https://files.usenix.org/s3fs-public/cdn/sec16_paper_razavi.pdf)),
   and remote dedup attacks
   ([NDSS'22](https://www.ndss-symposium.org/wp-content/uploads/2022-81-paper.pdf)).
   Firecracker's production guide says disable it
   ([prod-host-setup](https://github.com/firecracker-microvm/firecracker/blob/main/docs/prod-host-setup.md)).
2. **DAX / shared page cache / shared kernel text** create the same
   Flush+Reload channel, but only over **public** bytes (the Nix store is
   public by construction). What leaks is *which* code and data pages another
   compartment touches, so require constant-time crypto (no secret-indexed
   tables in shared text). Never put secrets in a shared file, and keep
   per-compartment state (`/var`, keys) on private virtio-blk.
3. **Snapshot clones share RNG state, ASLR layout and keys.** Reseed at
   restore (VMGenID, or a host-pushed seed over the channel), never snapshot
   after key generation, and re-randomise where possible
   ([Brooker, "Restoring Uniqueness in MicroVM Snapshots"](https://arxiv.org/abs/2102.12892);
   FC snapshot doc "Snapshot security and uniqueness"
   [link](https://github.com/firecracker-microvm/firecracker/blob/main/docs/snapshotting/snapshot-support.md)).
   Pre-patched shared kernels also defeat per-VM KASLR (accepted trade-off;
   the kernel is not the secret).
4. **SMT**: Firecracker recommends disabling it when tenants must be separated
   ([prod-host-setup](https://github.com/firecracker-microvm/firecracker/blob/main/docs/prod-host-setup.md)).
   Alternatively use core scheduling so that only one compartment's vCPUs share
   a core. Disabling SMT costs a large share of host throughput, which is part
   of the "accept overhead / rent VPS" budget.
5. **Rowhammer**: ECC + TRR DIMMs (same guide).
6. **Swap**: disable it or encrypt it (same guide). Do not swap guest memory
   unencrypted.
7. **Free page reporting / balloon**: leaks only guest memory pressure to the
   host, which is trusted anyway. Acceptable.

---

## 7. Ranked recommendation

1. **Default substrate (all Rust/id_effect services and most foreign
   software):** a **Firecracker or cloud-hypervisor microVM** with:
   - a single condensed, **pre-patched** guest kernel shared across the host:
     virtio + vsock only, no modules, no ACPI or ftrace, `NO_HZ_IDLE`, quiet
     console;
   - the **program as PID 1**, with a tiny init that does reseed, mounts and
     exec;
   - its `/nix/store` closure over **virtio-fs DAX**, read-only;
   - private state on virtio-blk;
   - **boot from a per-program snapshot template** with REAP/FaaSnap-style
     working-set prefetch;
   - virtio-mem plus free page reporting for elasticity;
   - pooled cgroups.

   Target **~20–35 MB per compartment and single-digit-ms restore** (RunD
   proves <20 MB overhead in production at 2,000+ per node).
2. **Unikernel track for helper-free id_effect network services:** **Hermit**
   first (Rust-native, tokio and axum examples exist), Unikraft second. Target
   **~5–10 MB and ~1–5 ms**. Gate it per program on "no fork, no `/proc`, no
   raw `libc`". Keep the T1 microVM as the rollback.
3. **Hyperlight / Hyperlight-Wasm for sub-program compartments:** the
   wasm-portable id_effect core, untrusted parsers and policy evaluation. Costs
   1–2 ms to create, µs per call, and adds a second boundary inside a
   compartment.
4. **Heavy and odd workloads get bigger, still per-program VMs:**
   - Nix builders: ephemeral VM per build.
   - Databases: dedicated VM, vhost-user-blk/NVMe, hugepages, no balloon.
5. **seL4 (Microkit/LionsOS) is the long-term asymptote:** a protection domain
   is ~tens of KiB and IPC is ~750 cycles, but tokio/Linux software does not
   run there natively. Track it as research, not as the near-term substrate.
6. **Do not:**
   - enable KSM across compartments;
   - share any anonymous or secret-bearing memory;
   - treat gVisor as the compartment (no hardware boundary for the Sentry,
     ~20 MB anyway);
   - use QEMU-class VMMs (~131 MB each).

## 8. Measure first on this fleet

- Real W for id_effect/tokio services (RSS of static binaries).
- vsock round-trip latency and throughput with `tools/testing/vsock/vsock_perf`.
- Current Firecracker/cloud-hypervisor block IOPS with io_uring/async engines,
  and their flush semantics.
- Snapshot restore p50/p99 on local NVMe with and without UFFD prefetch.
- Idle CPU per guest.
- Hermit build of one real id_effect service.
