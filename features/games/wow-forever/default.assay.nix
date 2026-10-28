# Colocated suite: wow-forever symlink helper.
#
# The module's whole contribution is one wrapped shell script, so the suite checks that the
# script is installed and that its body is read from the colocated file rather than inlined —
# an empty or missing bin/link-wow-forever would otherwise produce a script that silently does
# nothing.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    pkgs = {writeShellScriptBin = name: body: {inherit name body;};};
    settings = {};
  };
  script = builtins.head mod.environment.systemPackages;
in
  assay.suite "wow-forever" {
    installsOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;
    namesHelperScript = assay.eq script.name "link-wow-forever";

    # The body comes from bin/link-wow-forever; assert the file exists and is substantial.
    helperSourceExists = assay.eq (builtins.pathExists ./bin/link-wow-forever) true;
    helperBodyIsNotEmpty = assay.eq (builtins.stringLength script.body > 50) true;

    # Symlinking is deliberately manual (Wine prefix permissions, WoW path may not exist at
    # build time), so the module must NOT create activation-time links.
    createsNoActivationScript = assay.eq (mod ? system) false;
  }
