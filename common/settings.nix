{
  system ? "x86_64-linux",
  hostname,
  username ? "tom",
  version ? "24.11",
  # Git commit identity (features/programming/git) and the ssh-keygen comment
  # (features/cli/create-ssh-key). The defaults are placeholders — the email is built
  # from the username and the *system string* (`tom@x86_64-linux.local`), an address
  # that routes nowhere. lib/mk-host.nix passes the real one for fleet hosts.
  useremail ? null,
  userfullname ? null,
}: let
  assertions = import ./assert.nix;

  # Apply validations
  validSystem = assertions.assertSupportedSystem system;
  validHostname = assertions.assertNonEmptyString hostname;
  validUsername = assertions.assertNonEmptyString username;
  validVersion = assertions.assertMatches "[0-9]+\\.[0-9]+" version;
in {
  inherit system username;
  settings = {
    system = validSystem;
    hostname = validHostname;
    username = validUsername;
    stateVersion = validVersion;
    hostPlatform = {
      system = validSystem;
    };
    userdir = "/home/${validUsername}";
    useremail =
      if useremail == null
      then "${validUsername}@${validSystem}.local"
      else assertions.assertNonEmptyString useremail;
    userfullname =
      if userfullname == null
      then validUsername
      else assertions.assertNonEmptyString userfullname;
  };
}
