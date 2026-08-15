# Workflow Management for API Migrations

Managing API migrations (like id_effect v2→v3) benefits from structured workflows. Consider adapting principles from systems like Industrial Delivery (ID):

## Workflow Approach

1. **ORIENT**: Understand scope
   - List all breaking changes from migration guide
   - Search codebase for occurrences of old APIs
   - Identify affected modules and test files

2. **RESEARCH**: Investigate solutions
   - For each breaking change, study recommended replacements
   - Look for similar fixes in related code or dependencies
   - Check for utility functions or wrappers that could help

3. **PLAN**: Create fix strategy
   - Group similar fixes (e.g., all `logger_only_env()` → `logger_caps()`)
   - Create tracking issue or task list
   - Estimate effort per file/group
   - Identify risky changes needing extra testing

4. **EXECUTE**: Implement fixes
   - Work in small, testable batches
   - Run tests after each group of changes
   - Use compiler errors as guidance for missed occurrences
   - Record evidence of fixes (before/after snippets, test results)

5. **REVIEW**: Verify completeness
   - Search for any remaining old API usage
   - Run full test suite
   - Check for regressions in related functionality
   - Get review on changes

6. **SHIP**: Submit changes
   - Ensure all tests pass
   - Update documentation if needed
   - Create pull request with clear migration notes

## Tracking Progress

- Use task tracking (Maestro, GitHub issues, or similar) to:
  - List each breaking change pattern to fix
  - Track status: TODO, IN PROGRESS, FIXED, VERIFIED
  - Link to specific code changes or commits
  - Record verification steps and results

## Evidence Recording

For each fix or group of fixes:
- Record what was changed (files, lines)
- Record verification (test results, build output)
- Note any complications or workarounds
- This creates an audit trail and helps with review

This approach ensures nothing is missed and provides confidence in the migration's completeness.