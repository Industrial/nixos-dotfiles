# Assay — Nix claim algebra (authoring DSL).
# Claims are plain attrsets; the Rust runner evaluates them in isolation.
{
  suite = name: cases: {inherit name cases;};

  eq = expr: expected: {
    claim = "eq";
    inherit expr expected;
  };

  throws = expr: pattern: {
    claim = "throws";
    inherit expr pattern;
  };

  subset = expr: expected: {
    claim = "subset";
    inherit expr expected;
  };

  hasAttrs = expr: attrs: {
    claim = "hasAttrs";
    inherit expr attrs;
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
