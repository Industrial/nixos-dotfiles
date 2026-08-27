# Testing Anti-Patterns

**Load this reference when:** writing or changing tests, adding mocks, or tempted to add test-only methods to production code.

## Overview

Tests must verify real behavior, not mock behavior. Mocks are a means to isolate, not the thing being tested.

**Core principle:** Test what the code does, not what the mocks do.

**Following strict TDD prevents these anti-patterns.**

## The Iron Laws

```
1. NEVER test mock behavior
2. NEVER add test-only methods to production classes
3. NEVER mock without understanding dependencies
```

## Anti-Pattern 1: Testing Mock Behavior

**The violation:**

```gleam
// ❌ BAD: Testing that the mock exists
import gleam/option.{None, Some}

pub fn renders_sidebar_test() {
  let page = Page(sidebar: Some(MockSidebar))

  page.sidebar
  |> should.be_some
}
```

**Why this is wrong:**

- You're verifying the mock works, not that the component works
- Test passes when mock is present, fails when it's not
- Tells you nothing about real behavior

**your human partner's correction:** "Are we testing the behavior of a mock?"

**The fix:**

```gleam
// ✅ GOOD: Test real component or don't mock it
pub fn renders_sidebar_test() {
  let page = render_page()  // Don't mock sidebar

  page
  |> get_navigation_elements
  |> list.length
  |> should.equal(3)
}

// OR if sidebar must be mocked for isolation:
// Don't assert on the mock - test Page's behavior with sidebar present
```

### Gate Function

```
BEFORE asserting on any mock element:
  Ask: "Am I testing real component behavior or just mock existence?"

  IF testing mock existence:
    STOP - Delete the assertion or unmock the component

  Test real behavior instead
```

## Anti-Pattern 2: Test-Only Methods in Production

**The violation:**

```gleam
// ❌ BAD: destroy() only used in tests
pub type Session {
  Session(id: String, workspace_manager: Option(WorkspaceManager))
}

pub fn destroy(session: Session) -> Result(Nil, String) {
  // Looks like production API!
  case session.workspace_manager {
    Some(manager) -> workspace.destroy_workspace(manager, session.id)
    None -> Ok(Nil)
  }
}

// In tests
// afterEach(() -> session.destroy())
```

**Why this is wrong:**

- Production type polluted with test-only code
- Dangerous if accidentally called in production
- Violates YAGNI and separation of concerns
- Confuses object lifecycle with entity lifecycle

**The fix:**

```gleam
// ✅ GOOD: Test utilities handle test cleanup
// Session has no destroy() - it's stateless in production

// In test/test_utils.gleam
pub fn cleanup_session(session: Session) -> Result(Nil, String) {
  case session.workspace_manager {
    Some(manager) -> workspace.destroy_workspace(manager, session.id)
    None -> Ok(Nil)
  }
}

// In tests
// afterEach(() -> test_utils.cleanup_session(session))
```

### Gate Function

```
BEFORE adding any function to production module:
  Ask: "Is this only used by tests?"

  IF yes:
    STOP - Don't add it
    Put it in test utilities instead

  Ask: "Does this module own this resource's lifecycle?"

  IF no:
    STOP - Wrong module for this function
```

## Anti-Pattern 3: Mocking Without Understanding

**The violation:**

```gleam
// ❌ BAD: Mock breaks test logic
pub fn detects_duplicate_server_test() {
  // Mock prevents config write that test depends on!
  let mock_catalog = fn(_) { Ok(Nil) }

  add_server(config, mock_catalog)
  |> should.be_ok

  add_server(config, mock_catalog)  // Should error - but won't!
  |> should.be_ok
}
```

**Why this is wrong:**

- Mocked function had side effect test depended on (writing config)
- Over-mocking to "be safe" breaks actual behavior
- Test passes for wrong reason or fails mysteriously

**The fix:**

```gleam
// ✅ GOOD: Mock at correct level
pub fn detects_duplicate_server_test() {
  // Mock the slow part, preserve behavior test needs
  let mock_server_startup = fn(_) { Ok(Nil) }

  add_server(config)  // Config written
  |> should.be_ok

  add_server(config)  // Duplicate detected ✓
  |> should.be_error
}
```

### Gate Function

