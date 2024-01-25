{
  settings,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../../features/lab/hidden-service.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = settings.stateVersion;

  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  users.users.${settings.username} = {
    isNormalUser = true;
    initialPassword = "test";
    extraGroups = ["wheel"];
  };

  services.xserver.enable = false;

  networking.hostName = "vm";

  environment.systemPackages = with pkgs; [
    wget
    vim
  ];
}
