# Nix Expression Evaluator: Current State vs Requirements

## Analysis: `nix-eval` vs. Nix Expression Evaluator

### What `nix-eval` Currently Does ✅

- **Basic Parsing**: Uses `rnix` to parse Nix syntax
- **Literal Evaluation**: Integers, floats, strings, booleans, null
- **Basic Data Structures**: Lists and simple attribute sets
- **Variable Scope**: Basic HashMap-based scope (no nesting/shadowing)
- **Builtin Registration**: Framework exists, but no function calls
- **✅ Lazy Evaluation / Thunks**: Thunk system implemented with forcing, memoization, and blackhole detection
- **✅ Lazy Attribute Sets**: Attribute set values are wrapped in thunks and evaluated on-demand

### Critical Missing Features ❌

#### 1. **Lazy Evaluation / Thunks** ✅ **COMPLETED**
- **✅ Implemented**: Call-by-need lazy evaluation
  - **✅ Thunks**: `Thunk` data structure stores delayed computations with expression and lexical closure
  - **✅ Forcing**: `force()` method evaluates thunks when their values are needed
  - **✅ Memoization**: Evaluated results are cached, subsequent accesses return cached value
  - **✅ Blackhole Detection**: `Evaluating` state marker detects infinite recursion, returns `InfiniteRecursion` error
  - **✅ Integration**: Attribute set values are wrapped in thunks, evaluated lazily on access
  - This was the **core architectural difference** - now implemented!

#### 2. **Function Application** ✅ **MOSTLY COMPLETED**
- **✅ Implemented**: Function system foundation
  - **✅ Function definition**: `x: x + 1` - Lambda expressions create `Function` closures
  - **✅ Function application**: `f 42` - Functions can be applied to arguments
  - **✅ Lexical scoping**: Functions capture their lexical environment (closures)
  - **✅ Function data structure**: `Function` struct with parameter, body, and closure
- **❌ Still missing**:
  - Currying: Functions can take multiple arguments (partial application)
  - Higher-order functions (functions that take/return functions)

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
| **Evaluation Model** | ✅ Lazy (call-by-need) | Lazy (call-by-need) |
| **Values** | ✅ Values OR thunks | Values OR thunks |
| **Memory Management** | ✅ GC-aware thunk management | GC-aware thunk management |
| **Function Calls** | ✅ Basic support (lambdas, application, closures) | Full support with closures + currying |
| **Store Integration** | None | Required for derivations |
| **Builtins** | Framework only | 100+ implementations |

### Gap Assessment

**`nix-eval` is approximately 15-20% of a full Nix evaluator** (up from 5-10%).

It currently handles:
- ✅ Parsing (via `rnix`)
- ✅ Basic literal evaluation
- ✅ Simple data structures
- ✅ **Lazy evaluation architecture** (thunks) - **COMPLETED**
- ✅ Thunk forcing, memoization, and blackhole detection
- ✅ Lazy attribute set evaluation

But it's still missing:
- ⚠️ Function system (basic support done, currying missing)
- ❌ Store integration
- ❌ Most language features (`let`, `with`, `if`, `import`, etc.)
- ❌ Builtin implementations

### What Would Be Needed to Reach Full Evaluator

#### 1. **Thunk System** ✅ **COMPLETED** (HIGHEST PRIORITY)
   - ✅ Implement lazy evaluation with thunks (`Thunk` struct with expression and closure)
   - ✅ Memoization for evaluated thunks (cached results in `cached_value`)
   - ✅ Blackhole detection for cycles (`Evaluating` state marker)
   - ✅ Integration into evaluator (attribute sets use lazy evaluation)

#### 2. **Function System** ✅ **MOSTLY COMPLETED**
   - ✅ Closures with lexical scoping (`Function` captures scope at creation)
   - ✅ Function application (`Function::apply` with scope merging)
   - ✅ Lambda evaluation (`evaluate_lambda` creates functions)
   - ✅ Function application evaluation (`evaluate_apply` applies functions)
   - ❌ Currying support (partial application for multi-argument functions)

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

**`nix-eval` has made significant progress toward becoming a proper Nix evaluator.**

✅ **Major Milestone Achieved**: The **lazy evaluation (thunks)** system has been fully implemented, which was the core architectural difference. This enables:
- ✅ Lazy evaluation of attribute set values
- ✅ Memoization of evaluated expressions
- ✅ Detection of infinite recursion (blackhole detection)
- ✅ Foundation for handling mutually recursive definitions

**Remaining Work**: While the lazy evaluation and basic function system foundations are complete, `nix-eval` still needs:
- Function currying (partial application for multi-argument functions)
- Store integration for derivations
- Language features (`let`, `with`, `if`, `import`, operators, etc.)
- Builtin function implementations

The core evaluation model has been rebuilt around lazy evaluation, similar to what Tvix has done. The remaining work builds on this foundation.

## References

- [Nix Language Manual - Evaluation](https://nixos.org/manual/nix/unstable/language/evaluation)
- [Tvix: Rust Nix Rewrite](https://tvl.fyi/blog/rewriting-nix)
- [Nix Evaluation Performance](https://nixos.wiki/wiki/Nix_Evaluation_Performance)
