{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      monero-cli
      monero-gui
    ];
  };
}
