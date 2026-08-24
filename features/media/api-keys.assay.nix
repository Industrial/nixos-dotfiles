# Colocated suite for features/media/api-keys.nix.
# Sensitive data: assertions cover shape and structure ONLY — values are never
# echoed into claims, messages, or snapshots.
let
  assay = import ./../../common/assay/default.nix;
  keys = import ./api-keys.nix;
  # builtins.attrNames returns names in alphabetical order.
  expectedApps = ["lidarr" "prowlarr" "radarr" "readarr" "sonarr" "whisparr"];
  plausibleKey = k: builtins.match "[0-9A-Za-z]{64}" k != null;
in
  assay.suite "media-api-keys" {
    exactAppSet = assay.eq (builtins.attrNames keys) expectedApps;
    allKeysWellFormed =
      assay.eq (builtins.all plausibleKey (builtins.attrValues keys)) true;
    noPlaceholderValues = assay.eq
      (builtins.all (v: v != "changeme" && v != "") (builtins.attrValues keys))
      true;
  }
