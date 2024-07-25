{pkgs, ...}: {
  # https://configure.zsa.io/moonlander/layouts/ZRrJ7/latest/0

  hardware.keyboard.zsa.enable = true;

  environment.systemPackages = with pkgs; [
    wally-cli
  ];
}
