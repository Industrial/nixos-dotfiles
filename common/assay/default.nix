# Assay — Nix claim algebra (authoring DSL).
# eq/subset/hasAttrs take real Nix values (suite eval computes them; runner compares JSON).
# throws/forces/module keep expr strings (must re-eval to observe failure / IFD).
{
  suite = name: cases: {inherit name cases;};

  eq = actual: expected: {
    claim = "eq";
    inherit actual expected;
  };

  throws = expr: pattern: {
    claim = "throws";
    inherit expr pattern;
  };

  subset = actual: expected: {
    claim = "subset";
    inherit actual expected;
  };

  hasAttrs = actual: attrs: {
    claim = "hasAttrs";
    inherit actual attrs;
  };

  snapshot = name: expr: {
    claim = "snapshot";
    inherit name expr;
  };

  module = args: {claim = "module";} // args;

  drv = args: {claim = "drv";} // args;

  forces = expr: paths: {
    claim = "forces";
    inherit expr paths;
  };
}
