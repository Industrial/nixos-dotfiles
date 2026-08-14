---
name: effect.ts-testing
description: >-
  Expert in testing Effect.ts code using Effect's built-in Layer-based dependency injection system.
  Never use vi.mock() or jest.mock() for Effect services - always use Effect's Layer system instead.
category: testing
displayName: Effect.ts Testing
color: purple
---

# Effect.ts Testing Skill

## Purpose

This skill teaches AI assistants how to properly test Effect.ts code using Effect's built-in dependency injection system. Effect.ts is a functional effect system for TypeScript that provides type-safe, composable effects with built-in dependency injection through Layers.

**Critical Rule**: **NEVER use `vi.mock()` or `jest.mock()` for Effect services**. Effect.ts has its own dependency injection system that must be used instead.

---

## Why This Matters

### The Problem with Traditional Mocking

Traditional test mocking tools (`vi.mock()`, `jest.mock()`) work by replacing entire modules at the module system level. This approach:

1. **Bypasses Effect's Dependency Injection**: Effect.ts uses a sophisticated Layer-based DI system that ensures type safety and proper service lifecycle management. Module-level mocks completely bypass this system.

2. **Causes Mock Leakage**: Module mocks are global and leak between test files, causing tests to fail unpredictably when run together vs. individually.

3. **Breaks Effect Services**: Empty mock objects (`HttpClientError: {}`) break Effect's service constructors like `RequestError` and `ResponseError`, causing runtime errors.

4. **Loses Type Safety**: Module mocks lose TypeScript's type checking, making it easy to create incorrect mocks.

### The Effect.ts Solution

Effect.ts provides **built-in dependency injection** through Layers. Each test provides its own dependencies, ensuring:
- ✅ **No mock leakage** - Each test is isolated
- ✅ **Type safety** - TypeScript ensures correct service types
- ✅ **Proper lifecycle** - Effect manages service creation and cleanup
- ✅ **Composability** - Layers can be combined and reused

---

## Core Principles

### 1. Never Mock Effect Services with vi.mock()

```typescript
// ❌ WRONG - This breaks Effect's DI system
vi.mock('@effect/platform', () => ({
  HttpClient: {
    HttpClient: Symbol.for('HttpClient'),
  },
  HttpClientError: {}, // Empty object breaks RequestError/ResponseError!
}))
```

**Why this is wrong:**
- Bypasses Effect's dependency injection
- Breaks `HttpClientError.RequestError` and `HttpClientError.ResponseError`
- Causes mock leakage across test files
- Not the way Effect.ts is designed to work

### 2. Use Effect's Layer System Instead

```typescript
// ✅ CORRECT - Use Effect's Layer system
import { HttpClient } from '@effect/platform'
import { Effect, Layer } from 'effect'

// Create a mock HttpClient
const mockHttpClient = HttpClient.make((request) => {
  return Effect.succeed({
    status: 200,
    json: Effect.succeed({ data: 'test' }),
    // ... other required fields
  })
})

// Provide it using Effect's DI
const mockLayer = Layer.succeed(HttpClient.HttpClient, mockHttpClient)

const result = await Effect.runPromise(
  myEffectProgram.pipe(
    Effect.provide(mockLayer)
  )
)
```

**Why this is correct:**
- Uses Effect's built-in dependency injection
- Each test provides its own layers - no leakage
- Type-safe - TypeScript ensures correct types
- Properly integrates with Effect's service system

---

## Testing Patterns

### Pattern 1: Mocking HttpClient

#### Creating a Mock HttpClient

```typescript
import { HttpClient, HttpClientError } from '@effect/platform'
import { Effect } from 'effect'

// Helper to create a mock HttpClient with all required methods
function createMockHttpClient(
  getImpl: (
    url: string,
    options?: unknown,
  ) => Effect.Effect<
    { json: Effect.Effect<unknown> },
    HttpClientError.HttpClientError
  >,
): HttpClient.HttpClient {
  const noopEffect = Effect.succeed({ json: Effect.succeed({}) })
  return {
    get: getImpl,
    // Provide stub implementations for other required methods
    head: () => noopEffect,
    post: () => noopEffect,
    put: () => noopEffect,
    patch: () => noopEffect,
    delete: () => noopEffect,
    options: () => noopEffect,
    execute: () => noopEffect,
    request: () => noopEffect,
    requestWith: () => noopEffect,
    stream: () => noopEffect,
    streamWith: () => noopEffect,
  } as unknown as HttpClient.HttpClient
}
```

#### Using the Mock in Tests

