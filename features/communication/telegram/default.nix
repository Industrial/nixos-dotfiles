{pkgs, ...}: {
  environment = {
    systemPackages =
      if pkgs.stdenv.isDarwin
      then with pkgs; []
      else with pkgs; [telegram-desktop];
  };
}
