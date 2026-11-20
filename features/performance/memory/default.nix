# Memory Management - OOM Protection and Configuration
# Prevents system freezes from memory exhaustion by:
# - Enabling systemd-oomd for proactive memory management
# - Configuring kernel OOM killer for faster, predictable behavior
# - Setting memory overcommit to allow normal operation
{...}: {
  systemd = {
    oomd = {
      enable = true;

      # Enable root slice for proactive memory management
      enableRootSlice = true;

      # Disable user slices - was killing login sessions at 80% memory pressure
      # Custom oomkiller service handles user-level OOM instead
      enableUserSlices = false;

      # Note: enableUserServices was renamed to enableUserSlices in newer NixOS
      # Both are enabled via enableUserSlices above

      # Configure memory pressure thresholds (only kill at 90%+ memory usage)
      # Default is too aggressive (~60-70%), so we raise it to 90%
      # This prevents killing processes during normal operation
      settings = {
        OOM = {
          DefaultMemoryPressureDurationSec = "2s";
          DefaultMemoryPressureLimit = "90%";
        };
      };
    };
  };

  # Compressed swap in RAM. With no swap at all, the only memory the kernel can reclaim under
  # pressure is file-backed pages, and those include the executable code of gnome-shell and
  # the browsers. They get evicted and re-read from disk over and over, which is what a
  # "frozen" desktop is. zram gives anonymous memory somewhere to go first. zstd fits 2-4x
  # into the same space; 25% of RAM caps how much it can take.
  #
  # systemd-oomd stays unaffected: only the root slice opts into oomd, and only by memory
  # pressure (ManagedOOMMemoryPressure), never by swap use (ManagedOOMSwap).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  boot = {
    kernel = {
      sysctl = {
        # Write back in small steady amounts instead of multi-gigabyte bursts. The ratio
        # defaults (20% / 10%) let ~12 GiB of dirty pages build up on a 61 GiB host before
        # writers are throttled. Parallel lld links filled that with gigabytes of output and
        # then flushed it all at once; every fsync() behind the flush (browser profiles,
        # dockerd, gnome-shell) stalled with it. Measured on drakkar 2026-11-20: I/O
        # pressure "full" up to 71% with 4.5 GiB dirty, memory never below 16 GiB available.
        # Setting the *_bytes knobs zeroes the *_ratio ones.
        "vm.dirty_bytes" = 536870912; # 512 MiB: writers are throttled from here
        "vm.dirty_background_bytes" = 134217728; # 128 MiB: background writeback starts here

        # Kill the allocating task instead of searching for best candidate
        "vm.oom_kill_allocating_task" = 1;

        # Allow overcommit (default behavior) - this is necessary for normal operation
        # Setting to 2 (no overcommit) causes legitimate processes to fail
        "vm.overcommit_memory" = 0;

        # Don't panic on OOM, just kill processes
        "vm.panic_on_oom" = 0;
      };
    };
  };
}
