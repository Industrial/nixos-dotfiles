# Homarr dashboard (official container image) — port 7575.
#
# Reverted from the vendored from-source build (nixpkgs PR #430235 packaging):
# its better-sqlite3 native module SIGABRTs under the bundled Node 24
# (`Statement::~Statement` -> `node::RemoveEnvironmentCleanupHook` assert),
# crash-looping homarr.service. The upstream OCI image is the supported
# runtime; data lives under /data/services/homarr/{data,appdata} as before.
#
# Declarative board: ./board.json declares apps + integrations (Prowlarr
# wired with its API key from ../api-keys.nix). A oneshot service copies the
# spec + reconciler into the container and runs them against
# /appdata/db/db.sqlite — same idempotent pattern as arr-wiring.nix. UI edits
# persist in that sqlite; `homarr-export` runs hourly, diffs the live board
# against board.json and refreshes it in the repo checkout (/data/dotfiles)
# so UI changes land on disk for git.
{pkgs, ...}: let
  name = "homarr";
  directoryPath = "/data/services/${name}";
  dotfilesRepo = "/data/dotfiles";
  featureDir = "${dotfilesRepo}/features/media/homarr";
in {
  virtualisation.oci-containers.containers.${name} = {
    image = "ghcr.io/homarr-labs/homarr:latest";
    ports = ["7575:7575"];
    environment = {
      SECRET_ENCRYPTION_KEY = "a203bd976170059a5b560b8ade34fcb4951f970f94792abefbafad1377610d28";
    };
    volumes = [
      "${directoryPath}/data:/data"
      "${directoryPath}/appdata:/appdata"
    ];
  };

  # Container data lives under the fleet-standard NFS-backed path.
  systemd.tmpfiles.rules = [
    "d ${directoryPath}/data 0770 homarr data - -"
    "d ${directoryPath}/appdata 0770 homarr data - -"
  ];

  # Push the declared board into the container's sqlite after start.
  # The reconciler is idempotent and never deletes undeclared items.
  systemd.services."${name}-sync" = {
    description = "Apply declarative board.json to homarr's database";
    after = ["${name}.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "homarr-board-sync" ''
        set -eu
        if [ ! -f "${featureDir}/board.json" ] || [ ! -f "${featureDir}/reconcile.js" ]; then
          echo "homarr-sync: ${featureDir} incomplete (is ${dotfilesRepo} cloned?); skipping" >&2
          exit 0
        fi
        install -m 0644 "${featureDir}/reconcile.js" /tmp/homarr-reconcile.js
        ${pkgs.podman}/bin/podman cp "${featureDir}/board.json" ${name}:/tmp/board.json
        ${pkgs.podman}/bin/podman cp /tmp/homarr-reconcile.js ${name}:/tmp/reconcile.js
        rm -f /tmp/homarr-reconcile.js
        ${pkgs.podman}/bin/podman exec ${name} node /tmp/reconcile.js /tmp/board.json
      '';
    };
  };

  # Export UI-made changes back into the repo so they can be committed.
  systemd.services."${name}-export" = {
    description = "Refresh git-tracked board.json from live homarr state";
    after = ["${name}.service"];
    startAt = "hourly";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "homarr-board-export" ''
        set -eu
        if [ ! -d "${dotfilesRepo}" ]; then exit 0; fi
        tmp="$(${pkgs.coreutils}/bin/mktemp /tmp/homarr-board.XXXXXX.json)"
        chmod 0644 "$tmp"
        ${pkgs.podman}/bin/podman cp "${featureDir}/export.js" ${name}:/tmp/export.js
        if ! ${pkgs.podman}/bin/podman exec ${name} node /tmp/export.js > "$tmp"; then
          rm -f "$tmp"; exit 0
        fi
        if [ ! -f "${featureDir}/board.json" ] || ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "${featureDir}/board.json"; then
          install -m 0664 "$tmp" "${featureDir}/board.json"
          echo "homarr-export: board changed, refreshed ${featureDir}/board.json"
        fi
        rm -f "$tmp"
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [7575];
}
