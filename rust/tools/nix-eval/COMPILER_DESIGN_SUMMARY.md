# Compiler Design Research Summary

## Key Findings

### 1. Architecture Patterns

**Tree-Walking Interpreter (Our Current Approach)**
- ✅ Simple and straightforward
- ✅ Good for prototyping
- ❌ Performance overhead from repeated AST traversal
- ❌ Context propagation can be complex

**Bytecode VM (Industry Standard)**
- ✅ Better performance (compile once, execute many times)
- ✅ Natural context management through VM stack
- ✅ Industry-standard approach (Lua, Python, many others)
- ❌ More complex implementation
- ❌ Requires compilation step

**Recommendation:** Our tree-walking approach is fine for now, but consider migrating to bytecode VM long-term for better performance and context handling.

### 2. Context Propagation Strategies

#### Current Approach (nix-eval)
```rust
struct Evaluator {
    current_file: Rc<RefCell<Option<PathBuf>>>,  // Global mutable state
}

struct Thunk {
    current_file: Option<PathBuf>,  // Captured at creation
}
```

**Issues:**
- Global mutable state (`Rc<RefCell<>>`)
- Manual save/restore in thunks/functions
- Easy to forget to capture context
- No location information (line/column)

#### Recommended Approach (Rust Compiler Pattern)
```rust
struct Evaluator {
    context_stack: Vec<EvaluationContext>,  // Explicit stack
}

struct EvaluationContext {
    file_path: Option<PathBuf>,
    span: Span,  // File + location
    scope: VariableScope,
}

// Context is explicit and visible
fn evaluate_with_context<F, R>(&mut self, ctx: EvaluationContext, f: F) -> R {
    self.context_stack.push(ctx);
    let result = f(self);
    self.context_stack.pop();
    result
}
```

**Benefits:**
- Explicit context management
- Easy to debug (can inspect stack)
- No global mutable state
- Natural for recursive evaluation

### 3. Span-Based Tracking (Rust Compiler Pattern)

**Key Insight:** Spans carry file path AND location information throughout the entire compilation/evaluation pipeline.

```rust
struct Span {
    file_id: FileId,
    start: BytePos,
    end: BytePos,
}

struct SourceMap {
    files: Vec<SourceFile>,
}

impl Span {
    fn file_path(&self, source_map: &SourceMap) -> Option<&Path> {
        source_map.files.get(self.file_id).map(|f| f.path.as_path())
    }
}
```

**Benefits:**
- Integrated with error reporting
- Efficient (compressed representation)
- Carries through entire pipeline
- Better error messages
- Used by production compilers (Rust, Swift, etc.)

### 4. Thunk Context Capture

**Current Issue:** Thunks are created with `current_file = None` in some cases.

**Solution:** Ensure context is ALWAYS captured when thunks are created.

**Pattern:**
```rust
impl Evaluator {
    fn create_thunk(&self, expr: &Expr, scope: VariableScope) -> Thunk {
        let current_file = self.current_context().file_path.clone();
        Thunk::new(expr, scope, current_file)
    }
}
```

**Key Point:** Context should be captured from the CURRENT evaluation context, not from a global mutable state.

### 5. Evaluation Stack Management

**Problem:** Deep recursion can cause stack overflow.

**Solutions:**
1. **Explicit Stack:** Convert recursion to iteration with explicit stack
2. **Recursion Schemes:** Use `recursion` crate for stack-safe traversal
3. **Trampolines:** Use continuation-passing style

**For nix-eval:** Current recursion depth is probably fine, but consider explicit stack for production.

---

## Actionable Recommendations

### Immediate (Fix Current Bug)

1. **Add Debug Logging**
```rust
impl Thunk {
    fn new(expr: &Expr, closure: VariableScope, current_file: Option<PathBuf>) -> Self {
        eprintln!("Creating thunk with current_file: {:?}", current_file);
        // ...
    }
    
    fn force(&self, evaluator: &Evaluator) -> Result<NixValue> {
        eprintln!("Forcing thunk with stored current_file: {:?}", self.current_file);
        // ...
    }
}
```

2. **Audit All Thunk Creation Points**
   - `evaluate_attr_set()` ✅ Already fixed
   - `evaluate_recursive_attr_set()` ✅ Already fixed
   - `evaluate_let_in()` ✅ Already fixed
   - Check for any other locations

