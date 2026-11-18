# Re-export Industrial/assay claim DSL (pinned). Suites: `let assay = import ../lib/assay.nix;`
let
  src = builtins.fetchTarball {
    url = "https://github.com/Industrial/assay/archive/refs/tags/v0.3.0.tar.gz";
    sha256 = "1ydsv3slx8cc2ysrzpbbqw9jb6hkcy16dr4ykghylwn9fkha7qq0";
  };
in
  import (src + "/nix/assay/default.nix")
