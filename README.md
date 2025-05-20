# NixOS Dotfiles

My NixOS configuration. I have separated out all software into features and
avoided [HomeManager](https://github.com/nix-community/home-manager) to make it
more portable. The caveat is that you have to configure everything manually but
hey it's nix so that's pretty easy!

## Installation

```bash
git clone git@github.com:Industrial/nixos-dotfiles.git ~/.dotfiles
```

## Update

```bash
bin/update/host/<n>
```

## Clean

If you hit the limit of derivations or you are just very happy with what you've
got:

```bash
bin/delete-generations
```

## Development

```bash
format
bin/test
commit
```

## Automated Flake Updates

The repository includes an automated GitHub Actions workflow that keeps all host flake lock files up-to-date. It runs weekly and creates pull requests with dependency updates. 

See [Flake Update Automation](docs/flake-update-automation.md) for details.

## Virtual Machines

I have an ongoing project to use
[MicroVM](https://astro.github.io/microvm.nix/intro.html) to run containerized
services in virtual machines (rather then say, docker containers or bare metal)
in order to provide a secure environment for the processes to run and to expose
them to the internet. The plan is to create a setup that works a bit like
QubesOS and have one VM run Tor and to run all network traffic of other VM's
through this one.

### Update VM

```bash
bin/vm/update <n>
bin/vm/stop <n>
bin/vm/delete <n>
bin/vm/start <n>
```
