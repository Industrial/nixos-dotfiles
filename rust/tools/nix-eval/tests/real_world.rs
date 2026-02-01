//! Real-world Nix expression tests
//!
//! These tests use actual Nix expressions from real-world use cases,
//! including nixpkgs-style package definitions, NixOS configurations,
//! and flake outputs.

use nix_eval::{Evaluator, NixValue};

mod package_definitions {
    use super::*;

    #[test]
    fn test_simple_package() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          pname = "hello";
          version = "2.12";
          src = null;
          buildInputs = [];
          nativeBuildInputs = [];
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(attrs) => {
                // Attribute values are thunks, need to force them
                let pname_value = attrs
                    .get("pname")
                    .unwrap()
                    .clone()
                    .force(&evaluator)
                    .unwrap();
                let version_value = attrs
                    .get("version")
                    .unwrap()
                    .clone()
                    .force(&evaluator)
                    .unwrap();
                assert_eq!(pname_value, NixValue::String("hello".to_string()));
                assert_eq!(version_value, NixValue::String("2.12".to_string()));
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_package_with_dependencies() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          pname = "my-package";
          version = "1.0.0";
          buildInputs = ["dep1" "dep2" "dep3"];
          propagatedBuildInputs = ["runtime-dep"];
          checkInputs = ["test-framework"];
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(attrs) => {
                // Attribute values are thunks, need to force them
                let pname_value = attrs
                    .get("pname")
                    .unwrap()
                    .clone()
                    .force(&evaluator)
                    .unwrap();
                assert_eq!(pname_value, NixValue::String("my-package".to_string()));

                // Check that buildInputs is a list
                let build_inputs_value = attrs
                    .get("buildInputs")
                    .unwrap()
                    .clone()
                    .force(&evaluator)
                    .unwrap();
                match build_inputs_value {
                    NixValue::List(items) => {
                        assert_eq!(items.len(), 3);
                    }
                    _ => panic!("Expected buildInputs to be a List"),
                }
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_package_meta() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          meta = {
            description = "A test package";
            homepage = "https://example.com";
            license = null;
            platforms = ["x86_64-linux" "aarch64-linux"];
            maintainers = [];
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(attrs) => {
                // Attribute values are thunks, need to force them
                let meta_value = attrs
                    .get("meta")
                    .unwrap()
                    .clone()
                    .force(&evaluator)
                    .unwrap();
                match meta_value {
                    NixValue::AttributeSet(meta) => {
                        // Inner attribute set values are also thunks
                        let description_value = meta
                            .get("description")
                            .unwrap()
                            .clone()
                            .force(&evaluator)
                            .unwrap();
                        assert_eq!(
                            description_value,
                            NixValue::String("A test package".to_string())
                        );
                    }
                    _ => panic!("Expected meta to be an AttributeSet"),
                }
            }
            _ => panic!("Expected AttributeSet"),
        }
    }
}

mod nixos_configurations {
    use super::*;

