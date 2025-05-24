# Tests for the assert.nix module
# Run with: nix-instantiate --eval -E 'import ./common/assert.test.nix'
{...}: let
  # Import the assertions module
  assertions = import ./assert.nix {};

  # Helper functions for testing
  testPass = name: result: expected:
    if result == expected
    then {
      inherit name;
      passed = true;
    }
    else {
      inherit name;
      passed = false;
      expected = expected;
      actual = result;
    };

  testFail = name: testFn: expectedError: let
    result = builtins.tryEval testFn;
  in
    if
      !result.success
      && (
        if builtins.typeOf expectedError == "string"
        then
          (
            builtins.hasAttr "error" result
            && builtins.isAttrs result.error
            && builtins.hasAttr "message" result.error
            && builtins.match expectedError result.error.message != null
          )
        else true
      )
    then {
      inherit name;
      passed = true;
    }
    else {
      inherit name;
      passed = false;
      expected = "should throw error matching: ${expectedError}";
      actual =
        if result.success
        then "no error"
        else if
          (
            builtins.hasAttr "error" result
            && builtins.isAttrs result.error
            && builtins.hasAttr "message" result.error
          )
        then result.error.message
        else if
          (
            builtins.hasAttr "error" result
            && builtins.isAttrs result.error
          )
        then "evaluation failed, error object present but no message attribute"
        else if (builtins.hasAttr "error" result)
        then "evaluation failed, error attribute is not an attrset"
        else "evaluation failed, no error attribute in result"; # Should ideally not be reached if !result.success
    };

  # Create and run a test suite
  createTestSuite = name: tests: {
    name = name;
    passed = builtins.all (test: test.passed) tests;
    results = tests;
  };

  # Format results for reporting
  formatResults = suite: let
    passedTests = builtins.filter (test: test.passed) suite.results;
    failedTests = builtins.filter (test: !test.passed) suite.results;

    passedCount = builtins.length passedTests;
    failedCount = builtins.length failedTests;
    totalCount = builtins.length suite.results;

    failureDetails =
      builtins.map (
        test: "  - ${test.name} FAILED:\n    Expected: ${builtins.toJSON test.expected}\n    Actual: ${builtins.toJSON test.actual}"
      )
      failedTests;

    status =
      if suite.passed
      then "PASSED"
      else "FAILED";
  in ''
    Test Suite: ${suite.name} - ${status}
    Results: ${toString passedCount}/${toString totalCount} tests passed

    ${
      if failedCount > 0
      then "Failed Tests:\n${builtins.concatStringsSep "\n" failureDetails}"
      else "All tests passed!"
    }
  '';

  # Tests for assertSupportedSystem
  systemTests = [
    (testPass "Valid Linux x86_64"
      (assertions.assertSupportedSystem "x86_64-linux")
      "x86_64-linux")

    (testPass "Valid Linux ARM"
      (assertions.assertSupportedSystem "aarch64-linux")
      "aarch64-linux")

    (testFail "Invalid System"
      (assertions.assertSupportedSystem "invalid-system")
      "Unsupported system")
  ];

  # Tests for assertNonEmptyString
  stringTests = [
    (testPass "Valid string"
      (assertions.assertNonEmptyString "hello")
      "hello")

    (testFail "Empty string"
      (assertions.assertNonEmptyString "")
      "Expected test to be a non-empty string")

    (testFail "Non-string value"
      (assertions.assertNonEmptyString 123)
      "Expected test to be a non-empty string")
  ];

  # Tests for assertMatches
  matchTests = [
    (testPass "Valid pattern match"
      (assertions.assertMatches "[0-9]+\\.[0-9]+" "24.11")
      "24.11")

    (testFail "Invalid pattern match"
      (assertions.assertMatches "[0-9]+\\.[0-9]+" "abc")
      "Expected version to match pattern")
  ];

  # Tests for assertIntInRange
  intTests = [
    (testPass "Valid int in range"
      (assertions.assertIntInRange 1 10 5)
      5)

    (testFail "Int below range"
      (assertions.assertIntInRange 1 10 0)
      "Expected count to be an integer between 1 and 10")

    (testFail "Int above range"
      (assertions.assertIntInRange 1 10 11)
      "Expected count to be an integer between 1 and 10")

    (testFail "Not an int"
      (assertions.assertIntInRange 1 10 "5")
      "Expected count to be an integer between 1 and 10")
  ];

  # Tests for assertListOfType
  listTests = [
    (testPass "Valid list of strings"
      (assertions.assertListOfType "string" ["a" "b" "c"])
      ["a" "b" "c"])

    (testFail "Mixed type list"
      (assertions.assertListOfType "string" ["a" 1 "c"])
      "Expected names to contain only items of type string")

    (testFail "Not a list"
      (assertions.assertListOfType "string" "abc")
      "Expected names to be a list")
  ];

  # Tests for assertHasAttrs
  attrTests = [
    (testPass "Valid attrs"
      (assertions.assertHasAttrs ["a" "b"] {
        a = 1;
        b = 2;
        c = 3;
      })
      {
        a = 1;
        b = 2;
        c = 3;
      })

    (testFail "Missing attrs"
      (assertions.assertHasAttrs ["a" "b"] {a = 1;})
      "Object config is missing required attributes: b")
  ];

  # Run all test suites
  allSuites = [
    (createTestSuite "assertSupportedSystem" systemTests)
    (createTestSuite "assertNonEmptyString" stringTests)
    (createTestSuite "assertMatches" matchTests)
    (createTestSuite "assertIntInRange" intTests)
    (createTestSuite "assertListOfType" listTests)
    (createTestSuite "assertHasAttrs" attrTests)
  ];

  # Format and display results
  results = builtins.map formatResults allSuites;
