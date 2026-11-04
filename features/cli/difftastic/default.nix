# Difftastic is a structural diff that understands syntax; its binary is difft, not difftastic.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    difftastic
  ];
}
