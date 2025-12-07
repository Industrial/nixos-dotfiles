# Memory Management - OOM Protection and Configuration
# Prevents system freezes from memory exhaustion by:
# - Enabling systemd-oomd for proactive memory management
# - Configuring kernel OOM killer for faster, predictable behavior
# - Setting memory overcommit policies to prevent allocation beyond available memory
{...}: {
  systemd = {
    oomd = {
      enable = true;

      # Enable root slice for proactive memory management
      enableRootSlice = true;

      # Enable user slices for proactive memory management
      enableUserSlices = true;

      # Enable user services for proactive memory management
      enableUserServices = true;
    };
  };

  boot = {
    kernel = {
      sysctl = {
        # Kill the allocating task instead of searching for best candidate
        "vm.oom_kill_allocating_task" = 1;

        # Don't overcommit memory (safer, prevents allocation beyond available)
        "vm.overcommit_memory" = 2;

        # Only allow 50% overcommit when overcommit is enabled
        "vm.overcommit_ratio" = 50;

        # Don't panic on OOM, just kill processes
        "vm.panic_on_oom" = 0;
      };
    };
  };
}
