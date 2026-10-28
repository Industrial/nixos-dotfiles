# Colocated suite: V-268158 — hashlimit rate limiting on exposed ports.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268158.nix {};
  cmds = mod.networking.firewall.extraCommands;
  has = pat: builtins.match pat cmds != null;
  lines = builtins.filter (l: builtins.isString l && builtins.match ".*ip46tables.*" l != null) (builtins.split "\n" cmds);
in
  assay.suite "stig-V-268158" {
    firewallEnabled = assay.eq mod.networking.firewall.enable true;
    threeRules = assay.eq (builtins.length lines) 3;

    # Uses the ip46tables helper so the rules apply to both address families; plain iptables
    # would leave IPv6 unlimited.
    coversBothAddressFamilies = assay.eq (builtins.all (l: builtins.match ".*ip46tables.*" l != null) lines) true;

    # The SSH byte limit is the disruptive one, and the reason this control is `full`.
    limitsSshBytes = assay.eq (has ".*dport 22 .*hashlimit-above 1000000b/second.*") true;
    limitsHttpConnections = assay.eq (has ".*dport 80 .*hashlimit-above 1000/minute.*") true;
    limitsHttpsConnections = assay.eq (has ".*dport 443 .*hashlimit-above 1000/minute.*") true;

    # Every rule jumps to the firewall's refuse chain, not ACCEPT — a rule that matched and
    # then accepted would be rate *measurement*, not limiting.
    allRulesRefuse = assay.eq (builtins.all (l: builtins.match ".*--jump nixos-fw-refuse.*" l != null) lines) true;
  }