```
BEFORE mocking any function:
  STOP - Don't mock yet

  1. Ask: "What side effects does the real function have?"
  2. Ask: "Does this test depend on any of those side effects?"
  3. Ask: "Do I fully understand what this test needs?"

  IF depends on side effects:
    Mock at lower level (the actual slow/external operation)
    OR use test doubles that preserve necessary behavior
    NOT the high-level function the test depends on

  IF unsure what test depends on:
    Run test with real implementation FIRST
    Observe what actually needs to happen
    THEN add minimal mocking at the right level

  Red flags:
    - "I'll mock this to be safe"
    - "This might be slow, better mock it"
    - Mocking without understanding the dependency chain
```

## Anti-Pattern 4: Incomplete Mocks

**The violation:**

```gleam
// ❌ BAD: Partial mock - only fields you think you need
pub type MockResponse {
  MockResponse(
    status: String,
    data: UserData,
    // Missing: metadata that downstream code uses
  )
}

pub type UserData {
  UserData(user_id: String, name: String)
}

// Later: breaks when code accesses response.metadata.request_id
```

**Why this is wrong:**

- **Partial mocks hide structural assumptions** - You only mocked fields you know about
- **Downstream code may depend on fields you didn't include** - Silent failures
- **Tests pass but integration fails** - Mock incomplete, real API complete
- **False confidence** - Test proves nothing about real behavior

**The Iron Rule:** Mock the COMPLETE data structure as it exists in reality, not just fields your immediate test uses.

**The fix:**

```gleam
// ✅ GOOD: Mirror real API completeness
pub type ApiResponse {
  ApiResponse(
    status: String,
    data: UserData,
    metadata: Metadata,  // All fields real API returns
  )
}

pub type Metadata {
  Metadata(request_id: String, timestamp: Int)
}
```

### Gate Function

```
BEFORE creating mock responses:
  Check: "What fields does the real API response contain?"

  Actions:
    1. Examine actual API response from docs/examples
    2. Include ALL fields system might consume downstream
    3. Verify mock matches real response schema completely

  Critical:
    If you're creating a mock, you must understand the ENTIRE structure
    Partial mocks fail silently when code depends on omitted fields

  If uncertain: Include all documented fields
```

## Anti-Pattern 5: Integration Tests as Afterthought

**The violation:**

```
✅ Implementation complete
❌ No tests written
"Ready for testing"
```

**Why this is wrong:**

- Testing is part of implementation, not optional follow-up
- TDD would have caught this
- Can't claim complete without tests

**The fix:**

```
TDD cycle:
1. Write failing test
2. Implement to pass
3. Refactor
4. THEN claim complete
```

## When Mocks Become Too Complex

**Warning signs:**

- Mock setup longer than test logic
- Mocking everything to make test pass
- Mocks missing fields real types have
- Test breaks when mock changes

**your human partner's question:** "Do we need to be using a mock here?"

**Consider:** Integration tests with real components often simpler than complex mocks

## TDD Prevents These Anti-Patterns

**Why TDD helps:**

1. **Write test first** → Forces you to think about what you're actually testing
2. **Watch it fail** → Confirms test tests real behavior, not mocks
3. **Minimal implementation** → No test-only methods creep in
4. **Real dependencies** → You see what the test actually needs before mocking

**If you're testing mock behavior, you violated TDD** - you added mocks without watching test fail against real code first.

## Quick Reference

| Anti-Pattern                    | Fix                                           |
| ------------------------------- | --------------------------------------------- |
| Assert on mock elements         | Test real component or unmock it              |
| Test-only methods in production | Move to test utilities                        |
| Mock without understanding      | Understand dependencies first, mock minimally |
| Incomplete mocks                | Mirror real API completely                    |
| Tests as afterthought           | TDD - tests first                             |
| Over-complex mocks              | Consider integration tests                    |

## Red Flags

- Assertion checks for mock-specific fields
- Functions only called in test files
- Mock setup is >50% of test
- Test fails when you remove mock
- Can't explain why mock is needed
- Mocking "just to be safe"

## The Bottom Line

**Mocks are tools to isolate, not things to test.**

If TDD reveals you're testing mock behavior, you've gone wrong.

Fix: Test real behavior or question why you're mocking at all.
