{...}: let
  # Basic assertion
  assertions = {
    equal = expected: actual: {
      assertion = actual == expected;
      message = "Expected ${toString expected}, got ${toString actual}";
    };
  };

  # Execute a single test
  runTest = test: {
    inherit (test) name;
    result = test.test {inherit assertions;};
  };

  # Public API
  public = {
    it = name: test: {
      inherit name test;
    };

    run = test: runTest test;

    inherit assertions;
  };
in
  public
