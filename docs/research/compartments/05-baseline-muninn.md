# 05 — Per-compartment baseline, measured on muninn

Measured 2026-11-27 for #420 (epic #419), with the guest kernel from #425. Everything
ran as the unprivileged user `tom`: no root, no KSM, no sysctl changes, and nothing
was installed on the host. Report 02 estimated these costs from papers. This report
replaces those estimates with numbers from this fleet.

## 1. Headline

| What | cloud-hypervisor 55.0 | Firecracker 1.17.0 |
|---|---|---|
| Cold boot, VMM spawn → first vsock message (p50 / p99) | **130 / 158 ms** | **71 / 87 ms** |
| … with KSPP `init_on_free=1` left on, 128 MiB guest | 168 / 223 ms | 105 / 119 ms |
| Host cost per idle cold-booted VM (PSS / MemAvailable drop) | **34 / 34 MB** | 37 MB RSS |
| … with `init_on_free=1` on, 128 MiB guest | 137 MB (the whole guest) | 136 MB |
| Snapshot-template clone, spawn → first vsock echo | 76 ms (32 MiB) / 128 ms (128 MiB) | **50–67 ms** |
| Host cost per template clone | = guest size (eager copy) | **5.2 MB PSS, 5.5 MB MemAvailable** |
| vsock round trip, 64 B, hybrid (p50 / p99) | **81–106 / 220–780 µs** | 212–226 / 390–412 µs |
| Density reached before the 75 % RAM guard (31 GiB host) | 480 VMs (34 MB each) | **2,500 clones** (5.5 MB each), still under the guard at 68 % |
| Idle CPU, whole fleet of VMs | 4.1 % of one core for 400 VMs | 12.8 % of one core for 2,500 |
| Content-identical 64 MiB read-only blob, 10 guests | virtio-blk: +55 MB per guest. **virtio-pmem + DAX: +8 MB per guest** (1.7 private + 64/10 shared) | — |

Five findings change the design:

1. **The VMM is cheap; touched guest memory is the cost.** cloud-hypervisor's own
   private memory is under 1 MB of anonymous memory plus 3.9 MB of binary text shared
   by every VM. The rest of the 34 MB is guest RAM the guest touched: the 12 MB
   kernel image, its `struct page` arrays and boot allocations, rounded up to 2 MiB
   huge pages.