in {
  # Return overall test status and detailed results
  success = builtins.all (suite: suite.passed) allSuites;
  output = builtins.concatStringsSep "\n\n" results;

  # Test assertSupportedSystem
  testSupportedSystem = {
    expr = assertions.assertSupportedSystem "x86_64-linux";
    expected = "x86_64-linux";
  };

  testSupportedSystemAarch64 = {
    expr = assertions.assertSupportedSystem "aarch64-linux";
    expected = "aarch64-linux";
  };

  testSupportedSystemDarwin = {
    expr = assertions.assertSupportedSystem "x86_64-darwin";
    expected = "x86_64-darwin";
  };

  # Test assertNonEmptyString
  testValidNonEmptyString = {
    expr = assertions.assertNonEmptyString "hello";
    expected = "hello";
  };

  # Test assertMatches
  testValidPatternMatch = {
    expr = assertions.assertMatches "[0-9]+\\.[0-9]+" "24.11";
    expected = "24.11";
  };

  # Test assertIntInRange
  testValidIntInRange = {
    expr = assertions.assertIntInRange 1 10 5;
    expected = 5;
  };

  # Test assertListOfType
  testValidListOfType = {
    expr = assertions.assertListOfType "string" ["a" "b" "c"];
    expected = ["a" "b" "c"];
  };

  # Test assertHasAttrs
  testValidHasAttrs = {
    expr = assertions.assertHasAttrs ["a" "b"] {
      a = 1;
      b = 2;
      c = 3;
    };
    expected = {
      a = 1;
      b = 2;
      c = 3;
    };
  };

  # Test for tryEval - To verify assertions correctly throw errors when they should
  testErrorBehaviorSystem = {
    expr = builtins.tryEval (assertions.assertSupportedSystem "invalid-system");
    expected = {
      success = false;
      value = false;
    };
  };

  testErrorBehaviorEmptyString = {
    expr = builtins.tryEval (assertions.assertNonEmptyString "");
    expected = {
      success = false;
      value = false;
    };
  };

  testErrorBehaviorIntRange = {
    expr = builtins.tryEval (assertions.assertIntInRange 1 10 11);
    expected = {
      success = false;
      value = false;
    };
  };
}
