{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    deno
  ];
}
