{
  system ? "x86_64-linux",
  hostname,
  username ? "tom",
  version ? "24.11",
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
