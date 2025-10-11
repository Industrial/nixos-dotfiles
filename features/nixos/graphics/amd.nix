{...}: {
  hardware = {
    amdgpu = {
      opencl = {
        enable = true;
      };
      initrd = {
        enable = true;
      };
    };
  };
}
