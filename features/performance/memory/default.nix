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

      # Enable user slices for proactive memory management
      enableUserSlices = true;

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

  boot = {
    kernel = {
      sysctl = {
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
