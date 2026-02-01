# Compiler Design Guide: Context Propagation and Evaluation Patterns

## Table of Contents

1. [Architecture Patterns](#architecture-patterns)
2. [Context Propagation Strategies](#context-propagation-strategies)
3. [File Path and Span Tracking](#file-path-and-span-tracking)
4. [Lazy Evaluation and Thunks](#lazy-evaluation-and-thunks)
5. [Closures and Upvalues](#closures-and-upvalues)
6. [Evaluation Stack Management](#evaluation-stack-management)
7. [Best Practices for Rust](#best-practices-for-rust)
8. [Real-World Examples](#real-world-examples)

---

## Architecture Patterns

### Tree-Walking Interpreter vs Bytecode VM

#### Tree-Walking Interpreter (Our Current Approach)

**Characteristics:**
- Direct AST evaluation through recursive tree traversal
- Pattern matching on each AST node type
- Values computed directly during traversal
- Simpler to implement and understand
- Generally slower due to repeated AST traversal

**Pattern:**
```rust
fn evaluate_expr(&self, expr: &Expr) -> Result<Value> {
    match expr {
        Expr::Integer(i) => Ok(Value::Integer(*i)),
        Expr::BinaryOp { op, left, right } => {
            let left_val = self.evaluate_expr(left)?;
            let right_val = self.evaluate_expr(right)?;
            self.apply_op(op, left_val, right_val)
        }
        // ...
    }
}
```

**Pros:**
- Straightforward implementation
- Easy to add new expression types
- Good for prototyping and learning
- No compilation step needed

**Cons:**
- Performance overhead from repeated AST traversal
- Harder to optimize
- Context propagation can be complex

#### Bytecode VM (Industry Standard)

**Characteristics:**
- Compiles AST to bytecode instructions
- VM executes pre-compiled instructions
- Uses eval/apply pattern: `eval` generates instructions, `apply` executes them
- Register-based or stack-based architecture
- Better performance through compilation optimizations

**Pattern:**
```rust
// Compilation phase
fn compile_expr(&mut self, expr: &Expr) -> Result<Vec<Opcode>> {
    match expr {
        Expr::Integer(i) => Ok(vec![Opcode::LoadConst(*i)]),
        Expr::BinaryOp { op, left, right } => {
            let mut code = self.compile_expr(left)?;
            code.extend(self.compile_expr(right)?);
            code.push(Opcode::BinaryOp(*op));
            Ok(code)
        }
        // ...
    }
}

// Execution phase
fn execute(&mut self, bytecode: &[Opcode]) -> Result<Value> {
    // VM executes instructions
}
```

**Pros:**
- Better performance (compiled once, executed many times)
- Easier to optimize (dead code elimination, constant folding)
- Better context tracking through VM stack
- Industry-standard approach (used by Lua, Python, many others)

**Cons:**
- More complex implementation
- Requires compilation step
- Harder to debug

**Recommendation:** For nix-eval, tree-walking is fine for now. Consider migrating to bytecode VM long-term for better performance and context handling.

---

## Context Propagation Strategies

### 1. Context Stack Pattern

**Problem:** Need to track file paths, scopes, and other context during recursive evaluation.

**Solution:** Maintain an explicit context stack that grows/shrinks with evaluation depth.

```rust
struct EvaluationContext {
    file_path: Option<PathBuf>,
    scope: VariableScope,
    // ... other context
}

struct Evaluator {
    context_stack: Vec<EvaluationContext>,
    // ...
}

impl Evaluator {
    fn push_context(&mut self, ctx: EvaluationContext) {
        self.context_stack.push(ctx);
    }
    
    fn pop_context(&mut self) -> Option<EvaluationContext> {
        self.context_stack.pop()
    }
    
    fn current_context(&self) -> &EvaluationContext {
        self.context_stack.last().unwrap()
    }
}
```

**Pros:**
- Explicit context management
- Easy to debug (can inspect stack)
- Natural for recursive evaluation

**Cons:**
- Manual stack management
- Can forget to pop context
- Stack overhead

### 2. Thread-Local Storage (TLS)

**Problem:** Need global context accessible from anywhere in evaluation.

**Solution:** Use Rust's `thread_local!` macro for thread-local context.

```rust
thread_local! {
    static CURRENT_FILE: RefCell<Option<PathBuf>> = RefCell::new(None);
}

fn with_file_context<F, R>(file: Option<PathBuf>, f: F) -> R
where
    F: FnOnce() -> R,
{
    CURRENT_FILE.with(|current| {
        let old = current.replace(file);
        let result = f();
        current.replace(old);
        result
    })
}
```

**Pros:**
- Globally accessible
- Automatic cleanup
- No manual stack management

**Cons:**
- Less explicit (harder to see where context is set)
- Thread-local only
- Can be confusing in async contexts

**Note:** The Rust compiler uses TLS sparingly, preferring explicit context passing.

### 3. Context in Visitor Struct (Rust Compiler Pattern)

**Problem:** Need to propagate context through AST traversal.

**Solution:** Embed context directly in visitor struct.

```rust
struct MyVisitor {
    tcx: TyCtxt<'tcx>,
    current_file: Option<PathBuf>,
    scope: VariableScope,
    // ... other context
}

impl Visitor for MyVisitor {
    fn visit_expr(&mut self, expr: &Expr) {
        // Context is available as self.current_file, etc.
        // Update context as needed
        self.current_file = Some(new_path);
        // Recursive traversal
        walk_expr(self, expr);
        // Restore if needed
    }
}
```

**Pros:**
- Context is explicit and visible
- Easy to pass around
- No global state

**Cons:**
- Must clone context when needed
- Can be verbose

**Recommendation:** This is the Rust compiler's preferred approach. Consider refactoring nix-eval to use this pattern.

### 4. Span-Based Tracking (Rust Compiler Pattern)

**Problem:** Need to track source locations for error reporting and context.

**Solution:** Use `Span` types that carry file path and location information.

```rust
#[derive(Clone, Copy)]
struct Span {
    file_id: FileId,
    lo: BytePos,
    hi: BytePos,
    ctxt: SyntaxContext,
}

struct SourceMap {
    files: Vec<SourceFile>,
    // ...
}

impl Span {
    fn file_path(&self, source_map: &SourceMap) -> Option<&Path> {
        self.files.get(self.file_id).map(|f| f.path.as_path())
    }
}
```

**Pros:**
- Integrated with error reporting
- Efficient (compressed representation)
- Carries through entire compilation pipeline
- Used by production compilers (Rust, Swift, etc.)

**Cons:**
- Requires source map infrastructure
- More complex initial setup

**Recommendation:** Long-term goal - implement span-based tracking like the Rust compiler.

---

## File Path and Span Tracking

### Rust Compiler's Approach

The Rust compiler uses a sophisticated `SourceMap` system:

```rust
struct SourceMap {
    files: RwLock<SourceMapFiles>,
    file_loader: Box<dyn FileLoader>,
    path_mapping: PathMapping,
    working_dir: PathBuf,
}

struct SourceFile {
    name: FileName,
    src: String,
    start_pos: BytePos,  // Global position
    lines: Vec<BytePos>,
    stable_id: StableFileId,
    cnum: CrateNum,
}

struct Span {
    // Compressed 8-byte representation
    // Most spans fit inline, rare ones are interned
}
```

**Key Features:**
- Global byte positions for cross-file mapping
- Stable file IDs for consistent referencing
- Efficient compression (99.9%+ spans fit in 8 bytes)
- Precomputed line boundaries
- Integrated with error reporting

### Our Current Approach

```rust
struct Evaluator {
    current_file: Rc<RefCell<Option<PathBuf>>>,
    // ...
}
```

**Issues:**
- Single file path (no history)
- No location information (line/column)
- Manual save/restore in thunks/functions
- No integration with error reporting

### Recommended Improvement

```rust
struct SourceMap {
    files: Vec<SourceFile>,
    current_file_id: Option<FileId>,
}

struct SourceFile {
    path: PathBuf,
    content: String,
    id: FileId,
}

struct Span {
    file_id: FileId,
    start: usize,
    end: usize,
}

struct EvaluationContext {
    span: Span,  // Current evaluation location
    scope: VariableScope,
    // ...
}
```

---

## Lazy Evaluation and Thunks

### Thunk Design Patterns

#### Pattern 1: Capture Context at Creation (Our Current Approach)

```rust
struct Thunk {
    expression_text: String,
    closure: VariableScope,
    current_file: Option<PathBuf>,  // Captured at creation
    // ...
}

impl Thunk {
    fn force(&self, evaluator: &Evaluator) -> Result<Value> {
        // Restore context
        let old = evaluator.current_file.replace(self.current_file.clone());
        let result = self.evaluate();
        evaluator.current_file.replace(old);
        result
    }
}
```

**Pros:**
- Explicit context capture
- Works with tree-walking interpreter

**Cons:**
- Must remember to capture context
- Manual restoration
- Context can be None if not set

#### Pattern 2: Span-Based Context (Rust Compiler Pattern)

```rust
struct Thunk {
    expression: Expr,
    closure: Closure,
    span: Span,  // Includes file path and location
    // ...
}

impl Thunk {
    fn force(&self, evaluator: &mut Evaluator) -> Result<Value> {
        // Evaluator maintains context stack
        // Span provides file path when needed
        evaluator.push_context_from_span(self.span);
        let result = evaluator.evaluate(&self.expression);
        evaluator.pop_context();
        result
    }
}
```

**Pros:**
- Integrated with source tracking
- Context managed by evaluator
- Better error messages

**Cons:**
- Requires span infrastructure
- More complex

### Thunk State Management

**Common States:**
- **Suspended**: Not yet evaluated
- **Evaluating**: Currently being evaluated (blackhole detection)
- **Evaluated**: Fully evaluated, result cached

**Interior Mutability:**
```rust
struct Thunk {
    state: Arc<Mutex<ThunkState>>,
    cached_value: Arc<Mutex<Option<Value>>>,
}
```

**Memoization:** Once evaluated, cache the result to avoid re-evaluation.

---

## Closures and Upvalues

### Upvalue Capture

**Problem:** Closures need to capture variables from enclosing scopes.

**Solution:** Track "upvalues" (free variables) and capture them appropriately.

```rust
struct Closure {
    function: Function,
    upvalues: Vec<Upvalue>,  // Captured variables
}

enum Upvalue {
    Local(usize),      // Still on stack
    Escaped(Rc<RefCell<Value>>),  // Moved to heap
}
```

### Rust Compiler's Approach

The Rust compiler:
1. **Infers capture mode** (by reference, mutable reference, or move)
2. **Desugars closures** into structs containing captured values
3. **Tracks upvars** during compilation

```rust
// Closure: |x| x + y
// Desugared to:
struct Closure {
    y: i32,  // Captured by value
}

impl Closure {
    fn call(&self, x: i32) -> i32 {
        x + self.y
    }
}
```

### Our Current Approach

```rust
struct Function {
    parameter: String,
    body_text: String,
    closure: VariableScope,  // Captured scope
    current_file: Option<PathBuf>,
}
```

**Issues:**
- No distinction between capture modes
- All variables captured by cloning scope
- No upvalue tracking

**Recommendation:** Consider implementing proper upvalue tracking for better performance and correctness.

---

## Evaluation Stack Management

### Stack Safety

**Problem:** Deep recursion can cause stack overflow.

**Solutions:**

1. **Explicit Stack:**
```rust
struct Evaluator {
    eval_stack: Vec<EvalFrame>,
}

struct EvalFrame {
    expr: Expr,
    context: EvaluationContext,
}

fn evaluate(&mut self, expr: Expr) -> Result<Value> {
    self.eval_stack.push(EvalFrame { expr, context: self.current_context() });
    
    while let Some(frame) = self.eval_stack.pop() {
        match frame.expr {
            Expr::BinaryOp { op, left, right } => {
                // Push right, then left (LIFO)
                self.eval_stack.push(EvalFrame { expr: *right, ..frame });
                self.eval_stack.push(EvalFrame { expr: *left, ..frame });
            }
            // ...
        }
    }
}
```

2. **Recursion Schemes:**
```rust
use recursion::*;

#[derive(Recursive)]
enum Expr {
    Integer(i64),
    BinaryOp { op: Op, left: Box<Expr>, right: Box<Expr> },
}

impl Collapsible for Expr {
    // Define how to collapse frames
}
```

3. **Trampolines:**
```rust
enum EvalResult {
    Done(Value),
    Continue(Box<dyn FnOnce() -> EvalResult>),
}

fn evaluate_trampoline(mut result: EvalResult) -> Value {
    loop {
        match result {
            EvalResult::Done(v) => return v,
            EvalResult::Continue(f) => result = f(),
        }
    }
}
```

### Context Stack

**Pattern:** Maintain context stack alongside evaluation stack.

```rust
struct Evaluator {
    context_stack: Vec<EvaluationContext>,
    eval_stack: Vec<EvalFrame>,
}

impl Evaluator {
    fn evaluate_with_context<F, R>(&mut self, ctx: EvaluationContext, f: F) -> R
    where
        F: FnOnce(&mut Self) -> R,
    {
        self.context_stack.push(ctx);
        let result = f(self);
        self.context_stack.pop();
        result
    }
}
```

---

## Best Practices for Rust

### 1. Prefer Explicit Context Passing

**Bad:**
```rust
thread_local! {
    static CONTEXT: RefCell<Context> = ...
}

fn evaluate() {
    CONTEXT.with(|ctx| { /* ... */ });
}
```

**Good:**
```rust
struct Evaluator {
    context: EvaluationContext,
}

impl Evaluator {
    fn evaluate(&mut self, expr: &Expr) -> Result<Value> {
        // Context is explicit
    }
}
```

### 2. Use Interior Mutability Sparingly

**Bad:**
```rust
struct Evaluator {
    current_file: Rc<RefCell<Option<PathBuf>>>,  // Too many layers
}
```

**Good:**
```rust
struct Evaluator {
    context_stack: Vec<EvaluationContext>,  // Explicit stack
}

struct EvaluationContext {
    file_path: Option<PathBuf>,  // Immutable in context
}
```

### 3. Leverage Rust's Type System

**Use enums for states:**
```rust
enum ThunkState {
    Suspended { expr: Expr, closure: Closure },
    Evaluating,
    Evaluated(Value),
}
```

**Use newtypes for IDs:**
```rust
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
struct FileId(u32);

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
struct SpanId(u32);
```

### 4. Error Handling

**Use Result types consistently:**
```rust
type EvalResult<T> = Result<T, EvalError>;

#[derive(Debug, Error)]
enum EvalError {
    #[error("cannot resolve import path '{path}': {reason}")]
    ImportResolution { path: PathBuf, reason: String, span: Span },
    
    #[error("undefined variable '{name}'")]
    UndefinedVariable { name: String, span: Span },
}
```

### 5. Source Map Integration

**Track spans throughout evaluation:**
```rust
struct Expr {
    kind: ExprKind,
    span: Span,  // Always include span
}

fn evaluate_expr(&mut self, expr: &Expr) -> EvalResult<Value> {
    // Use expr.span for error reporting
    match &expr.kind {
        ExprKind::Import(path) => {
            self.import_file(path, expr.span)
        }
        // ...
    }
}
```

---

## Real-World Examples

### 1. Rust Compiler (rustc)

**Architecture:**
- Query-based compilation system
- MIR (Mid-level IR) for analysis
- Span-based source tracking
- Explicit context passing through queries

**Key Lessons:**
- Use queries for memoization
- Track spans throughout compilation
- Explicit context is better than global state
- Visitor pattern for AST traversal

### 2. Rhai (Embedded Scripting)

**Architecture:**
- Tree-walking interpreter
- `EvalContext` for state
- Simple but effective

**Key Lessons:**
- Context struct can be simple
- Good for embedded scripting
- Less complex than full compiler
- Shows tree-walking can work well

### 3. Crafting Interpreters (Lox)

**Architecture:**
- Two implementations: tree-walker and bytecode VM
- Excellent learning resource
- Shows progression from simple to complex

**Key Lessons:**
- Start with tree-walker
- Migrate to bytecode for performance
- Context tracking improves with VM
- Good patterns for both approaches

### 4. Lua (Reference Implementation)

**Architecture:**
- Bytecode VM
- Register-based
- Upvalue tracking for closures

**Key Lessons:**
- VM stack naturally handles context
- Upvalues important for closures
- Register-based can be efficient
- Industry-standard patterns

---

## Recommendations for nix-eval

### Short Term (Current Issues)

1. **Add debug logging** to track `current_file` propagation
2. **Investigate thunk creation points** - ensure all capture context
3. **Add span information** to AST nodes (even if just file path initially)
4. **Improve error messages** with file context

### Medium Term

1. **Refactor to explicit context stack:**
```rust
struct Evaluator {
    context_stack: Vec<EvaluationContext>,
    // Remove Rc<RefCell<Option<PathBuf>>>
}

struct EvaluationContext {
    file_path: Option<PathBuf>,
    scope: VariableScope,
    span: Option<Span>,  // For future span support
}
```

2. **Implement proper span tracking:**
   - Add `Span` type with file ID and position
   - Add `SourceMap` for file management
   - Integrate spans with error reporting

3. **Add upvalue tracking** for closures

### Long Term

1. **Consider migrating to bytecode VM:**
   - Better performance
   - Natural context management
   - Industry-standard approach

2. **Implement query system** (like rustc) for:
   - Import caching
   - Memoization
   - Incremental evaluation

3. **Add comprehensive testing:**
   - Language test suite
   - Regression tests
   - Performance benchmarks

---

## Resources

### Books
- **Crafting Interpreters** by Robert Nystrom - Excellent introduction
- **Writing Interpreters in Rust: a Guide** (rust-hosted-langs.github.io/book) - Rust-specific guide
- **Rust Compiler Development Guide** (rustc-dev-guide.rust-lang.org) - Production compiler patterns

### Projects to Study
- **Rust Compiler** (github.com/rust-lang/rust) - Production compiler with excellent patterns
- **Rhai** (github.com/rhaiscript/rhai) - Simple tree-walking interpreter
- **crafting-interpreters-rs** - Rust implementation of Crafting Interpreters
- **Lua** - Reference VM implementation

### Key Concepts
- **Eval/Apply Pattern**: Recursive descent with function application
- **Upvalues**: Variables captured by closures
- **Spans**: Source location tracking
- **Context Stack**: Explicit context management
- **Memoization**: Caching evaluated results
- **Interior Mutability**: `RefCell`, `Cell` for mutable shared state

---

## Conclusion

The key insight from compiler design research is that **explicit context propagation** is superior to implicit global state. Production compilers (like Rust) use:

1. **Span-based tracking** for source locations
2. **Explicit context stacks** for evaluation state
3. **Query systems** for memoization and caching
4. **Visitor patterns** for AST traversal

Our current approach of storing `current_file` in thunks/functions is correct, but we should:

1. **Ensure context is always captured** when thunks are created
2. **Add span tracking** for better error messages
3. **Consider explicit context stack** instead of `Rc<RefCell<>>`
4. **Long-term: consider bytecode VM** for better performance and context handling

The "(no current file context)" error suggests we're missing context capture somewhere. With proper logging and explicit context stack, we can identify and fix the issue.
