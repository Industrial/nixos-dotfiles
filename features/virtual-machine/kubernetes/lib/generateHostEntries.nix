{settings}: services:
builtins.concatStringsSep "\n" (map (
    service: "127.0.0.1 ${service}.${settings.hostname}"
  )
  services)
