# Rust Crates for Compiler Rewrite

If we were to completely rewrite `nix-eval`, here are the Rust crates that would save the most development time by leveraging existing, battle-tested infrastructure.

## Core Infrastructure

### 1. **Parsing & AST**
- **`rnix`** (keep) - Already using this, it's the standard Nix parser
  - Uses `rowan` internally for lossless syntax trees
  - Well-maintained and Nix-specific
  
- **`rowan`** (keep) - Lossless syntax trees
  - Used by rust-analyzer
  - 200k+ downloads/month
  - Provides `SyntaxNode`, `SyntaxToken`, `SyntaxElement`
  - Perfect for maintaining source location information

### 2. **Source Location & Spans**
- **`codespan`** - Source file management and location tracking
  - Provides `Files` database for source files
  - `ByteIndex`, `LineIndex`, `ColumnIndex` types
  - `Span` types for source ranges
  - Used by many Rust language implementations
  - ~1.4M downloads/month, 2,200+ crates

- **`codespan-reporting`** - Beautiful diagnostic reporting
  - Structured error/warning diagnostics
  - Terminal output backends
  - Compiler-like error messages
  - Industry standard for language tools

**Alternative:** `miette` - More comprehensive diagnostic protocol
  - Generic error protocol with derive macros
  - Pluggable renderers (terminal, JSON, etc.)
  - Automatic accessibility features
  - More modern API, but heavier

### 3. **Error Handling**
- **`thiserror`** (keep) - Already using, perfect for error types
  - Derive macro for `Error` trait
  - Clean error definitions
  
- **`anyhow`** (keep) - Context-aware error handling
  - `Result<T, anyhow::Error>` for application code
  - `.context()` for adding context

**Consider:** `miette` could replace both if we want integrated diagnostics

### 4. **Lazy Evaluation & Memoization**
- **`cached`** - Memoization and caching
  - Multiple cache backends (LRU, timed, etc.)
  - Macro-based memoization
  - Could simplify thunk memoization

**Note:** Our custom `Thunk` implementation is probably fine, but `cached` could help with import caching and builtin memoization.

### 5. **Bytecode VM (Future Consideration)**
If we migrate from tree-walking to bytecode:

- **`cranelift`** - Code generation backend
  - Used by Wasmtime
  - JIT compilation support
  - Overkill for now, but powerful

- **`cranelift-interpreter`** - Interpreter for Cranelift IR
  - Could use for bytecode execution
  - Part of Bytecode Alliance

**Recommendation:** Stick with tree-walking for now, but these are options if we need performance later.

## Language Server Protocol (LSP)

### 6. **Language Server**
- **`tower-lsp`** - LSP implementation
  - Built on Tower framework
  - Async support (tokio)
  - 158k+ downloads/month
  - Would enable IDE integration

**Use Case:** If we want to provide IDE support (autocomplete, go-to-definition, etc.)

## Serialization & Data

### 7. **Serialization**
- **`serde`** (keep) - Already using
  - Industry standard
  - JSON, CBOR, MessagePack, etc.

- **`serde_json`** (keep) - JSON support

## Testing & Benchmarking

### 8. **Testing**
- **`proptest`** (keep) - Property-based testing
  - Already using
  - Great for fuzzing evaluator

- **`criterion`** (keep) - Benchmarking
  - Already using
  - Statistical analysis

## Recommended Stack for Rewrite

### Minimal (Current + Essential)
```toml
[dependencies]
# Parsing
rnix = "0.11"
rowan = "0.15"

# Source tracking & errors
codespan = "0.11"
codespan-reporting = "0.13"
thiserror = "1.0"
anyhow = "1.0"

# Core
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### Enhanced (Add Diagnostics)
```toml
[dependencies]
# Replace codespan-reporting with miette for richer diagnostics
miette = { version = "7.6", features = ["fancy"] }
# Keep codespan for source management
codespan = "0.11"
```

### Full-Featured (Add LSP)
```toml
[dependencies]
# ... all above ...
tower-lsp = "0.20"
tokio = { version = "1.0", features = ["full"] }
```

## Key Architectural Changes

### 1. **Span-Based Context** (High Priority)
Replace `current_file: Rc<RefCell<Option<PathBuf>>>` with:

```rust
use codespan::{Files, Span};

