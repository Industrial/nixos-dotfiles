# Colocated suite: n8n packages.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = {
        n8n = "n8n";
        nodejs_latest = "nodejs_latest";
        supabase-cli = "supabase-cli";
      };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "n8n" {
    systemPackages = assay.eq "${mod}.environment.systemPackages" ''[ "n8n" "nodejs_latest" "supabase-cli" ]'';
  }
