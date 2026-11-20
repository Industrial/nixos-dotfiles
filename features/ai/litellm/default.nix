{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      litellm
    ];
  };
}
