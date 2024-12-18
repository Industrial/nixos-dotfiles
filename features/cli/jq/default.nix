# jq is a command-line JSON processor.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      jq
    ];
  };
}
