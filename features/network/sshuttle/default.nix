{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    sshuttle
  ];
}