struct Evaluator {
    source_map: Files<String>,
    context_stack: Vec<EvaluationContext>,
}

struct EvaluationContext {
    span: Span,
    scope: VariableScope,
}

impl Evaluator {
    fn current_file(&self) -> Option<&Path> {
        self.context_stack.last()
            .and_then(|ctx| {
                let file_id = self.source_map.span_to_file_id(ctx.span);
                self.source_map.get(file_id).map(|f| f.name())
            })
    }
}
```

**Benefits:**
- Explicit context stack (no global mutable state)
- Integrated with error reporting
- Carries line/column information
- Easier to debug

### 2. **Integrated Error Reporting** (High Priority)
Use `codespan-reporting` or `miette`:

```rust
use codespan_reporting::diagnostic::{Diagnostic, Label};
use codespan_reporting::files::SimpleFiles;
use codespan_reporting::term;

fn report_error(
    files: &SimpleFiles<String, String>,
    span: Span,
    message: &str,
) {
    let diagnostic = Diagnostic::error()
        .with_message(message)
        .with_labels(vec![
            Label::primary(span.file_id, span.range())
                .with_message("error occurred here")
        ]);
    
    term::emit(&mut term::termcolor::StandardStream::stderr(), ...);
}
```

**Benefits:**
- Beautiful, compiler-like error messages
- Automatic source code snippets
- Multi-file error support
- Standard format

### 3. **Context Stack Pattern** (High Priority)
Replace manual save/restore with explicit stack:

```rust
impl Evaluator {
    fn evaluate_with_context<F, R>(
        &mut self,
        file_id: FileId,
        span: Span,
        scope: VariableScope,
        f: F,
    ) -> R
    where
        F: FnOnce(&mut Self) -> R,
    {
        let ctx = EvaluationContext { span, scope };
        self.context_stack.push(ctx);
        let result = f(self);
        self.context_stack.pop();
        result
    }
}
```

**Benefits:**
- No more `Rc<RefCell<>>` for context
- Explicit and debuggable
- Natural for recursive evaluation
- Prevents context loss bugs

## Migration Strategy

### Phase 1: Add Span Tracking (Low Risk)
1. Add `codespan` for source file management
2. Wrap AST nodes with spans
3. Keep existing `current_file` logic temporarily

### Phase 2: Replace Context Management (Medium Risk)
1. Implement context stack
2. Migrate thunk/function context capture
3. Remove `Rc<RefCell<Option<PathBuf>>>`

### Phase 3: Integrate Error Reporting (Low Risk)
1. Replace error strings with `Diagnostic` types
2. Use `codespan-reporting` for output
3. Add source code snippets to errors

### Phase 4: Optional Enhancements
1. Add `miette` for richer diagnostics (if needed)
2. Add `tower-lsp` for IDE support (if desired)
3. Consider bytecode VM (if performance becomes issue)

## Estimated Time Savings

- **Span tracking**: ~2-3 weeks → 2-3 days (with `codespan`)
- **Error reporting**: ~1-2 weeks → 1-2 days (with `codespan-reporting`)
- **Context management**: ~1 week → 2-3 days (with explicit stack pattern)
- **LSP support**: ~1-2 months → 1-2 weeks (with `tower-lsp`)

**Total potential savings: 2-3 months → 2-3 weeks** for core infrastructure.

## Conclusion

The biggest wins come from:
1. **`codespan` + `codespan-reporting`** - Source tracking and error reporting
2. **Context stack pattern** - Better architecture (no new crates, just pattern)
3. **`miette`** (optional) - If we want richer diagnostics

These crates are battle-tested, well-documented, and used by production compilers. They would significantly reduce development time while improving code quality and user experience.
