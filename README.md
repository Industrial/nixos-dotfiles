# NixOS Dotfiles (Linux and OSX)

My NixOS configuration. I have separated out all software into features and
avoided [HomeManager](https://github.com/nix-community/home-manager) to make it
more portable. The caveat is that you have to configure everything manually but
hey it's nix so that's pretty easy!

It configures a NixOS machine, an OSX machine and a Virtual Machine (using
[MicroVM](https://github.com/astro/microvm.nix)).

## Installation

```bash
git clone git@github.com:Industrial/nixos-dotfiles.git ~/.dotfiles
```

### Installation on OSX

```bash
bin/install-osx-nix
bin/install-osx-nix-flakes
bin/install-osx-nix-conf
```

## Update

Run one command to update your entire system.

### Update NixOS

```bash
bin/update-repositories
bin/update-nixos
```

### Update OSX

```bash
bin/update-repositories
bin/update-osx
```

### Update VM

```bash
C9_HOST=vm_test bin/vm/update
C9_HOST=vm_test bin/vm/stop
C9_HOST=vm_test bin/vm/delete
C9_HOST=vm_test bin/vm/start
```

## Clean

If you hit the limit of derivations or you are just very happy with what you've
got:

```bash
bin/delete-generations
```

## Development

```bash
bin/format
bin/lint
bin/check
bin/test
```

## Lab

I have several services configured to run locally on some hosts:

- Langhus:
  - Media:
    - Invidious (YouTube):
      - [http://0.0.0.0:4000]
  - Passwords:
    - Vaultwarden:
      - [http://0.0.0.0:7000]
  - Monitoring:
    - Grafana:
      - [http://0.0.0.0:9000]
    - Prometheus:
      - [http://0.0.0.0:9001]
      - [http://0.0.0.0:9002]
