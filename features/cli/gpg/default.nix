{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      gnupg
      pinentry-all
    ];
  };

  programs = {
    gnupg = {
      agent = {
        enable = true;
        enableBrowserSocket = true;
      };
    };
  };
}
