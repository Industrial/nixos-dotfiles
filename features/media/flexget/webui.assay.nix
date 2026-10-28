# Colocated suite for features/media/flexget/webui.nix.
# String-level guards (repo pattern): identity, pinned wheel, and the extraction that is the
# whole point of this derivation.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./webui.nix;
  has = pat: builtins.match pat src != null;
in
  assay.suite "flexget-webui" {
    namesFlexgetWebui = assay.eq (has ".*pname = \"flexget-webui\";.*") true;
    pinsVersion = assay.eq (has ".*version = \"3\\.20\\.5\";.*") true;

    # The version appears in the wheel URL too, so the two must move together along with the
    # hash. A mismatched pair silently serves the wrong UI against the running flexget.
    urlMatchesVersion = assay.eq (has ".*flexget-3\\.20\\.5-py3-none-any\\.whl.*") true;
    pinsWheelHash = assay.eq (has ".*hash = \"sha256-SU1zAi4HBgd5QOZVkhCyf2\\+K/nnQd/ZE9WrUMkYKf\\+0=\";.*") true;

    # The reason this derivation exists: nixpkgs' flexget builds from the GitHub tarball, where
    # ui/v2/dist is only a "run npm build yourself" stub. The PyPI wheel ships the real bundle,
    # so the unpack must target exactly that path.
    extractsOnlyTheUiBundle = assay.eq (has ".*unzip -q .curSrc .flexget/ui/v2/.*") true;
    sourcesFromPypiWheel = assay.eq (has ".*files\\.pythonhosted\\.org.*") true;

    # services.flexget expects to find the bundle at this share path.
    installsToSharedWebui = assay.eq (has ".*mv out/flexget/ui/v2 \\$out/share/webui.*") true;
  }
