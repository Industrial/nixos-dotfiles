{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    jira-cli-go
  ];
}
