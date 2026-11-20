# Colocated suite: memory pressure handling, evaluated against the real NixOS option tree.
#
# The claims are the ones that decide whether a heavy build freezes the desktop: there is
# swap to absorb anonymous memory, writeback is bounded in bytes rather than as a share of a
# 61 GiB host, and adding swap did not opt any slice into swap-based oomd kills.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;

  cfg = nixos.eval {modules = [./default.nix];};
  sysctl = cfg.boot.kernel.sysctl;
  rootSlice = cfg.systemd.slices."-".sliceConfig or {};
in
  assay.suite "memory" {
    zramEnabled = assay.eq cfg.zramSwap.enable true;
    zramIsZstd = assay.eq cfg.zramSwap.algorithm "zstd";
    zramCappedAtQuarter = assay.eq cfg.zramSwap.memoryPercent 25;

    # Bytes, not ratios: the ratio defaults scale with RAM and let ~12 GiB of dirty pages
    # pile up before writers are throttled.
    dirtyBytesBounded = assay.eq sysctl."vm.dirty_bytes" 536870912;
    dirtyBackgroundBytesBounded = assay.eq sysctl."vm.dirty_background_bytes" 134217728;
    noDirtyRatiosAlongside = assay.eq [(sysctl ? "vm.dirty_ratio") (sysctl ? "vm.dirty_background_ratio")] [false false];

    oomdEnabled = assay.eq cfg.systemd.oomd.enable true;
    # Login sessions were being killed when user slices were managed; they stay out.
    userSlicesUnmanaged = assay.eq cfg.systemd.oomd.enableUserSlices false;
    # The root slice is managed by memory pressure only. Swap-based kills would start firing
    # once zram fills, and nothing asked for that.
    rootSliceNotSwapManaged = assay.eq (rootSlice.ManagedOOMSwap or null) null;
    rootSliceByPressure = assay.eq (rootSlice.ManagedOOMMemoryPressure or null) "kill";

    killsAllocatingTask = assay.eq sysctl."vm.oom_kill_allocating_task" 1;
    heuristicOvercommit = assay.eq sysctl."vm.overcommit_memory" 0;
    noPanicOnOom = assay.eq sysctl."vm.panic_on_oom" 0;
  }
