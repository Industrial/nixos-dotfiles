# V-268089 (CAT I) — NixOS must implement DoW-approved encryption to protect the
# confidentiality of remote access sessions.
#
# The published fix text does not evaluate:
#
#   services.openssh.setting.Ciphers = [ ... ];
#                      ^^^^^^^ singular
#
# There is no `setting` option — it is `settings`. Applied literally on a system using
# `nixpkgs.config.allowUnfree`-style strictness this is an "option does not exist" error; on a
# freeform submodule it would silently create a meaningless `setting` attribute and the CAT I
# control would appear applied while sshd kept its default cipher list. Corrected to
# `settings.Ciphers`.
#
# Trailing whitespace after "aes128-ctr" in the published list is also dropped.
#
# All three are counter-mode AES, which is what the requirement means by DoW-approved. This
# narrows sshd's default cipher list; every current OpenSSH client supports these.
{...}: {
  services.openssh.settings.Ciphers = [
    "aes256-ctr"
    "aes192-ctr"
    "aes128-ctr"
  ];
}