    #[test]
    fn test_service_configuration() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          services.nginx = {
            enable = true;
            virtualHosts."example.com" = {
              root = "/var/www";
              locations."/" = {
                proxyPass = "http://localhost:3000";
              };
            };
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(_) => {
                // Just verify it evaluates successfully
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_user_configuration() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          users.users.alice = {
            isNormalUser = true;
            extraGroups = ["wheel" "docker"];
            openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2E..."
            ];
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(_) => {
                // Verify it evaluates
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_networking_configuration() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          networking = {
            hostName = "myserver";
            interfaces.eth0 = {
              ipv4.addresses = [
                { address = "192.168.1.100"; prefixLength = 24; }
              ];
            };
            firewall = {
              enable = true;
              allowedTCPPorts = [22 80 443];
            };
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(_) => {
                // Verify it evaluates
            }
            _ => panic!("Expected AttributeSet"),
        }
    }
}

mod flake_outputs {
    use super::*;

    #[test]
    fn test_flake_packages() {
        let evaluator = Evaluator::new();
        // Note: Dot notation in attribute paths (packages.x86_64-linux.default) creates
        // a single key with the full path as the identifier. Until nested attribute path
        // support is added, we test with nested attribute sets instead.
        let expr = r#"
        {
          packages = {
            x86_64-linux = {
              default = {
                pname = "my-flake-package";
                version = "0.1.0";
              };
            };
            aarch64-linux = {
              default = {
                pname = "my-flake-package";
                version = "0.1.0";
              };
            };
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(top_level) => {
                // Check for "packages" key
                assert!(top_level.contains_key("packages"));
                // Force the packages value to check nested structure
                let packages_value = top_level
                    .get("packages")
                    .unwrap()
                    .clone()
                    .force(&evaluator)
                    .unwrap();
                match packages_value {
                    NixValue::AttributeSet(packages) => {
                        assert!(packages.contains_key("x86_64-linux"));
                        assert!(packages.contains_key("aarch64-linux"));
                    }
                    _ => panic!("Expected packages to be an AttributeSet"),
                }
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_flake_devshells() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          devShells.x86_64-linux.default = {
            buildInputs = ["rustc" "cargo" "clippy"];
            shellHook = "";
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(_) => {
                // Verify it evaluates
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_flake_outputs_structure() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          outputs = {
            packages = {
              x86_64-linux = {
                default = { name = "package"; };
              };
            };
            devShells = {
              x86_64-linux = {
                default = { buildInputs = []; };
              };
            };
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(_) => {
                // Verify it evaluates
            }
            _ => panic!("Expected AttributeSet"),
        }
    }
}

mod complex_nested {
    use super::*;

    #[test]
    fn test_deeply_nested_structure() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          level1 = {
            level2 = {
              level3 = {
                level4 = {
                  value = 42;
                };
              };
            };
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(_) => {
                // Verify it evaluates
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_mixed_nested_structures() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          config = {
            services = {
              web = {
                ports = [80 443];
                hosts = ["example.com" "www.example.com"];
              };
            };
            database = {
              connections = [
                { host = "localhost"; port = 5432; }
                { host = "remote"; port = 5432; }
              ];
            };
          };
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(_) => {
                // Verify it evaluates
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_large_attribute_set() {
        let evaluator = Evaluator::new();
        let expr = r#"
        {
          a = 1; b = 2; c = 3; d = 4; e = 5;
          f = 6; g = 7; h = 8; i = 9; j = 10;
          k = 11; l = 12; m = 13; n = 14; o = 15;
          p = 16; q = 17; r = 18; s = 19; t = 20;
        }
        "#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::AttributeSet(attrs) => {
                assert_eq!(attrs.len(), 20);
            }
            _ => panic!("Expected AttributeSet"),
        }
    }
}

mod edge_cases {
    use super::*;

    #[test]
    fn test_empty_structures() {
        let evaluator = Evaluator::new();

        assert!(matches!(
            evaluator.evaluate("[]").unwrap(),
            NixValue::List(items) if items.is_empty()
        ));

        assert!(matches!(
            evaluator.evaluate("{}").unwrap(),
            NixValue::AttributeSet(attrs) if attrs.is_empty()
        ));
    }

    #[test]
    fn test_single_element_structures() {
        let evaluator = Evaluator::new();

        let list = evaluator.evaluate("[42]").unwrap();
        match list {
            NixValue::List(items) => {
                assert_eq!(items.len(), 1);
                assert_eq!(items[0], NixValue::Integer(42));
            }
            _ => panic!("Expected List"),
        }

        let attrs = evaluator.evaluate("{ x = 1; }").unwrap();
        match attrs {
            NixValue::AttributeSet(attrs) => {
                assert_eq!(attrs.len(), 1);
                // Attribute values are thunks, need to force them
                let x_value = attrs.get("x").unwrap().clone().force(&evaluator).unwrap();
                assert_eq!(x_value, NixValue::Integer(1));
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_unicode_strings() {
        let evaluator = Evaluator::new();
        let expr = r#""Hello 世界 🌍""#;

        let result = evaluator.evaluate(expr).unwrap();
        match result {
            NixValue::String(s) => {
                assert!(s.contains("世界"));
            }
            _ => panic!("Expected String"),
        }
    }
}