3. **Add Context Validation**
```rust
fn create_thunk(&self, expr: &Expr, scope: VariableScope) -> Thunk {
    let current_file = self.current_file.borrow().clone();
    if current_file.is_none() {
        eprintln!("WARNING: Creating thunk without file context!");
    }
    Thunk::new(expr, scope, current_file)
}
```

### Short Term (Improve Architecture)

1. **Refactor to Explicit Context Stack**
   - Replace `Rc<RefCell<Option<PathBuf>>>` with `Vec<EvaluationContext>`
   - Make context explicit and visible
   - Easier to debug and reason about

2. **Add Basic Span Tracking**
   - Start with just file path (no line/column yet)
   - Add `Span` type with `file_path: Option<PathBuf>`
   - Integrate with error reporting

3. **Improve Error Messages**
   - Include file context in all errors
   - Show evaluation stack on errors
   - Better debugging information

### Medium Term (Better Design)

1. **Implement Proper Span Tracking**
   - Add `SourceMap` for file management
   - Add `FileId` for efficient file references
   - Track byte positions for location info

2. **Add Upvalue Tracking**
   - Distinguish between local and captured variables
   - Optimize closure capture
   - Better performance

3. **Comprehensive Testing**
   - Language test suite
   - Regression tests
   - Performance benchmarks

### Long Term (Advanced Features)

1. **Migrate to Bytecode VM**
   - Better performance
   - Natural context management
   - Industry-standard approach

2. **Query System**
   - Memoization for imports
   - Incremental evaluation
   - Better caching

---

## Key Insights from Research

### 1. Explicit > Implicit

**Bad:** Global mutable state (`Rc<RefCell<>>`)
**Good:** Explicit context stack (`Vec<EvaluationContext>`)

### 2. Span-Based Tracking

**Current:** Just file path
**Better:** File path + location (span)
**Best:** Full source map with stable IDs

### 3. Context Should Flow Through Stack

**Current:** Context stored in thunks/functions
**Better:** Context maintained in evaluation stack
**Best:** VM maintains context automatically (for bytecode VM)

### 4. Rust Compiler Patterns

The Rust compiler uses:
- Explicit context passing (not global state)
- Span-based source tracking
- Query system for memoization
- Visitor pattern for AST traversal

These patterns work well and are worth adopting.

### 5. Industry Standards

Production compilers and interpreters use:
- **Bytecode VM** for performance (Lua, Python, Java)
- **Span-based tracking** for error reporting (Rust, Swift)
- **Explicit context stacks** for evaluation state
- **Upvalue tracking** for closures (Lua, JavaScript)

These are proven patterns worth learning from.

---

## Resources for Further Learning

### Books
- **Crafting Interpreters** - Excellent introduction to interpreter design
- **Writing Interpreters in Rust** - Rust-specific guide (rust-hosted-langs.github.io/book)
- **Rust Compiler Development Guide** - Production compiler patterns (rustc-dev-guide.rust-lang.org)

### Projects to Study
- **Rust Compiler** - Production compiler with excellent patterns
- **Rhai** - Simple tree-walking interpreter example
- **crafting-interpreters-rs** - Rust implementation of Crafting Interpreters
- **Lua** - Reference VM implementation

### Key Concepts to Master
- **Eval/Apply Pattern** - Core evaluation pattern
- **Upvalues** - Closure variable capture
- **Spans** - Source location tracking
- **Context Stack** - Explicit context management
- **Memoization** - Caching evaluated results
- **Interior Mutability** - When and how to use it

---

## Conclusion

The research confirms that our approach of capturing `current_file` in thunks/functions is correct, but we need to:

1. **Ensure context is ALWAYS captured** when thunks are created
2. **Add explicit context stack** instead of global mutable state
3. **Implement span tracking** for better error messages
4. **Consider bytecode VM** for long-term performance

The "(no current file context)" error is likely due to a thunk being created before context is set, or context not being properly propagated. With explicit context stack and proper logging, we can identify and fix the issue.

**Next Steps:**
1. Add debug logging to track context propagation
2. Refactor to explicit context stack
3. Investigate where thunks are created without context
4. Fix the bug and verify with tests
