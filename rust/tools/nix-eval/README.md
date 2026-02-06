# nix-eval

A pure Rust library for evaluating Nix expressions.

## Features

- ✅ Literal values: integers, floats, strings, booleans, null
- ✅ Lists
- ✅ Attribute sets
- ✅ Variable scope resolution
- ✅ Extensible builtin function API
- ✅ JSON serialization
- ✅ Comprehensive error handling

## Installation

Add this to your `Cargo.toml`:

```toml
[dependencies]
nix-eval = "0.1.0"
```

## Usage

### Basic Evaluation

```rust
use nix_eval::{Evaluator, NixValue};

let evaluator = Evaluator::new();
let result = evaluator.evaluate("42").unwrap();
assert_eq!(result, NixValue::Integer(42));
```

### Evaluating Different Value Types

```rust
use nix_eval::{Evaluator, NixValue};

let evaluator = Evaluator::new();

// Integers
let value = evaluator.evaluate("42").unwrap();
assert_eq!(value, NixValue::Integer(42));

// Strings
let value = evaluator.evaluate(r#""hello world""#).unwrap();
assert_eq!(value, NixValue::String("hello world".to_string()));

// Booleans
let value = evaluator.evaluate("true").unwrap();
assert_eq!(value, NixValue::Boolean(true));

// Null
let value = evaluator.evaluate("null").unwrap();
assert_eq!(value, NixValue::Null);

// Lists
let value = evaluator.evaluate("[1 2 3]").unwrap();
match value {
    NixValue::List(items) => {
        assert_eq!(items.len(), 3);
    }
    _ => {}
}

// Attribute sets
let value = evaluator.evaluate("{ foo = 1; bar = 2; }").unwrap();
match value {
    NixValue::AttributeSet(attrs) => {
        assert_eq!(attrs.get("foo"), Some(&NixValue::Integer(1)));
    }
    _ => {}
}
```

### Variable Scope

```rust
use nix_eval::{Evaluator, NixValue, VariableScope};
use std::collections::HashMap;

let mut evaluator = Evaluator::new();
let mut scope: VariableScope = HashMap::new();
scope.insert("x".to_string(), NixValue::Integer(42));
scope.insert("y".to_string(), NixValue::String("hello".to_string()));
evaluator.set_scope(scope);

// Variables can now be resolved
let result = evaluator.evaluate("x").unwrap();
assert_eq!(result, NixValue::Integer(42));
```

### Custom Builtin Functions

```rust
use nix_eval::{Evaluator, Builtin, NixValue, Result};

struct AddBuiltin;

impl Builtin for AddBuiltin {
    fn name(&self) -> &str {
        "add"
    }

    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(nix_eval::Error::UnsupportedExpression {
                reason: "add requires 2 arguments".to_string(),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                Ok(NixValue::Integer(a + b))
            }
            _ => Err(nix_eval::Error::UnsupportedExpression {
                reason: "add requires integer arguments".to_string(),
            })
        }
    }
}

let mut evaluator = Evaluator::new();
evaluator.register_builtin(Box::new(AddBuiltin));
// Note: Function calls are not yet implemented, but the API is ready
```

### Error Handling

```rust
use nix_eval::{Evaluator, Error};

let evaluator = Evaluator::new();

match evaluator.evaluate("invalid syntax {") {
    Err(Error::ParseError { reason }) => {
        println!("Parse error: {}", reason);
    }
    Err(Error::UnsupportedExpression { reason }) => {
        println!("Unsupported: {}", reason);
    }
    Ok(value) => {
        println!("Success: {:?}", value);
    }
    _ => {}
}
```

### Display Formatting

```rust
use nix_eval::Evaluator;

let evaluator = Evaluator::new();
let value = evaluator.evaluate("[1 2 3]").unwrap();
println!("{}", value); // Prints: [ 1 2 3 ]
```

### JSON Serialization

```rust
use nix_eval::Evaluator;
use serde_json;

let evaluator = Evaluator::new();
let value = evaluator.evaluate("{ foo = 42; }").unwrap();
let json = serde_json::to_string_pretty(&value).unwrap();
println!("{}", json);
// Output:
// {
//   "type": "attrset",
//   "value": {
//     "foo": {
//       "type": "integer",
//       "value": 42
//     }
//   }
// }
```

## Command-Line Interface

The package includes a command-line tool:

```bash
# Evaluate a simple expression
nix-eval "42"

# Evaluate from a file
nix-eval --file expression.nix

# Output as JSON
nix-eval --format json "[1 2 3]"

# Read from stdin
echo '"hello"' | nix-eval
```

## Limitations

The current implementation has the following limitations:

- ❌ No variable binding (let expressions)
- ❌ No builtin functions (API ready, but calls not implemented)
- ❌ No function application
- ❌ No recursive attribute sets
- ❌ No with expressions
- ❌ No path expressions
- ❌ No import expressions

These features may be added in future versions.

## Testing

Run all tests:

```bash
cargo test
```

Run only integration tests:

```bash
cargo test --test integration_tests
```

## Documentation

Generate documentation:

```bash
cargo doc --open
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Related Projects

- [rnix](https://github.com/nix-community/rnix-parser) - Nix parser used by this library
- [rowan](https://github.com/rust-analyzer/rowan) - Syntax tree library
