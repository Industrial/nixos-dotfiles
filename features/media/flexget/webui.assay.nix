# Assay: the FlexGet Web UI bundle derivation (features/media/flexget/webui.nix).
#
# The derivation is called the way default.nix calls it (pkgs.callPackage, pkgs from the
# pinned nixpkgs) and projected to its attributes; the unpack and install commands are build
# scripts, so matching them as text is matching the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  inherit (nixos.evalSystem {modules = [];}) pkgs;
  drv = pkgs.callPackage ./webui.nix {};
in
  assay.suite "flexget-webui" {
    namesFlexgetWebui = assay.eq drv.pname "flexget-webui";
    pinsVersion = assay.eq drv.version "3.20.5";

    # The version appears in the wheel URL too, so the two must move together along with the
    # hash. A mismatched pair silently serves the wrong UI against the running flexget.
    urlMatchesVersion = assay.eq (lib.hasSuffix "/flexget-${drv.version}-py3-none-any.whl" drv.src.url) true;
    pinsWheelHash = assay.eq drv.src.outputHash "sha256-SU1zAi4HBgd5QOZVkhCyf2+K/nnQd/ZE9WrUMkYKf+0=";

    # The reason this derivation exists: nixpkgs' flexget builds from the GitHub tarball, where
    # ui/v2/dist is only a "run npm build yourself" stub. The PyPI wheel ships the real bundle,
    # so the unpack must target exactly that path.
    extractsOnlyTheUiBundle = assay.eq (lib.hasInfix "unzip -q $curSrc 'flexget/ui/v2/*' -d out" drv.unpackCmd) true;
    sourcesFromPypiWheel = assay.eq (lib.hasPrefix "https://files.pythonhosted.org/" drv.src.url) true;

    # services.flexget expects to find the bundle at this share path.
    installsToSharedWebui = assay.eq (lib.hasInfix "mv out/flexget/ui/v2 $out/share/webui" drv.installPhase) true;
    licenseIsMit = assay.eq drv.meta.license.spdxId "MIT";
  }
