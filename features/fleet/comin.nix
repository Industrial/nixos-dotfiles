# Pull-based convergence (comin) — each host fetches origin/main and activates
# itself, so a host that was offline for weeks self-heals on next boot instead
# of waiting for an operator to run `bin/fleet deploy`.
#
# Supersedes clause 3 of ADR-0001 ("Disable comin on all hosts"); see
# docs/adr/0002-comin-pull-convergence.md for why that decision was reversed.
#
# RACE WITH PUSH-DEPLOY — the hazard ADR-0001 cited, and how it is contained:
# comin only ever activates a commit that exists on origin/main, so a
# `bin/fleet deploy` from an uncommitted or unpushed working tree WILL be
# reverted at the next poll. Operator discipline is therefore:
#   * commit and push before deploying, or
#   * push to the per-host `testing-<hostname>` branch, which comin applies
#     with `switch-to-configuration test` — never written to the bootloader,
#     so it cannot strand a host across a reboot.
# Both hosts converge on the same closure in the common case, where comin's
# poll is a no-op rather than a fight.
#
# Comin is NOT in nixpkgs; the module comes from its own flake input (see
# flake.nix). The pre-ADR-0001 version of this feature lived at
# features/ci/comin and pointed the repository subdir at hosts/<hostname> for
# the old per-host-flake layout — wrong under the unified root flake, so that
# option is deliberately left unset at its default of ".".
{
  inputs,
  settings,
  ...
}: {
  imports = [inputs.comin.nixosModules.comin];

  services.comin = {
    enable = true;

    # Selects nixosConfigurations.<hostname> out of the root flake.
    hostname = settings.hostname;

    remotes = [
      {
        name = "origin";
        url = "https://github.com/Industrial/nixos-dotfiles.git";

        branches = {
          main = {
            name = "main";
            operation = "switch";
          };
          # `testing.name` defaults to testing-<hostname> and `operation` to
          # "test"; both defaults are what we want, so they stay implicit.
        };

        # Upstream default is 60s. 300s is gentler on the remote while still
        # converging a fleet-wide change within five minutes.
        poller.period = 300;
      }
    ];

    # Convergence telemetry: comin exports whether this host is up to date,
    # which is what makes "always automatically up to date" observable rather
    # than merely asserted. Scrapeable at <host>:4243 by the fleet
    # Prometheus. Firewall stays closed on the public interface — tailscale0 is
    # already a trustedInterface via features/security/tailscale.
    exporter = {
      port = 4243;
      openFirewall = false;
    };
  };
}
