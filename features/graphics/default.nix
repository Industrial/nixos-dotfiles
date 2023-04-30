{pkgs, ...}: {
  hardware.opengl.enable = true;
  hardware.opengl.extraPackages = with pkgs; [
    rocm-opencl-icd
    rocm-opencl-runtime
    rocm-runtime
  ];
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true;

  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
  };

  environment.systemPackages = with pkgs; [
    rocminfo
  ];
}