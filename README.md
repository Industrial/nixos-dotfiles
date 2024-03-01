# NixOS Dotfiles (Linux and OSX)
My nixos configuration. Don't just run this. Configure it first.

## Installation
```bash
git clone git@github.com:Industrial/nixos-dotfiles.git ~/.dotfiles
```

### OSX
```bash
bin/osx-install-nix
bin/osx-install-nix-flakes
bin/osx-install-nix-conf
```

## Update
Run one command to update your entire system.

### NixOS
```bash
bin/update
```

### OSX
```bash
bin/osx-update
```

## Clean
If you hit the limit of derivations or you are just very happy with what you've got:

```bash
bin/collect-garbage
```

## Lab
I have several services configured to run locally on some hosts:
- Langhus:
  - Media:
    - Invidious (YouTube):
      - http://localhost:4000
    - Lemmy (Out of order):
      - http://localhost:4001
      - http://localhost:4002
  - Documents:
    - Cryptpad:
      - http://localhost:4020
  - Passwords:
    - Vaultwarden:
      - http://localhost:7000
  - Monitoring:
    - Grafana:
      - http://localhost:9000
    - Prometheus:
      - http://localhost:9001
      - http://localhost:9002

## TODO
- Tests
- Security
  - Keys
  - Scanner
  - Network
  - VPN
  - Honeypots