```typescript
import { HttpClient } from '@effect/platform'
import { Effect, Layer } from 'effect'
import { getWalletRiskScore } from './getWalletRiskScore'

describe('getWalletRiskScore', () => {
  it('should return data on successful request', async () => {
    const mockResponseData = { totalFunds: 45 }
    
    const mockHttpClient = createMockHttpClient(
      (_url: string, _options?: unknown) => {
        return Effect.succeed({
          json: Effect.succeed(mockResponseData),
        })
      },
    )

    // ✅ Use Effect's Layer system
    const mockLayer = Layer.succeed(HttpClient.HttpClient, mockHttpClient)
    const result = await Effect.runPromise(
      getWalletRiskScore('0x123...').pipe(
        Effect.provide(mockLayer),
      ),
    )

    expect(result).toEqual(mockResponseData)
  })
})
```

### Pattern 2: Testing Error Cases

```typescript
it('should handle HTTP errors', async () => {
  const mockError = new HttpClientError.RequestError({
    request: {} as any,
    reason: 'Transport',
    cause: new Error('Network error'),
  } as any)

  const mockHttpClient = createMockHttpClient(
    (_url: string, _options?: unknown) => {
      return Effect.fail(mockError)
    },
  )

  const mockLayer = Layer.succeed(HttpClient.HttpClient, mockHttpClient)
  
  await expect(
    Effect.runPromise(
      getWalletRiskScore('0x123...').pipe(
        Effect.provide(mockLayer),
      ),
    ),
  ).rejects.toThrow()
})
```

### Pattern 3: Testing with Retry Logic

**Important**: If your Effect program has retry logic, it will retry on failures. For fast unit tests, you may want to create a version without retry:

```typescript
// Production code has retry logic
export const getWalletRiskScore = (address: string) =>
  pipe(
    Effect.gen(function* () {
      const client = yield* HttpClient.HttpClient
      const response = yield* client.get(url).pipe(
        Effect.timeout('10 seconds'),
        Effect.retry({
          schedule: Schedule.exponential(1000),
          times: 3, // This would take ~7 seconds in tests!
        }),
      )
      return yield* response.json
    }),
  )

// For fast error testing, create a helper without retry
function getWalletRiskScoreNoRetry(address: string) {
  return Effect.gen(function* () {
    const client = yield* HttpClient.HttpClient
    const response = yield* client.get(url)
    // Skip retry/timeout for error testing
    if (response.status < 200 || response.status >= 300) {
      throw new HttpClientError.ResponseError({...})
    }
    return yield* response.json
  })
}
```

### Pattern 4: Using FetchHttpClient.layer in Production Code

In production code, don't create HttpClient manually. Use Effect's `FetchHttpClient.layer`:

```typescript
// ❌ WRONG - Creating HttpClient manually
const httpClient = HttpClient.make((request, url) => {
  // 100+ lines of manual fetch implementation
})

const response = await Effect.runPromise(
  Effect.provideService(
    getWalletRiskScore(walletAddress),
    HttpClient.HttpClient,
    httpClient,
  ),
)

// ✅ CORRECT - Use FetchHttpClient.layer
import { FetchHttpClient } from '@effect/platform'
import { Effect } from 'effect'

const response = await Effect.runPromise(
  getWalletRiskScore(walletAddress).pipe(
    Effect.provide(FetchHttpClient.layer),
  ),
)
```

### Pattern 5: Creating `<Thing>Mock.ts` Files for Service Mocks

**Best Practice**: Create dedicated mock files next to your service files using the `<Thing>Mock.ts` naming pattern. This keeps mocks co-located with services and makes them easy to discover and maintain.

#### File Structure

```
src/
  db/
    Database.ts          # Service definition
    DatabaseMock.ts      # Mock implementation
  services/
    HttpClient.ts        # Service definition
    HttpClientMock.ts    # Mock implementation (if needed)
```

#### Example: DatabaseMock.ts Pattern

Create `DatabaseMock.ts` next to `Database.ts`:

