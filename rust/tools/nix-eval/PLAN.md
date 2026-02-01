# Nix Expression Evaluator: Current State vs Requirements

## Analysis: `nix-eval` vs. Nix Expression Evaluator

### What `nix-eval` Currently Does ✅

- **Basic Parsing**: Uses `rnix` to parse Nix syntax
- **Literal Evaluation**: Integers, floats, strings, booleans, null
- **Basic Data Structures**: Lists and simple attribute sets
- **Variable Scope**: Basic HashMap-based scope (no nesting/shadowing)
- **Builtin Registration**: Framework exists, but no function calls

### Critical Missing Features ❌

#### 1. **Lazy Evaluation / Thunks** (HIGHEST PRIORITY)
- **Current**: Eager evaluation - everything is evaluated immediately
- **Required**: Call-by-need lazy evaluation
  - **Thunks**: Delayed computations that are only evaluated when forced
  - **Memoization**: Once a thunk is evaluated, cache the result
  - **Blackhole Detection**: Detect infinite recursion when forcing thunks
  - This is the **core architectural difference**

#### 2. **Function Application**
- **Current**: No function calls
- **Required**:
  - Function definition: `x: x + 1`
  - Function application: `f 42`
  - Currying: Functions can take multiple arguments
  - Higher-order functions

#### 3. **Language Constructs**
- `let` bindings: `let x = 1; in x`
- `with` statements: `with pkgs; [ hello world ]`
- `if` expressions: `if condition then a else b`
- `import`: Load and evaluate other `.nix` files
- Recursive attribute sets: `rec { x = y; y = 1; }`
- String interpolation: `"Hello ${name}"`
- Path literals: `<nixpkgs>`, `./relative/path`

#### 4. **Builtin Functions**
- **Current**: Framework exists but unused
- **Required**: 100+ builtins including:
  - `builtins.derivation` - create build plans
  - `builtins.readFile` - read files during evaluation
  - `builtins.attrNames`, `builtins.listToAttrs` - attribute set operations
  - `builtins.trace` - debugging
  - Many more...

#### 5. **Store Integration**
- **Current**: No store interaction
- **Required**:
  - Create derivations (`.drv` files)
  - Reference store paths
  - Handle content-addressed vs input-addressed paths
  - Interact with the Nix store database

#### 6. **Operators**
- Arithmetic: `+`, `-`, `*`, `/`, `//` (integer division)
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `&&`, `||`, `!`
- String concatenation: `+`
- Attribute access: `.` operator
- List concatenation: `++`

#### 7. **Advanced Features**
- Import From Derivation (IFD): Evaluate expressions that depend on build outputs
- `__functor`: Make attribute sets callable
- `__toString`: Custom string conversion
- Error handling: Proper Nix-style error messages with source positions

### Architectural Differences

| Aspect | `nix-eval` (Current) | Nix Evaluator (Required) |
|--------|---------------------|--------------------------|
| **Evaluation Model** | Eager | Lazy (call-by-need) |
| **Values** | Direct values | Values OR thunks |
| **Memory Management** | Simple ownership | GC-aware thunk management |
| **Function Calls** | None | Full support with closures |
| **Store Integration** | None | Required for derivations |
| **Builtins** | Framework only | 100+ implementations |

### Gap Assessment

**`nix-eval` is approximately 5-10% of a full Nix evaluator.**

It currently handles:
- ✅ Parsing (via `rnix`)
- ✅ Basic literal evaluation
- ✅ Simple data structures

But it's missing:
- ❌ **Lazy evaluation architecture** (thunks) - **CRITICAL**
- ❌ Function system
- ❌ Store integration
- ❌ Most language features
- ❌ Builtin implementations

### What Would Be Needed to Reach Full Evaluator

#### 1. **Thunk System** (HIGHEST PRIORITY)
   - Implement lazy evaluation with thunks
   - Memoization for evaluated thunks
   - Blackhole detection for cycles

#### 2. **Function System**
   - Closures with lexical scoping
   - Function application
   - Currying support

#### 3. **Store Integration**
   - Derivation creation
   - Store path handling
   - Store database interaction

#### 4. **Language Features**
   - `let`, `with`, `if`, `import`
   - Operators
   - String interpolation
   - Recursive attribute sets

#### 5. **Builtin Functions**
   - Implement standard builtins
   - Store-related builtins

### Conclusion

**`nix-eval` is currently a basic expression calculator, not a Nix evaluator.**

The fundamental missing piece is **lazy evaluation (thunks)**, which is central to Nix's semantics and performance. Without it, you cannot handle:
- Mutually recursive definitions
- Large attribute sets efficiently
- The lazy evaluation model that makes Nix work

To become a real Nix evaluator, it needs a **complete architectural redesign** around lazy evaluation, similar to what Tvix has done. The current code is a foundation, but the core evaluation model needs to be rebuilt.

## References

- [Nix Language Manual - Evaluation](https://nixos.org/manual/nix/unstable/language/evaluation)
- [Tvix: Rust Nix Rewrite](https://tvl.fyi/blog/rewriting-nix)
- [Nix Evaluation Performance](https://nixos.wiki/wiki/Nix_Evaluation_Performance)
