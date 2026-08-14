{
  config,
  lib,
  pkgs,
  ...
}: {
  # Performance environment configuration

  # Configure environment for performance
  environment = {
    # Set performance environment variables
    variables = {
      # Optimize Python performance
      "PYTHONUNBUFFERED" = "1";
      "PYTHONDONTWRITEBYTECODE" = "1";

      # Optimize Node.js performance
      "NODE_OPTIONS" = "--max-old-space-size=4096";

      # Optimize Java performance
      "JAVA_OPTS" = "-Xmx4g -Xms2g";

      # Do not set RUSTFLAGS=-C target-cpu=native system-wide: it breaks
      # reproducible Nix builds of crates with AVX512 code paths (e.g.
      # lean-ctx → rten-gemm: LLVM cannot select vpdpbusd.512 on Zen4).

      # Optimize Go performance
      "GOMAXPROCS" = "auto";

      # Optimize general performance
      # OMP_NUM_THREADS removed - OpenMP auto-detects threads, "auto" is invalid
      "MKL_NUM_THREADS" = "auto";
      "OPENBLAS_NUM_THREADS" = "auto";
      "VECLIB_MAXIMUM_THREADS" = "auto";
      "NUMEXPR_NUM_THREADS" = "auto";
    };
  };
}
