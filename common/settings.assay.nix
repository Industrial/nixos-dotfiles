# Assay suite for common/settings.nix (hostname/username/version validation).
# Use toString so relative imports inside settings.nix (./assert.nix) resolve on disk.
let
  assay = import ./assay/default.nix;
  settingsFile = toString ./settings.nix;
  settings = "(import ${settingsFile} { hostname = \"testhost\"; username = \"alice\"; version = \"24.11\"; })";
in
  assay.suite "settings" {
    hostname = assay.eq "${settings}.settings.hostname" "\"testhost\"";
    username = assay.eq "${settings}.settings.username" "\"alice\"";
    systemDefault = assay.eq "${settings}.system" "\"x86_64-linux\"";
    userdir = assay.eq "${settings}.settings.userdir" "\"/home/alice\"";
    useremail = assay.eq "${settings}.settings.useremail" "\"alice@x86_64-linux.local\"";
    stateVersion = assay.eq "${settings}.settings.stateVersion" "\"24.11\"";

    emptyHostnameThrows = assay.throws "(import ${settingsFile} { hostname = \"\"; })" null;
    emptyUsernameThrows = assay.throws "(import ${settingsFile} { hostname = \"h\"; username = \"\"; })" null;
    badVersionThrows = assay.throws "(import ${settingsFile} { hostname = \"h\"; version = \"unstable\"; })" null;
    unsupportedSystemThrows = assay.throws "(import ${settingsFile} { system = \"i686-linux\"; hostname = \"h\"; })" null;
  }
