---
name: nixos-media-service-creation
description: Create proper NixOS service modules for media applications following Industrial NixOS dotfiles patterns.
---

# NixOS Media Service Creation Skill

## Overview
This skill covers creating proper NixOS service modules for media applications (Jellyfin, *arr suites, etc.) following established patterns in the Industrial NixOS dotfiles repository. Services are designed to be NFS-compatible and fully managed by NixOS without external state files.

## Prerequisites
- Familiarity with NixOS module system
- Understanding of the repository's feature structure (`features/media/`)
- Knowledge of how services are deployed via fleet/deploy-rs

## Step-by-Step Guide

### 1. Follow Existing Patterns
Always use an existing working service as a template (e.g., `features/media/jellyfin/default.nix`). Copy its exact structure and modify only the service-specific values.

### 2. Use NFS-Compatible Paths
**Critical**: All services must store data in `/data/services/${servicename}` to be accessible via NFS to Drakkar and Huginn.
- ✅ Correct: `directoryPath = "/data/services/${name}";`
- ❌ Incorrect: Avoid `/mnt/well/services` or other non-exported paths

### 3. Proper Service Structure
Follow this exact structure for all media services:

```nix
{pkgs, ...}: let
  name = "servicename";
  directoryPath = "/data/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      servicename  # or appropriate package name
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Service Description";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.servicename}/bin/servicename [service-specific-args]";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
    # tmpfiles MUST be inside systemd, not at top level
    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
      ];
    };
  };

  users = {
    users = {
      "${name}" = {
        isSystemUser = true;
        home = "/home/${name}";
        createHome = true;
        group = "${name}";
        extraGroups = ["data"];
      };
    };
    # groups MUST be inside users, not at top level
    groups = {
      "${name}" = {};
    };
  };
}
```

### 4. Service-Specific Considerations
- **Headless services**: For QBittorrent, use `qbittorrent-nox` package and adjust ExecStart accordingly
- **Node.js services**: For Homarr, include `nodejs-18_x` in systemPackages and use `npm start`
- **Service-specific arguments**: Research each service's required startup arguments (often `--nobrowser --data=${directoryPath}` for *arr suites)

### 5. Common Pitfalls to Avoid
- ❌ Placing `tmpfiles` at top level (must be inside `systemd = {`)
- ❌ Placing `groups` at top level (must be inside `users = {}`)
- ❌ Using non-NFS-compatible paths (`/mnt/well`, `/home`, etc.)
- ❌ Forgetting `Group = "data"` in serviceConfig (needed for NFS access)
- ❌ Incorrect package references (use `${pkgs.servicename}` not hardcoded paths)

### 6. Verification Steps
After creating/modifying a service module:
1. Check syntax: `nix eval --raw --json '(import ./path/to/module.nix {})'`
2. Validate with fleet: `bin/fleet check mimir`
3. Test build: `nix build .#mimir.config.system.build.toplevel --keep-going` (ignore warnings about overseaserr/grafana)
4. Confirm result symlink is created

### 7. Deployment
Once validated:
```bash
bin/fleet deploy mimir --dry-activate   # Always test first
bin/fleet deploy mimir                   # Actual deployment
```

## References
- See `features/media/jellyfin/default.nix` for the canonical template
- Refer to existing services in `features/media/` for service-specific details
- Check `hosts/mimir/configuration.nix` for how services are imported

## Troubleshooting
- If `nix flake check` shows only warnings about overseaserr/grafana, these are safe to ignore (configuration warnings, not build errors)
- If service fails to start, check `journalctl -u servicename` on the target host
- Verify NFS access: On Drakkar/Huginn, check if `/mnt/mimir/services/servicename` is accessible