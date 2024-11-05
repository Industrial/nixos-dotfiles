{settings, ...}: {
  # Coming automatically pulls from the remote repository and deploys to the
  # local machine.
  services.comin = {
    enable = true;
    flakeSubdirectory = "systems/nixos";
    hostname = "${settings.hostname}";
    remotes = [
      {
        name = "origin";
        url = "https://github.com/Industrial/nixos-dotfiles.git";
        branches = {
          main = {
            name = "main";
          };
        };
      }
    ];
  };
}
