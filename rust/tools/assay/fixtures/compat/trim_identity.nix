{
  trim_identity = {
    expr = "builtins.replaceStrings [\" \"] [\"\"] \"  hi  \"";
    expected = "\"hi\"";
  };
}
