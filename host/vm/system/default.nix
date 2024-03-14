{
  settings,
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.microvm.nixosModules.microvm

    # CLI
    ../../../features/system/cli/bat
    ../../../features/system/cli/btop
    ../../../features/system/cli/direnv
    ../../../features/system/cli/e2fsprogs
    ../../../features/system/cli/eza
    ../../../features/system/cli/fd
    ../../../features/system/cli/fish
    ../../../features/system/cli/fzf
    ../../../features/system/cli/gh
    ../../../features/system/cli/neofetch
    ../../../features/system/cli/p7zip
    ../../../features/system/cli/ranger
    ../../../features/system/cli/ripgrep
    ../../../features/system/cli/unrar
    ../../../features/system/cli/unzip

    # Nix
    ../../../features/system/nix/home-manager
    ../../../features/system/nix/shell

    # NixOS
    ../../../features/system/nixos/boot
    ../../../features/system/nixos/console
    ../../../features/system/nixos/fonts
    ../../../features/system/nixos/i18n
    ../../../features/system/nixos/nix
    ../../../features/system/nixos/networking
    ../../../features/system/nixos/security
    ../../../features/system/nixos/security/apparmor
    ../../../features/system/nixos/system
    ../../../features/system/nixos/time
    ../../../features/system/nixos/users
    ../../../features/system/nixos/window-manager

    {
      users.users.root.password = "";
      microvm = {
        volumes = [
          {
            mountPoint = "/var";
            image = "var.img";
            size = 256;
          }
        ];
        shares = [
          {
            # use "virtiofs" for MicroVMs that are started by systemd
            proto = "9p";
            tag = "ro-store";
            # a host's /nix/store will be picked up so that no
            # squashfs/erofs will be built for it.
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];

        hypervisor = "qemu";
        socket = "control.socket";
      };
    }
  ];
}
