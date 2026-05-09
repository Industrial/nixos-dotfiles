# Zig programming language (compiler and stdlib)
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    zig
  ];
}
