{
  system,
  hostname,
  username,
  version,
}: {
  inherit system username;
  settings = {
    inherit system hostname username;
    stateVersion = version;
    hostPlatform = {
      inherit system;
    };
    userdir = "/home/${username}";
    useremail = "${username}@${system}.local";
    userfullname = username;
  };
}
