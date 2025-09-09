{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    blender
    blender-addons
    python3Packages.bpy
  ];
}
