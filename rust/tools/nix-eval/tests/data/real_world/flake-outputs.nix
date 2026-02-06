{
  packages.x86_64-linux.default = {
    pname = "my-package";
    version = "0.1.0";
  };
  devShells.x86_64-linux.default = {
    buildInputs = ["rustc" "cargo"];
  };
}
