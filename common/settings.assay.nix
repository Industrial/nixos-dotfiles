# Assay suite for common/settings.nix — first-class Nix values.
let
  assay = import ./assay/default.nix;
  settings = import ./settings.nix {
    hostname = "testhost";
    username = "alice";
    version = "24.11";
  };
  settingsFile = toString ./settings.nix;
in
  assay.suite "settings" {
    hostname = assay.eq settings.settings.hostname "testhost";
    username = assay.eq settings.settings.username "alice";
    systemDefault = assay.eq settings.system "x86_64-linux";
    userdir = assay.eq settings.settings.userdir "/home/alice";
    useremail = assay.eq settings.settings.useremail "alice@x86_64-linux.local";
    useremailOverride =
      assay.eq
      (import ./settings.nix {
        hostname = "h";
        useremail = "a@example.org";
      }).settings.useremail "a@example.org";
    userfullnameOverride =
      assay.eq
      (import ./settings.nix {
        hostname = "h";
        userfullname = "Alice A";
      }).settings.userfullname "Alice A";
    emptyUseremailThrows = assay.throws "(import ${settingsFile} { hostname = \"h\"; useremail = \"\"; })" null;
    stateVersion = assay.eq settings.settings.stateVersion "24.11";

    emptyHostnameThrows = assay.throws "(import ${settingsFile} { hostname = \"\"; })" null;
    emptyUsernameThrows = assay.throws "(import ${settingsFile} { hostname = \"h\"; username = \"\"; })" null;
    badVersionThrows = assay.throws "(import ${settingsFile} { hostname = \"h\"; version = \"unstable\"; })" null;
    unsupportedSystemThrows = assay.throws "(import ${settingsFile} { system = \"i686-linux\"; hostname = \"h\"; })" null;
  }