```typescript
/**
 * Mock implementation of DatabaseService for testing.
 * Follows Effect.ts testing patterns - creates real mock objects, not vi.fn() mocks.
 * 
 * This mock provides a queue-based system where query results are queued and
 * consumed sequentially. This allows tests to control database responses without
 * using module-level mocks.
 */

import { makeDatabaseService, type DatabaseService } from './Database'
import type { Database as DrizzleDatabase } from './client'

/**
 * Creates a mock database service that implements the DatabaseService interface.
 * Results are provided via a queue - each query consumes the next result from the queue.
 * This follows Effect.ts testing patterns - real objects provided via Layers.
 * 
 * @returns An object containing the mock database service and control functions
 */
export function createMockDatabase(): {
  databaseService: DatabaseService
  addQueryResult: (results: unknown[]) => void
  clearResults: () => void
} {
  // Queue of results - queries consume from front of queue
  const resultQueue: unknown[][] = []

  const addQueryResult = (results: unknown[]) => {
    resultQueue.push(results)
  }

  const clearResults = () => {
    resultQueue.length = 0
  }

  const getNextResult = (): unknown[] => {
    return resultQueue.shift() || []
  }

  // Create a mock Drizzle database client that implements the query builder pattern
  const db: DrizzleDatabase = {
    select: () => {
      return {
        from: (_table: unknown) => {
          return {
            where: (_condition: unknown) => {
              const result = getNextResult()
              const promise = Promise.resolve(result)
              return {
                limit: (_n: number) => promise,
                then: promise.then.bind(promise),
                catch: promise.catch.bind(promise),
                finally: promise.finally.bind(promise),
              } as any
            },
            limit: (_n: number) => Promise.resolve(getNextResult()),
            then: (resolve: any, reject?: any) => {
              Promise.resolve(getNextResult()).then(resolve, reject)
            },
            catch: (reject: any) => Promise.resolve(getNextResult()).catch(reject),
            finally: (fn: any) => Promise.resolve(getNextResult()).finally(fn),
          } as any
        },
      } as any
    },
    // ... other methods (insert, update, delete)
  } as any as DrizzleDatabase

  const databaseService = makeDatabaseService(db)

  return {
    databaseService,
    addQueryResult,
    clearResults,
  }
}
```

#### Using the Mock in Tests

```typescript
import { Database, createMockDatabase } from '@idclear/database'
import { beforeEach, describe, expect, it } from 'bun:test'
import { Effect, Layer } from 'effect'
import { findRiskScoreEffect } from './findRiskScore'

describe('findRiskScore', () => {
  const { databaseService, addQueryResult, clearResults } = createMockDatabase()

  // Create mock database layer
  const mockDatabaseLayer = Layer.succeed(Database, databaseService)

  beforeEach(() => {
    clearResults()
  })

  it('should return score when found', async () => {
    const mockScore = {
      id: 'score-1',
      categoryId: 'cat-1',
      riskOption: 'option-1',
      score: '50',
      // ... other fields
    }

    // Queue query results - consumed sequentially
    addQueryResult([mockScore])

    const result = await Effect.runPromise(
      findRiskScoreEffect('cat-1', 'option-1', null, null).pipe(
        Effect.provide(mockDatabaseLayer),
      ),
    )

    expect(result).toEqual(mockScore)
  })

  it('should handle multiple queries', async () => {
    // First query returns empty (no client-specific)
    addQueryResult([])
    // Second query returns global score
    addQueryResult([{ id: 'score-2', score: '30' }])

    const result = await Effect.runPromise(
      findRiskScoreEffect('cat-1', 'option-1', 'client-1', 'Individual').pipe(
        Effect.provide(mockDatabaseLayer),
      ),
    )

    expect(result).toBeDefined()
  })
})
```

#### Benefits of the `<Thing>Mock.ts` Pattern

1. **Co-location**: Mocks live next to the services they mock, making them easy to find
2. **Consistency**: Standardized naming pattern (`<Thing>Mock.ts`) makes mocks discoverable
3. **Reusability**: One mock implementation can be used across all tests for that service
4. **Type Safety**: Mocks implement the same service interface, ensuring type compatibility
5. **No Module Mocking**: Avoids `vi.mock()` entirely - uses Effect's Layer system
6. **Queue-Based**: Sequential query results make complex test scenarios easy to model

#### Guidelines for Creating Mock Files

1. **Naming**: Use `<ServiceName>Mock.ts` (e.g., `DatabaseMock.ts`, `ConfigMock.ts`)
2. **Location**: Place next to the service file (e.g., `Database.ts` and `DatabaseMock.ts` in same directory)
3. **Export Pattern**: Export `createMock<ServiceName>()` function
4. **Return Value**: Return object with:
   - The mock service (implements the service interface)
   - Control functions (`addQueryResult`, `clearResults`, etc.)
5. **Queue-Based**: For services with sequential operations, use a queue-based approach
6. **Documentation**: Include usage examples in JSDoc comments

#### Real-World Example

See `apps/risk-calculator/src/db/DatabaseMock.ts` for a complete implementation:
- ✅ Co-located with `Database.ts`
- ✅ Queue-based query results
- ✅ No `vi.fn()` mocks
- ✅ Uses Effect's Layer system
- ✅ Well-documented with usage examples

---

## Common Mistakes

### Mistake 1: Using vi.mock() for Effect Services

```typescript
// ❌ WRONG
vi.mock('@effect/platform', () => ({
  HttpClientError: {},
}))
```

**Fix**: Remove the mock and use Effect's Layer system instead.

### Mistake 2: Empty Mock Objects

```typescript
// ❌ WRONG - Empty object breaks constructors
HttpClientError: {}
```

**Fix**: Don't mock Effect services at all. Use Layers.

### Mistake 3: Creating HttpClient Manually

