# nix-index and comma: "which package ships this binary?" and "run that binary once
# without installing it" (`, cowsay moo`). Both answer from a nix-index database.
#
# The database is the whole problem. Building it locally means `nix-index` walking every
# output in nixpkgs — hours of CPU, repeated on every host and again after every channel
# bump, to produce a file the community already publishes twice a day. So this feature
# consumes inputs.nix-index-database (pinned in flake.nix) and gets the prebuilt one from
# the binary cache instead.
#
# programs.nix-index.enable IS DELIBERATELY NOT SET HERE. The imported module already
# sets `programs.nix-index.enable = lib.mkDefault true` together with
# `programs.nix-index.package = lib.mkDefault <nix-index-with-db>`, both guarded by the
# single `programs.nix-index-database.enable` switch (default true). Leaving them alone is
# what keeps nix-locate — and the bash/zsh/fish command_not_found hooks that nixpkgs'
# programs.nix-index wires up — pointed at the prebuilt database via NIX_INDEX_DATABASE.
# Writing `enable = true` by hand would decouple it from that switch and, with
# nix-index-database off, would enable nix-index against the bare nixpkgs package and an
# empty database, next to a `programs.command-not-found` nixpkgs asserts is mutually
# exclusive with it. Verified against the locked rev (cee0f87) that the NixOS module
# creates no index-building unit of its own, so nothing here regenerates the database on
# the host; that cost only appears if you schedule `nix-index` yourself. Don't.
#
# Nushell — the login shell on these hosts — has no command_not_found integration in
# either module, so comma is the interactive path there and nix-locate the explicit one.
{inputs, ...}: {
  imports = [inputs.nix-index-database.nixosModules.nix-index];

  # Puts comma-with-db on the system: upstream's comma wrapped so NIX_INDEX_DATABASE
  # resolves to the prebuilt (small) database in the store.
  programs.nix-index-database.comma.enable = true;
}
