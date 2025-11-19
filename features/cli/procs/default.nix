# procs - A modern replacement for ps written in Rust
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    procs
  ];
}
