# paperclipai CLI wrapper — pins the official npm package and runs via npx.
# https://www.npmjs.com/package/paperclipai
{
  writeShellApplication,
  nodejs_22,
}:
writeShellApplication {
  name = "paperclipai";
  runtimeInputs = [nodejs_22];
  text = ''
    # Embedded Postgres refuses administrative users — fail fast.
    if [[ "''${EUID:-$(id -u)}" -eq 0 ]]; then
      echo "paperclipai: do not run as root (embedded Postgres)" >&2
      exit 1
    fi
    exec npx --yes paperclipai@2026.817.0 "$@"
  '';
}
