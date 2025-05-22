{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      bisq2
      bisq-desktop
    ];
  };
}
