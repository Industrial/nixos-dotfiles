{
  description = "Shim — use repository root flake (.#hostname)";
  inputs.root.url = "path:../..";
  outputs = {root, ...}: root.outputs;
}
