# Hyperfine benchmarks commands on the shell. It's the measurement tool for the
# shell-startup budget: `nu` with the full repo config measures 15 ms against
# `nu -n` at 8 ms (median of 5, drakkar, 2026-11-04), so CI gates the ratio
# (~4x) rather than a wall-clock, which flakes on shared runners.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    hyperfine
  ];
}
