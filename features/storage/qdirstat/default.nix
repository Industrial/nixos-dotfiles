{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      qdirstat
    ];
  };
}
