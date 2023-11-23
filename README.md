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