2. **KSPP's `init_on_free=1` makes every compartment cost its whole RAM size.** The
   guest zeroes all of its free memory at boot ("clearing system memory may take
   some time"), which faults in every host page. It also costs 39 ms per 128 MiB of
   boot time. With `init_on_free=0` (and `init_on_alloc=1` still on), a 512 MiB guest
   costs the same 34–46 MB as a 32 MiB guest. This is the single largest lever, and it
   needs an owner decision (§7).
3. **Firecracker snapshot templates are the density tier.** Firecracker maps the
   snapshot's memory file `MAP_PRIVATE`, so every clone shares the template's pages
   until it writes to them: 5.5 MB per clone, first vsock echo at ~55 ms. With this
   build, cloud-hypervisor's file restore copies the whole memory file eagerly; the
   restored VM costs its full RAM size. Its lazy `memory_restore_mode=ondemand` needs
   userfaultfd, which fails as non-root (`vm.unprivileged_userfaultfd = 0`).
4. **Sharing read-only blobs through virtio-pmem + DAX works, and dm-verity breaks
   it.** Ten guests reading the same 64 MiB erofs image cost 8 MB each over the
   baseline through DAX, against 55 MB each through virtio-blk. dm-verity cannot pass
   DAX through: the same image behind dm-verity silently falls back to the guest
   page cache and costs 58 MB per guest. The synthesis's "per-closure verity image +
   DAX-shared public blobs" therefore needs the shared blobs' integrity to come from
   the host (§5.3).
5. **The hybrid vsock round trip is ~80–100 µs on cloud-hypervisor and ~215 µs on
   Firecracker**, because both proxy every message through the VMM's userspace. That is
   the "unverified" vsock figure from the synthesis, now pinned down. A chatty channel
   pays it on every message.

## 2. Setup

| Item | Value |
|---|---|
| Host | muninn: i7-10750H (6 cores, 12 threads, SMT on), 31.1 GiB RAM, zram swap (unused), host kernel 6.18.64, THP `always`, shmem THP `never`, KSM off (`/sys/kernel/mm/ksm/run` = 0) |
| User | `tom`, uid 1000. Not in the `kvm` group, but `/dev/kvm` is mode 0666, so tom can open it. |
| Guest kernel | `features/compartments/guest-kernel` (#425): Linux 6.18.64, `allnoconfig` + 126 checked options, no modules, lockdown=confidentiality, KASLR. vmlinux 16.9 MB (text 8.2 MB, data 1.9 MB, bss 1.4 MB), bzImage 3.2 MB. Builds in 46 s on drakkar. |
| Guest userspace | an initramfs (40 KiB) whose only file is `/init`: a 38 KB static musl C program. It connects to host CID 2, sends `HELLO` with its `CLOCK_BOOTTIME` and `sysinfo()`, echoes until EOF, then serves echo on vsock port 5000. Not id_effect (§6). |
| VMMs | cloud-hypervisor 55.0 from nixpkgs. Firecracker 1.17.0 as upstream's static release binary, because nixpkgs' build fails at this pin (`aws-lc-sys` wants a system AWS-LC). |
| vsock | **hybrid vsock** on both VMMs: a Unix socket on the host, with no `vhost-vsock` module involved. Guest-initiated connections land on `<socket>_<port>`; host-initiated ones send `CONNECT <port>\n`. |
| Guest shape | 1 vCPU, 128 MiB unless stated, `quiet`, no serial or console device. |
| Harness | throwaway shell plus one C host probe (`hv`), under `.tmp/b420/`, not kept. `hv` takes `CLOCK_MONOTONIC` before `posix_spawn` of the VMM and again when the guest's first line arrives on the listening socket. Memory is read from `/proc/<pid>/smaps_rollup` (PSS) and `/proc/meminfo` (MemAvailable). |

Artefacts were built on drakkar and realised on muninn by copying the derivations
(`nix copy --derivation`), because tom is not a trusted user on muninn, so unsigned
outputs cannot be copied. The output hashes on both hosts are identical.

## 3. Boot

### 3.1 Cold boot to the first vsock message (n = 20 per row)

| VMM | Guest RAM | Kernel cmdline | p50 | p90 | p99 | min | guest `CLOCK_BOOTTIME` at `/init` |
|---|---|---|---|---|---|---|---|
| cloud-hypervisor | 128 MiB | (KSPP defaults) | 168.0 | 197.2 | 223.0 | 158.1 | 117 ms |
| cloud-hypervisor | 128 MiB | `init_on_free=0` | 129.8 | 152.9 | 157.5 | 121.2 | 81 ms |
| cloud-hypervisor | 64 MiB | `init_on_free=0` | 135.2 | 157.2 | 161.6 | 125.8 | 69 ms |
| cloud-hypervisor | 32 MiB | `init_on_free=0` | 135.0 | 155.8 | 218.0 | 119.7 | 72 ms |
| cloud-hypervisor | 512 MiB | (KSPP defaults) | 313.1 | 339.2 | 375.3 | 289.8 | 254 ms |
| cloud-hypervisor | 512 MiB | `init_on_free=0` | 138.3 | 168.6 | 224.3 | 128.6 | 82 ms |
| Firecracker | 128 MiB | (KSPP defaults) | 105.2 | 114.5 | 118.7 | 99.7 | — |
| Firecracker | 128 MiB | `init_on_free=0` | 71.4 | 74.6 | 87.0 | 69.0 | 42 ms |
| Firecracker | 32 MiB | `init_on_free=0` | 71.2 | 79.9 | 82.1 | 68.1 | 42 ms |

All times are in ms. Rows marked `init_on_free=0` keep `init_on_alloc=1`.

Firecracker boots the same kernel about 40 ms faster than cloud-hypervisor at every
size. Its kernel reaches `/init` in 42 ms against 70–80 ms, because Firecracker's
virtio-mmio devices need no PCI enumeration (likely the main difference; not profiled on Firecracker). The VMM's
own share, from spawn to the guest's first instruction, is about 30 ms for Firecracker
and about 55 ms for cloud-hypervisor.

### 3.2 Where the guest kernel spends its time

From an `initcall_debug` run on cloud-hypervisor with 128 MiB, with the kernel log
shipped out over vsock (addresses resolved against `vmlinux`), out of 108 ms to
`/init`:

| Phase | ms |
|---|---|
| `mem auto-init: clearing system memory` (`init_on_free=1`) | 39 (scales with guest RAM) |
| `acpi_init` | 24 |
| `virtio_vsock_init` | 6.6 |
| `virtio_pci_driver_init` | 6.1 |
| `init_hw_perf_events` | 4.0 |
| `slab_late_init` | 3.6 |
| everything else | ~25 |

Firecracker skips most of the ACPI and PCI cost. With serial logging on, the boot
takes 600–800 ms, because the legacy console replays the log over a 115,200-baud
UART. Report 02's "serial console logging costs up to 70 ms" understates this for a
verbose kernel: measured boots must run `quiet` with no serial device.

## 4. Memory per VM

### 4.1 One idle cloud-hypervisor VM, 2 s after `HELLO`

| Guest RAM, cmdline | RSS | PSS | anon | file |
|---|---|---|---|---|
| 128 MiB, defaults | 138.8 MB | 136.6 | 131.9 | 4.7 |
| 128 MiB, `init_on_free=0` | 40.4 | 38.2 | 33.6 | 4.6 |
| 64 MiB, `init_on_free=0` | 40.5 | 38.3 | 33.6 | 4.7 |
| 32 MiB, `init_on_free=0` | 38.4 | 36.2 | 31.5 | 4.7 |
| 512 MiB, defaults | 532.1 | 529.9 | 525.1 | 4.7 |
| 512 MiB, `init_on_free=0` | 48.6 | 46.4 | 41.8 | 4.6 |
| 128 MiB, `init_on_free=0`, `shared=on` (4 KiB memfd pages) | 32.7 | — | 0.8 + 24.9 shmem | 6.9 |

Breakdown of the 128 MiB, `init_on_free=0` VM from `/proc/<pid>/smaps`:

| Mapping | RSS |
|---|---|
| guest RAM | 32.0 MB, all of it `AnonHugePages`: 16 × 2 MiB |
| cloud-hypervisor text | 3.9 MB, shared by every VM |
| libc | 1.4 MB, shared host-wide (PSS 9 kB) |
| other VMM anon (heap, stacks) | ~0.8 MB |
| threads | 6 |

With 4 KiB pages (`shared=on`, since shmem THP is `never`), the guest actually
touches **24.9 MB**. The guest's own view: 117 MB `totalram`, 107 MB free after boot,
17.6 MB "reserved" (the kernel image, memmap and page_ext). Most of the 25 MB is the
kernel image that the VMM copies in, plus boot-time allocations that were freed but
had already faulted the host page.

- `--memory thp=off` did **not** stop the 2 MiB rounding: the host's THP is `always`.
- `shared=on` avoids the rounding but adds 60–90 ms to boot (memfd faults).
- The cheaper fix is host THP `madvise`, which is an owner decision for the host.

Firecracker, 128 MiB with `init_on_free=0`: 37.4 MB RSS, 35.1 MB anon, 3 threads.

### 4.2 Snapshot and restore

cloud-hypervisor (`ch-remote pause` / `snapshot`, then `cloud-hypervisor --restore`),
all unprivileged:

| Guest RAM | pause | snapshot | snapshot size | restore → API up | resume | first echo after resume | restored VM PSS |
|---|---|---|---|---|---|---|---|
| 128 MiB | 10 ms | 111 ms | 129 MB (full RAM, not sparse) | 117 ms (n=5) | 9 ms | 0.9 ms | 137 MB |
| 32 MiB | 10 ms | 36 ms | 33 MB | 66 ms (n=5) | 9 ms | 0.8 ms | 38.7 MB |

- `prefault=on` made no difference (n=3).
- `memory_restore_mode=ondemand` failed with `Failed to create userfaultfd: Operation
  not permitted`.
- Restore copies the whole memory file into fresh anonymous memory. A restored VM
  therefore costs its full guest size, and it is no faster than a cold boot at
  128 MiB.

Firecracker (API socket, `PUT /snapshot/create` Full, then `PUT /snapshot/load` with
a `File` backend, `resume_vm: true`), template 128 MiB:

| Step | Value |
|---|---|
| pause / create | 22–107 ms / 123–129 ms; memory file 128 MiB, state 13.5 KB |
| clone: spawn → load done | 38–52 ms (n = 20) |
| clone: spawn → first vsock echo | 50–67 ms |
| clone PSS | 5.7 MB (n = 20; anon 5.2 MB private, the rest is shared template pages) |
| MemAvailable drop per clone | 7.0 MB at 20 clones, 5.5 MB marginal at 1,000–2,500 |

Each clone runs in its own directory with a relative vsock `uds_path`, so one
snapshot serves every clone. As report 02 warns, **every clone has the same RNG
state, KASLR offset and memory layout**. A clone has to be reseeded before it holds a
secret (§7).

### 4.3 Density (75 % RAM guard, KSM off)

The guard stopped each run when used memory + 1 GiB reached 75 % of MemTotal (24.4 of
32.6 GB). The baseline before the runs: 23–24 % used by the host's own load.

cloud-hypervisor, cold boot, 128 MiB, `init_on_free=0`:

| N | PSS per VM | MemAvailable drop per VM | used | idle CPU (all VMs, 10 s) | boot p50 / p99 |
|---|---|---|---|---|---|
| 10 | 34.1 MB | 34.4 MB | 25 % | 0.3 % | 117 / 184 ms |
| 50 | 33.7 | 34.2 | 29 % | 1.2 % | 116 / 184 |
| 100 | 33.7 | 35.4 | 34 % | 1.4 % | 121 / 184 |
| 200 | 33.6 | 35.2 | 45 % | 3.7 % | 120 / 184 |
| 300 | 33.4 | 34.5 | 55 % | 3.4 % | 120 / 240 |
| 400 | 32.2 | 34.4 | 66 % | 4.1 % | 125 / 265 |
| 480 | guard reached at 72 % used | | | | |

Firecracker, snapshot clones of one 128 MiB template:

| N | PSS per VM | MemAvailable drop per VM | used | idle CPU (all VMs) | first echo p50 |
|---|---|---|---|---|---|
| 10 | 5.8 MB | 20.8 MB (template's page cache counted here) | 25 % | 0.7 % | 2.7 ms after load |
| 100 | 5.2 | 9.7 | 27 % | 2.7 % | 2.7 |
| 500 | 5.2 | 9.6 | 39 % | 4.3 % | 2.7 |
| 1,000 | 5.2 | 5.8 | 42 % | 3.0 % | 2.6 |
| 1,500 | 5.2 | 6.0 | 52 % | 8.5 % | 2.6 |
| 2,000 | 5.2 | 5.9 | 60 % | 5.9 % | 2.6 |
| 2,500 | 4.9 | 5.7 | 68 % | 12.8 % | 2.6 |

The run stopped at the step list's end (2,500), not at the guard. The marginal cost
from 1,000 to 2,500 clones is 8.2 GB / 1,500 = **5.4 MB per clone**, including the
host kernel's own per-VM cost (KVM structures, EPT, page tables), which PSS leaves
out. Idle guests are tickless and cost almost nothing: 13 % of one core for 2,500.

Operational finding: muninn's STIG `maxlogins` (10) counts the logind sessions that
the VMs keep alive. VMs started from plain ssh sessions locked tom out of ssh at
~480 VMs ("There were too many logins for 'tom'"), until they were stopped. The
later runs start every VMM in its own `systemd-run --user --scope`, which avoids
this. `CompartmentSupervisor` must likewise run each VMM in its own unit, never in
a login session.

## 5. Sharing content-identical read-only blobs (the synthesis's idea)

A 64 MiB file in an uncompressed 4 KiB-block erofs image (`mkfs.erofs -b 4096`), the
same image file for every guest. Each guest mounts it and reads every byte before it
says `HELLO`. cloud-hypervisor, 256 MiB guests, `init_on_free=0`. The figures are per
VM, 2 s after `HELLO`:

| Path | n | PSS | private anon | shared file (PSS) | Δ vs no blob | blob read |
|---|---|---|---|---|---|---|
| no blob | 10 | 38.2 MB | 37.7 | 0.5 | — | — |
| virtio-blk (`readonly=on`) | 10 | 93.7 | 93.1 | 0.6 | **+55.4** | 47 ms |
| virtio-pmem, no DAX | 10 | 102.2 | 95.1 | 7.1 | +64.0 | 182 ms |
| **virtio-pmem + erofs `dax=always`** | 10 | **46.5** | 39.4 | 7.1 | **+8.2** | 113 ms |
| dm-verity on virtio-pmem, `dax=always` | 10 | 102.9 | 95.7 | 7.1 | +64.7 | 772 ms |
| virtio-pmem + DAX | 1 | 110.2 | 39.8 | 70.4 | +67.7 | 127 ms |

### 5.1 What this shows

- With DAX the blob costs one host page-cache copy (64 MiB) for all guests, plus
  ~1.7 MB of private memory per guest (guest page tables and the DAX mapping
  metadata). Per guest that is 64/N + 1.7 MB: 8.2 MB at N = 10, 2.3 MB at N = 100.
- Without DAX, every path costs a full private copy in each guest's page cache,
  whether it goes through virtio-blk or pmem.
- The saving at N = 10 is **47 MB per guest** against virtio-blk. Asymptotically it is
  the blob's whole size per guest.

### 5.2 Kernel requirements found on the way

virtio-pmem namespaces do not probe without `CONFIG_NVDIMM_PFN`. `namespace0.0`
probe returned -ENXIO and no `/dev/pmem0` appeared. The guest kernel now enables
`NVDIMM_PFN` and `NVDIMM_DAX`. Its build-time Kconfig check would not have caught
this, because the option was never requested.

### 5.3 dm-verity and DAX do not compose

dm-verity is not a DAX-capable device-mapper target. erofs logs that DAX is
unsupported and falls back to the page cache, so the verity-protected image costs a
private copy per guest. The read is also slow (772 ms), because every block is
hashed. Two consequences for the design:

- The **per-closure image** (small and private) can keep dm-verity on virtio-blk, as
  report 04 proposes.
- The **shared public blobs** cannot be verity-checked inside the guest and still be
  shared. Their integrity has to come from the host, which is already in the TCB for
  the VMM and the kernel image:
  - the host maps only files whose digest it has checked, for example store paths
    with a known NAR hash or fs-verity on the host's filesystem;
  - cloud-hypervisor maps them `discard_writes=on`, which is `MAP_PRIVATE`, so a guest
    write never reaches the shared copy.

  An erofs-level digest (composefs-style fs-verity digests in the metadata) would
  move that check back into the guest. That is a follow-up.
- The side channel is the one report 02 predicts: Flush+Reload on *public* pages. The
  blobs must therefore contain only public, content-addressed bytes.

## 6. Not measured, and why

- **Hermit unikernel.** Skipped as not quick. Hermit needs a nightly toolchain with
  `build-std` for `x86_64-unknown-hermit` plus the Hermit loader, and none of these
  is packaged in this flake. Its per-VM figure stays unverified, and the follow-up
  issue carries it. On this evidence, the Linux microVM floor is ~25 MB of touched
  guest RAM on a cold boot and ~5 MB for a template clone, so a unikernel has to beat
  the clone number, not the cold-boot one, to change the design.
- **id_effect hello service.** The guest program is a 38 KB static C probe, not an
  id_effect service, so W (the program's own working set) is ~0 here. A real tokio
  service adds its RSS on top of every row above.
- **crosvm.** Not packaged at this pin and not tried.
- **VM-exit cost.** `perf kvm stat` needs root on the host, so this is not measured.
  The vsock round trip bounds it from above: one round trip is at least four exits plus
  two VMM wake-ups, so ~60 µs minimum.
- **vhost-vsock (in-kernel) round trip.** Both VMMs implement only hybrid vsock, and
  measuring the in-kernel path needs QEMU or crosvm.
- **Snapshot restore under a userfaultfd handler.** Needs
  `vm.unprivileged_userfaultfd = 1`, or root.

## 7. Against report 02's estimates, and the synthesis's open numbers

| Report 02 / synthesis said | Measured on muninn |
|---|---|
| Firecracker VMM ~3 MB, cloud-hypervisor ~13 MB (2020) | cloud-hypervisor 55: <1 MB private anon + 3.9 MB shared text. Firecracker 1.17: 2.4 MB file-backed, 3 threads (its anon is not separable from guest RAM here, total 35 MB). Both are small next to touched guest RAM. |
| T1 minimal microVM, program as PID 1: **~35–40 MB** (W = 15 MB) | **34 MB** cold (CH), 37 MB (FC), with W ≈ 0. Add the program's W, so a real service lands at ~50 MB unless templated. The estimate holds only if `init_on_free=0`. With KSPP defaults the cost is the full guest size (137 MB at 128 MiB). |
| T2 snapshot template: **~30 MB** | **5.4 MB** marginal per Firecracker clone. Much better than estimated, because clones share the template's pages. With this build, cloud-hypervisor's file restore does not share and costs the full guest size. |
| Firecracker ≤125 ms to `/sbin/init`, CH p99 158 ms | FC **71 ms** p50 to first vsock message, CH **130 ms** p50 / 158 ms p99 (`init_on_free=0`). |
| Snapshot restore "a few ms" | FC clone: 38–52 ms from process spawn to loaded, ~55 ms to the first vsock echo. Most of that is the process start and the API round trips, not page loading. CH: 66–117 ms. |
| ~1,500 compartments on a 64 GB host (56 GB usable) at T1 | 56 GB / 34.4 MB ≈ **1,630** CH cold-booted VMs. 56 GB / 5.4 MB ≈ **10,000** FC clones. muninn itself held 480 cold VMs before the guard and 2,500 clones at 68 %. |
| vsock round trip: unverified | **CH hybrid 81–106 µs p50, 220–780 µs p99; FC hybrid 212–226 µs p50, ~400 µs p99** (64 B, 10,000 samples). |
| Per-VM Hermit, crosvm: unverified | still unverified (§6) |
| VM-exit cycles: unverified | still unverified. Upper bound from the vsock floor: ~60 µs per round trip. |
| Idle CPU per guest ~0 (assumption) | 0.005–0.01 % of a core per idle guest (4.1 % for 400 CH VMs, 12.8 % for 2,500 FC clones) |
| Shared read-only blobs via DAX save RAM: validate first | Validated: **+8 MB instead of +55 MB per guest** for a 64 MiB blob at N = 10. **dm-verity defeats DAX**, so shared blobs need host-side integrity. |
| Condensed kernel ≈ Firecracker's 4.0 MB compressed | bzImage 3.2 MB, vmlinux 16.9 MB (8.2 MB text), with ACPI and PCI kept for cloud-hypervisor. |

## 8. Decisions needed and follow-ups

1. **`init_on_free` (owner decision).** KSPP says on. On, it makes each compartment
   resident at its full RAM size and adds ~0.3 ms per MiB to boot. `init_on_alloc=1`
   stays on either way, so new allocations never see stale data. The recommendation is
   that the supervisor boots compartments with `init_on_free=0` and sizes guest RAM by
   need. The kernel's compiled default stays KSPP's.
2. **Firecracker templates as the default start path.** They give 5 MB and ~55 ms.
   Two prerequisites:
   - reseeding at restore, via VMGenID or a seed pushed over vsock before any secret
     is derived;
   - keeping templates free of keys.
3. **Shared blobs: host-verified, `MAP_PRIVATE`, DAX.** Per-closure images stay
   dm-verity on virtio-blk, and the two do not mix.
4. **Host THP `madvise` on compartment hosts** would stop the 2 MiB rounding of
   guest RAM (32 → 25 MB per cold VM).
5. **Each VMM in its own systemd unit or scope**, never in a login session (the
   `maxlogins` lock-out).
6. Still open: Hermit, crosvm, vhost-vsock, VM-exit cost, and a real id_effect
   service's W.

## Appendix: raw lines

Selected verbatim lines from the harness (`hv`) output:

```
# CH 128M init_on_free=0, guest-initiated vsock RTT
pid=136263 boot_ms_accept=208.33 boot_ms_hello=208.79 HELLO init_boottime_ns=95717898 send_boottime_ns=95984985 totalram_kb=117132 freeram_kb=106540
rtt_n=10000 rtt_us_p50=95.3 rtt_us_p90=139.1 rtt_us_p99=273.6 rtt_us_mean=106.6 rtt_us_min=65.7 rtt_us_max=7268.1
# CH host-initiated (CONNECT 5000)
first_echo_ms=0.82 tries=1 rtt_n=10000 rtt_us_p50=89.4 rtt_us_p90=128.9 rtt_us_p99=260.2 rtt_us_mean=108.4 rtt_us_min=62.1 rtt_us_max=10271.6
# FC 128M init_on_free=0
pid=137634 boot_ms_accept=78.03 boot_ms_hello=78.53 HELLO init_boottime_ns=41895213 ... totalram_kb=117132 freeram_kb=107760
rtt_n=10000 rtt_us_p50=211.9 rtt_us_p90=296.7 rtt_us_p99=401.1 rtt_us_mean=224.5 rtt_us_min=138.6 rtt_us_max=2794.7
# FC template clones
clone2 load_ms=43 to_first_echo_ms=56 | first_echo_ms=2.13 tries=1
clones=20 sum_pss_kb=114955 per_clone_pss_kb=5747 memavailable_drop_kb=139728 per_clone_drop_kb=6986
# CH snapshot, 128M
pause_ms=10 snapshot_ms=111 snapshot_dir=129M on_disk=129M files=config.json,memory-ranges,state.json,
default restore_to_api_ms=118 resume_ms=11 launch_to_rtt_done_ms=231 | first_echo_ms=0.90 ... | mem=138964 136937 132124 4809 4
ondemand: restore failed: 0: Error restoring VM 2: Memory manager error 6: Operation not permitted (os error 1)
# density
ch-N400 vms=400 alive=400 sum_pss_mb=12568 per_vm_pss_kb=32175 per_vm_rss_kb=39028 per_vm_anon_kb=32147 memavail_drop_mb=13456 per_vm_drop_kb=34447 used_pct=66 idle_cpu_pct_all_vms=4.10
fc-N2500 vms=2500 alive=2500 sum_pss_mb=12058 per_vm_pss_kb=4939 per_vm_rss_kb=13786 per_vm_anon_kb=4923 memavail_drop_mb=13827 per_vm_drop_kb=5663 used_pct=68 idle_cpu_pct_all_vms=12.80
# sharing, n=10
blk-nodax n=10 per_vm_pss_kb=93654 per_vm_anon_kb=93091 per_vm_pss_file_kb=559
pmem-dax n=10 per_vm_pss_kb=46468 per_vm_anon_kb=39372 per_vm_pss_file_kb=7092
verity-pmem-dax n=10 per_vm_pss_kb=102877 per_vm_anon_kb=95726 per_vm_pss_file_kb=7147
```

Measurements in §3–§4 used the guest kernel before `NVDIMM_PFN`/`NVDIMM_DAX` were
added (§5.2), which grew vmlinux by 10 KB. §5 used the final kernel.
