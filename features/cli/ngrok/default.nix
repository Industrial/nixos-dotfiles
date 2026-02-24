# ngrok is a CLI for exposing local servers to the internet
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ngrok
  ];
}
