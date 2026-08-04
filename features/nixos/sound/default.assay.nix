# Colocated suite: pipewire on, pulseaudio forced off, rtkit on.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      lib = (import <nixpkgs> {}).lib;
      pkgs = { pavucontrol = "pavucontrol"; pulsemixer = "pulsemixer"; };
    in import ${modFile} { inherit lib pkgs; })
  '';
in
  assay.suite "sound" {
    rtkit = assay.eq "${mod}.security.rtkit.enable" "true";
    pipewire = assay.eq "${mod}.services.pipewire.enable" "true";
    pulseForcedOff = assay.eq "${mod}.services.pulseaudio.enable.content" "false";
    packages = assay.eq "${mod}.environment.systemPackages" ''[ "pavucontrol" "pulsemixer" ]'';
  }
