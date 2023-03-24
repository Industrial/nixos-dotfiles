{pkgs, ...}: {
  hardware = {
    opengl = {
      enable = true;

      extraPackages = with pkgs; [
        rocm-opencl-icd
        rocm-opencl-runtime
        rocm-runtime
      ];

      driSupport = true;
      driSupport32Bit = true;
    };
  };

  environment = {
    variables = {
      AMD_VULKAN_ICD = "RADV";
    };
  };
}