```typescript
// ❌ WRONG - Bypasses Effect's DI
const httpClient = HttpClient.make((request, url) => {
  // Manual implementation
})
```

**Fix**: Use `FetchHttpClient.layer` or provide a mock via Layers.

### Mistake 4: Using Effect.provideService Instead of Layers

```typescript
// ⚠️ Works but not idiomatic
Effect.provideService(
  program,
  HttpClient.HttpClient,
  mockHttpClient,
)

// ✅ Better - Use Layers (idiomatic Effect.ts)
program.pipe(
  Effect.provide(Layer.succeed(HttpClient.HttpClient, mockHttpClient))
)
```

---

## Migration Guide

### Step 1: Remove vi.mock() Calls

```typescript
// Before
vi.mock('@effect/platform', () => ({
  HttpClient: { HttpClient: Symbol.for('HttpClient') },
  HttpClientError: {},
}))
```

```typescript
// After - Remove entirely
// Effect.ts has built-in dependency injection through Layers.
// Mocking @effect/platform with vi.mock() breaks Effect's DI system.
// Use Effect's Layer system in tests that need HttpClient instead.
```

### Step 2: Import Effect and Layer

```typescript
import { HttpClient } from '@effect/platform'
import { Effect, Layer } from 'effect'
```

### Step 3: Create Mock HttpClient

```typescript
const mockHttpClient = createMockHttpClient(
  (url: string, options?: unknown) => {
    return Effect.succeed({
      json: Effect.succeed(mockData),
    })
  },
)
```

### Step 4: Provide Mock via Layer

```typescript
const mockLayer = Layer.succeed(HttpClient.HttpClient, mockHttpClient)
const result = await Effect.runPromise(
  myProgram.pipe(Effect.provide(mockLayer))
)
```

---

## Verification Checklist

When testing Effect.ts code, verify:

- [ ] No `vi.mock('@effect/platform')` or similar calls
- [ ] Using `Layer.succeed()` to create mock layers
- [ ] Using `Effect.provide()` to inject dependencies
- [ ] Each test provides its own layers (no shared state)
- [ ] Mock HttpClient includes all required methods
- [ ] Error cases use `Effect.fail()` with proper error types
- [ ] Production code uses `FetchHttpClient.layer` (not manual HttpClient)
- [ ] Custom service mocks follow `<Thing>Mock.ts` pattern (co-located with service files)
- [ ] Mock files export `createMock<Thing>()` functions with clear control APIs

---

## Real-World Examples

### Example 1: HttpClient Testing

See `apps/risk-calculator/src/util/getWalletRiskScore.test.ts` for a complete example:

1. ✅ No `vi.mock('@effect/platform')`
2. ✅ Uses `Layer.succeed()` for mocks
3. ✅ Uses `Effect.provide()` for dependency injection
4. ✅ Tests both success and error cases
5. ✅ Fast tests (no retry delays in error tests)

### Example 2: Database Service Mock Pattern

See `apps/risk-calculator/src/db/DatabaseMock.ts` and `apps/risk-calculator/src/util/findRiskScore.test.ts`:

1. ✅ `<Thing>Mock.ts` pattern - `DatabaseMock.ts` co-located with `Database.ts`
2. ✅ Queue-based query results for sequential operations
3. ✅ No `vi.fn()` mocks - uses real objects via Effect Layers
4. ✅ `createMockDatabase()` function with clear control API
5. ✅ Tests use `Layer.succeed(Database, databaseService)` for dependency injection

---

## Key Takeaways

1. **Effect.ts has built-in dependency injection** - Don't bypass it with module mocks
2. **Use Layers, not vi.mock()** - `Layer.succeed()` and `Effect.provide()` are the correct way
3. **Each test is isolated** - Layers prevent mock leakage between tests
4. **Type-safe** - Effect's DI system maintains TypeScript type safety
5. **Production code** - Use `FetchHttpClient.layer`, don't create HttpClient manually
6. **Mock files pattern** - Create `<Thing>Mock.ts` files next to service files for reusable, co-located mocks
7. **Queue-based mocks** - For sequential operations, use queue-based systems for predictable test behavior

---

## References

- Effect.ts Documentation: https://effect.website/
- Effect Platform: https://effect.website/docs/platform/
- Layer System: https://effect.website/docs/guides/layer/
- Testing Guide: https://effect.website/docs/guides/testing/

---

## Related Skills

- `effect.ts-fundamentals` - Effect as value, pipe/flatMap, FP data types
- `effect.ts-architect` - Layers, Services, dependency injection
- `typescript-expert` - TypeScript best practices
- `error-handling-patterns` - Error handling strategies
- `systematic-debugging` - Debugging techniques

---

**Remember**: Effect.ts is a well-tested library. The problem is never with Effect.ts itself - it's with how we're testing it. Always use Effect's Layer system for dependency injection in tests.
