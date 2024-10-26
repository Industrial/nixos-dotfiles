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
bin/update-vm
bin/stop-vm
bin/delete-vm
bin/start-vm
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
      - [http://localhost:4000]
  - Documents:
    - Cryptpad:
      - [http://localhost:4020]
  - Passwords:
    - Vaultwarden:
      - [http://localhost:7000]
  - Monitoring:
    - Grafana:
      - [http://localhost:9000]
    - Prometheus:
      - [http://localhost:9001]
      - [http://localhost:9002]

## TODO

- Security
  - Configure keys using [SopsNIX](https://github.com/Mic92/sops-nix).
  - Firewall: All host operating systems (NixOS and OSX) should have Firewalls
    enabled that are closed by default.
- Virtual Machine Setup: I want to recreate an environment that works like
  QubesOS. One Virtual Machine for one task.
  - Firewall: This Virtial Machine acts only as a firewall. It just routes all
    traffic. Allows only traffic from configured virtual machines.
  - Tor Bridge: Connects to Tor through the firewall. Allows only traffic from
    configured virtual Machines.
  - I2PD Bridge: Same as the Tor Bridge but uses I2PD.
    - Check out Yggdrasil.
  - Monero: Monero wallet (CLI). Connects to the Tor Bridge.
