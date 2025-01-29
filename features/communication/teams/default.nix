{pkgs, ...}: {
  environment = {
    systemPackages =
      if pkgs.stdenv.isDarwin
      then with pkgs; [teams]
      else with pkgs; [teams-for-linux];
  };
}
