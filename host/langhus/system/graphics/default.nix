{pkgs, ...}: {
  hardware.opengl.enable = true;
  hardware.opengl.extraPackages = with pkgs; [
    rocmPackages.clr
    rocmPackages.clr.icd
    rocmPackages.rocm-runtime
  ];
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true;

  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
  };

  environment.systemPackages = with pkgs; [
    rocmPackages.rocminfo
  ];

  services.xserver.videoDrivers = ["amdgpu"];
}
