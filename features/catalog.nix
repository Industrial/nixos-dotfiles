# Feature catalog — every feature a host can switch on.
#
# The list is generated (GH-417 S2): the source of truth is the typed Voltaic catalog in
# rust/tools/vfleet/src/catalog.vlt (a closed set of categories). vfleet checks it (no
# entry twice, no two entries for one option, plain relative paths) and writes
# ./catalog.json, the entries' paths below features/ in order; this file turns them into
# paths. Adding a feature: add it to catalog.vlt, run `bin/fleet-data`, commit both,
# then enable it from a profile or host.
#
# lib/mk-host.nix wraps each entry with lib/features.nix and imports the lot into
# every host, which declares `features.<category>.<name>.enable` (default false)
# for each. Profiles and hosts then turn features on by option instead of by
# import, and turn them off with `lib.mkForce false` instead of commenting
# lines out.
#
# Option name = path below features/, minus `.nix` / `/default.nix`:
#   fleet/comin.nix              -> features.fleet.comin.enable
#   nixos/graphics/amd.nix       -> features.nixos.graphics.amd.enable
#
# Features that another feature imports (claude-code's ../lean-ctx, remote-access's
# ../network/ssh) are reached through that import and need no entry here; enabling
# the parent enables them with mkDefault.
#
# Features left out (openhands, mullvad, the mimir media stack, ...) are not
# evaluated on any host — their enables in hosts/ and profiles/ stay commented
# out until they are listed in catalog.vlt.
map (p: ./. + "/${p}") (builtins.fromJSON (builtins.readFile ./catalog.json))
