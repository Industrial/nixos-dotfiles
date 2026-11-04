# Nushell plugins: polars (dataframes), query (json/xml/sqlite/web), formats
# (ini/eml/plist/vcf). Each is built against one engine version and nushell
# refuses a mismatch, so they must come from the same nixpkgs as pkgs.nushell.
{
  settings,
  pkgs,
  ...
}: let
  # `plugin add` wants the plugin binary, not the store root.
  polars = "${pkgs.nushellPlugins.polars}/bin/nu_plugin_polars";
  query = "${pkgs.nushellPlugins.query}/bin/nu_plugin_query";
  formats = "${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats";

  nushellDir = "/home/${settings.username}/.config/nushell";
  registry = "${nushellDir}/plugin.msgpackz";
  stamp = "${nushellDir}/.plugin-registry.store-paths";
in {
  environment.systemPackages = with pkgs; [
    nushellPlugins.polars
    nushellPlugins.query
    nushellPlugins.formats
  ];

  # Being on PATH is not enough: a plugin is only callable once it sits in the
  # per-user registry at `$nu.plugin-path`, which is mutable state no derivation
  # can own. Register from store paths so the entries never name a collected
  # generation. Best-effort by design — a plugin that refuses to register must
  # not take the whole activation down with it.
  system.activationScripts.registerNushellPlugins = {
    text = ''
      if [ -d /home/${settings.username} ]; then
        # Created as the user so the registry they write lands in their own dir.
        ${pkgs.util-linux}/bin/runuser -u ${settings.username} -- \
          mkdir -p ${nushellDir} || true

        # The registry keys on absolute plugin path, so a version bump would
        # leave the old path behind as a dead entry. Rebuild from scratch when
        # our store paths move, and do nothing at all when they have not.
        want="${polars} ${query} ${formats}"
        if [ "$(cat ${stamp} 2>/dev/null || true)" != "$want" ]; then
          rm -f ${registry}
          registered=1
          for plugin in ${polars} ${query} ${formats}; do
            # `plugin add` writes the invoking user's registry, so it has to run
            # as them; --no-config-file keeps a broken config.nu out of the way.
            if ! ${pkgs.util-linux}/bin/runuser -u ${settings.username} -- \
              env HOME=/home/${settings.username} \
              ${pkgs.nushell}/bin/nu --no-config-file \
              --commands "plugin add --plugin-config '${registry}' '$plugin'"; then
              echo "registerNushellPlugins: could not register $plugin, skipping" >&2
              registered=0
            fi
          done
          # Only stamp a complete registry, so a partial run retries next switch.
          if [ "$registered" = 1 ]; then
            printf '%s' "$want" > ${stamp}
          fi
        fi

        chown -R ${settings.username}:users ${nushellDir} || true
      fi
    '';
  };
}
