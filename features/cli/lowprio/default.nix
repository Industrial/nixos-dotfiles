# `lowprio <command>` runs a heavy job (a cargo build, a backtest) so that it slows itself
# down instead of freezing the desktop:
#
#   lowprio cargo build --release
#
# On drakkar, parallel `ld.lld` links of large Rust binaries saturated the NVMe and stalled
# every fsync() behind them, browsers and gnome-shell included (I/O pressure "full" up to
# 71%, 2026-11-20). The command runs in its own transient systemd scope:
#
#   - IOWeight / ionice best-effort 7: the desktop's I/O wins. Effective because
#     features/performance/hardware puts NVMe on BFQ, the scheduler that honours both.
#   - CPUWeight / nice 10: same for CPU.
#   - MemoryHigh 70%: past it the scope is throttled and reclaimed first, the job slows down.
#   - MemoryMax 85%: past it the kernel OOM-kills inside the scope only, before the
#     host-wide oomkiller (90%) has to pick a victim from the whole session.
#
# It also gives a Cargo workspace a NOCOW `target/` when there isn't one yet. Build output
# is rewritten constantly, and btrfs copy-on-write makes every rewrite a new extent. The flag
# only applies to files created after it is set, so an existing target/ needs recreating.
#
# The sccache cache directory gets the same flag through tmpfiles, below.
{
  lib,
  pkgs,
  settings,
  ...
}: let
  scopeProperties = [
    "IOWeight=10"
    "CPUWeight=20"
    "MemoryHigh=70%"
    "MemoryMax=85%"
  ];

  lowprio =
    (pkgs.writeShellApplication {
      name = "lowprio";
      runtimeInputs = [pkgs.systemd pkgs.util-linux pkgs.coreutils pkgs.e2fsprogs];
      text = ''
        if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
          echo "usage: lowprio <command> [args...]" >&2
          echo "Runs <command> in a systemd scope with low I/O and CPU priority and a memory cap." >&2
          exit 2
        fi

        # A fresh Cargo workspace gets a NOCOW target/. chattr fails harmlessly off btrfs.
        if [ -f Cargo.toml ] && [ ! -e target ]; then
          mkdir target
          chattr +C target 2>/dev/null || true
        fi

        exec systemd-run --user --scope --quiet --collect \
          ${lib.concatMapStringsSep " " (p: "--property=${lib.escapeShellArg p}") scopeProperties} \
          -- nice -n 10 ionice -c 2 -n 7 "$@"
      '';
    })
    .overrideAttrs (old: {
      passthru = (old.passthru or {}) // {inherit scopeProperties;};
    });

  sccacheDir = "${settings.userdir}/.cache/sccache";
in {
  environment.systemPackages = [lowprio];

  # NOCOW for sccache's cache when it exists. No `d` rule: tmpfiles would create any missing
  # parent as root, and ~/.cache must stay the user's. Like target/, only files written after
  # the flag is set are affected.
  systemd.tmpfiles.rules = [
    "h ${sccacheDir} - - - - +C"
  ];
}
