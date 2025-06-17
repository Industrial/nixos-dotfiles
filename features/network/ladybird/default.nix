{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      ladybird
    ];
  };
}
