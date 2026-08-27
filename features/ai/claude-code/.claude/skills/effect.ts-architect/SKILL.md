---
name: effect.ts-architect
description: >-
  Expert in Effect.ts architecture, design patterns, and best practices for building
  production-grade TypeScript applications using Effect's functional effect system.
  Covers dependency injection, error handling, composition, and integration patterns.
category: framework
displayName: Effect.ts Architect
color: purple
---

# Effect.ts Architecture Skill

## Purpose

This skill teaches AI assistants how to architect and build production-grade TypeScript applications using Effect.ts, a functional effect system that provides type-safe, composable effects with built-in dependency injection, error handling, and resource management.

**Core Philosophy**: Effect.ts enables **explicit dependency management**, **type-safe error handling**, and **composable program construction** through its Layer-based dependency injection system.

---

## Core Concepts

### 1. Effect: The Foundation

An `Effect` represents a computation that may:
- **Succeed** with a value of type `A`
- **Fail** with an error of type `E`
- **Require** services/dependencies of type `R`
- **Perform** side effects (IO, async operations, etc.)

```typescript
type Effect<A, E, R> = {
  // A = Success value type
  // E = Error type
  // R = Required services (dependencies)
}
```

### 2. Context: Dependency Requirements

The `R` type parameter represents **required services** (dependencies). Effect uses a Context system to manage these dependencies.

**Use the Tag type directly in `R`, not `typeof Tag`:**

```typescript
// ✅ GOOD - Use the Tag type (e.g. UsersServiceTag) in the requirement union
const program: Effect.Effect<Data, MyError, UsersServiceTag | DatabaseService> = ...

// ❌ BAD - Don't use typeof for requirement types
const program: Effect.Effect<Data, MyError, typeof UsersServiceTag | DatabaseService> = ...
```

When you provide the layer, `R` becomes `never`:

```typescript
const provided: Effect.Effect<Data, Error, never> = program.pipe(
  Effect.provide(HttpClientLayer)
)
```

### 3. Layer: Dependency Injection

**Layers** are the primary mechanism for dependency injection in Effect.ts. They:
- Define how to create services
- Can depend on other services
- Are composable and reusable
- Manage service lifecycle

**Layer Type Structure**:
```typescript
Layer<RequirementsOut, Error, RequirementsIn>
```

- `RequirementsOut`: The service(s) this layer produces
- `Error`: Possible errors during layer construction
- `RequirementsIn`: Dependencies this layer needs to construct the service

**Naming Conventions**:
- `Live` suffix for production implementations (e.g., `DatabaseLive`, `HttpClientLive`)
- `Test` suffix for test implementations (e.g., `DatabaseTest`, `HttpClientTest`)

**File and entity placement**:
- **One service (Tag) per file**: Put the `Context.Tag` definition in a file named after the service in **PascalCase** (e.g. `InferOrgsMainName.ts`, `InferEntitiesStreams.ts`). Export the Tag class and any types used by the interface (e.g. `UserMainNamePair`, `OrgRow`).
- **Live layer in a separate file**: Put the production implementation in a file named **`<ServiceName>Live.ts`** (e.g. `InferOrgsMainNameLive.ts`). This keeps the port (Tag + interface) separate from the adapter (Live implementation).
- **Avoid “Effect” in file names**: Prefer capability-based names (`InferOrgsMainName`, `InferUsersMainName`, `InferEntitiesStreams`) over names that mention “Effect” (e.g. avoid `inferOrgsMainNameEffect.ts`). The fact that the API returns `Effect`/`Stream` is implied.
- **Stream helpers as a service**: When you have paginated or entity streams used by multiple use cases, expose them via a dedicated service (e.g. `InferEntitiesStreams` with `streamOfOrganizations` / `streamOfUsers`) rather than free functions in a “streams” file. Callers then depend on the service and stay testable.

```typescript
// Layer with no dependencies (simplest case)
const ConfigLive = Layer.succeed(
  Config.Config,
  { apiKey: process.env.API_KEY }
)
// Type: Layer<Config, never, never>

// Or use built-in layers
import { FetchHttpClient } from '@effect/platform'
const HttpClientLayer = FetchHttpClient.layer
// Type: Layer<HttpClient, never, never>
```

### 4. Services: Type-Safe Dependencies

Services are accessed via `yield*` in Effect.gen:

```typescript
const program = Effect.gen(function* () {
  // Access HttpClient service from context
  const client = yield* HttpClient.HttpClient
  
  // Use the service
  const response = yield* client.get('https://api.example.com')
  return yield* response.json
})
```

---

## Architectural Patterns

### Pattern 1: Pure Effect Functions

**Best Practice**: Write functions that return Effects, not async functions that create Effects internally.

```typescript
// ✅ GOOD - Returns Effect, caller provides dependencies
export const getWalletRiskScore = (
  address: string,
): Effect.Effect<
  unknown,
  HttpClientError.HttpClientError | TimeoutException,
  HttpClient.HttpClient
> =>
  pipe(
    Effect.gen(function* () {
      const client = yield* HttpClient.HttpClient
      const response = yield* client.get(url).pipe(
        Effect.timeout('10 seconds'),
        Effect.retry({ schedule: Schedule.exponential(1000), times: 3 }),
      )
      return yield* response.json
    }),
    Effect.withSpan('getWalletRiskScore', { attributes: { address } }),
  )

// ❌ BAD - Creates dependencies internally, harder to test
export async function getWalletRiskScore(address: string) {
  const httpClient = HttpClient.make(...) // Hard to mock!
  return await Effect.runPromise(
    Effect.provideService(program, HttpClient.HttpClient, httpClient)
  )
}
```

**Why**: Pure Effect functions are:
- Easier to test (provide mock dependencies)
- More composable (can be combined with other Effects)
- Type-safe (dependencies are explicit in type signature)

### Pattern 2: Avoiding Requirement Leakage

**Critical Principle**: Service interfaces should **NOT** expose dependencies. Service operations should have `R = never` in their type signatures. Dependencies are managed at the **Layer construction level**, not the service level.

```typescript
// ❌ BAD - Leaks dependencies in service interface
class Database extends Context.Tag("Database")<
  Database,
  {
    readonly query: (sql: string) => Effect.Effect<unknown, never, Config | Logger>
  }
>()

// This forces tests to provide Config and Logger even when testing Database
const test = Effect.gen(function* () {
  const db = yield* Database
  const result = yield* db.query("SELECT * FROM users")
  // Now requires Config | Logger even though we're just testing Database!
})

// ✅ GOOD - Service interface has no dependencies
class Database extends Context.Tag("Database")<
  Database,
  {
    readonly query: (sql: string) => Effect.Effect<unknown>  // R = never
  }
>()

// Dependencies are managed in the Layer, not the service
const DatabaseLive = Layer.effect(
  Database,
  Effect.gen(function* () {
    const config = yield* Config  // Dependency accessed here
    const logger = yield* Logger   // Dependency accessed here
    return {
      query: (sql: string) => Effect.gen(function* () {
        yield* logger.log(`Executing: ${sql}`)
        // Use config, logger internally
        return { result: 'data' }
      })
    }
  })
)
// Type: Layer<Database, never, Config | Logger>

// Now tests can provide Database without Config/Logger
const test = Effect.gen(function* () {
  const db = yield* Database
  const result = yield* db.query("SELECT * FROM users")
  // Only requires Database, not Config | Logger
})
```

**Why**: This architectural principle:
- Keeps service interfaces clean and focused
- Makes services easier to test (no need to provide unrelated dependencies)
- Prevents dependency leakage throughout the codebase
- Enables better composition and reuse

### Pattern 3: Layer Composition

**Best Practice**: Compose layers to build your application's dependency graph. Understand when to **merge** vs **compose** layers.

#### Creating Layers with Dependencies

Use `Layer.effect` when a service depends on other services:

```typescript
import { Layer, Effect } from 'effect'

// Layer with no dependencies
const ConfigLive = Layer.succeed(
  Config.Config,
  { apiKey: process.env.API_KEY }
)
// Type: Layer<Config, never, never>

// Layer that depends on Config
const LoggerLive = Layer.effect(
  Logger.Logger,
  Effect.gen(function* () {
    const config = yield* Config.Config  // Access dependency
    return {
      log: (message: string) => Effect.gen(function* () {
        const { logLevel } = yield* config.getConfig
        console.log(`[${logLevel}] ${message}`)
      })
    }
  })
)
// Type: Layer<Logger, never, Config>

// Layer that depends on both Config and Logger
const DatabaseLive = Layer.effect(
  Database.Database,
  Effect.gen(function* () {
    const config = yield* Config.Config
    const logger = yield* Logger.Logger
    return {
      query: (sql: string) => Effect.gen(function* () {
        yield* logger.log(`Executing: ${sql}`)
        // Use config, logger internally
        return { result: 'data' }
      })
    }
  })
)
// Type: Layer<Database, never, Config | Logger>
```

#### Merging vs Composing Layers

**Merging** (`Layer.merge` / `Layer.mergeAll`): Combines layers **concurrently**
- Both outputs and inputs are combined (union types)
- Used when layers don't depend on each other
- Layers run in parallel

```typescript
// Merge layers that don't depend on each other
const AppConfigLive = Layer.mergeAll(
  ConfigLive,      // Layer<Config, never, never>
  HttpClientLive   // Layer<HttpClient, never, never>
)
// Type: Layer<Config | HttpClient, never, never>
```

**Composing** (`Layer.provide`): **Sequential** composition
- Output of one layer feeds into input of another
- Used when one layer depends on another
- Resolves dependency graph

```typescript
// Compose layers: DatabaseLive depends on Config | Logger
// First merge Config and Logger (they don't depend on each other)
const AppConfigLive = Layer.mergeAll(
  ConfigLive,   // Layer<Config, never, never>
  LoggerLive    // Layer<Logger, never, Config>
)
// Type: Layer<Config | Logger, never, Config>

// Then provide AppConfigLive to DatabaseLive
const MainLive = DatabaseLive.pipe(
  Layer.provide(AppConfigLive),  // Provides Config | Logger
  Layer.provide(ConfigLive)      // Provides Config (needed by LoggerLive)
)
// Type: Layer<Database, never, never> - fully resolved!
```

**Complete Example**:

```typescript
import { Layer, Effect } from 'effect'
import { FetchHttpClient } from '@effect/platform'

// Base layers (no dependencies)
const ConfigLive = Layer.succeed(Config.Config, { apiKey: 'key' })
const HttpClientLive = FetchHttpClient.layer

// Dependent layers
const LoggerLive = Layer.effect(
  Logger.Logger,
  Effect.gen(function* () {
    const config = yield* Config.Config
    return { log: (msg: string) => console.log(msg) }
  })
)
// Type: Layer<Logger, never, Config>

const DatabaseLive = Layer.effect(
  Database.Database,
  Effect.gen(function* () {
    const logger = yield* Logger.Logger
    return { query: (sql: string) => Effect.succeed([]) }
  })
)
// Type: Layer<Database, never, Logger>

// Build dependency graph
const AppLayer = DatabaseLive.pipe(
  Layer.provide(LoggerLive),      // Provides Logger to DatabaseLive
  Layer.provide(ConfigLive),       // Provides Config to LoggerLive
  Layer.provideMerge(HttpClientLive) // Also includes HttpClientLive
)
// Type: Layer<Database | HttpClient, never, never>

// Use in application
const program = Effect.gen(function* () {
  const db = yield* Database.Database
  const client = yield* HttpClient.HttpClient
  // ... use services
})

const result = await Effect.runPromise(
  program.pipe(Effect.provide(AppLayer))
)
```

**Why**: Layer composition:
- Makes dependencies explicit in type signatures
- Enables easy swapping (test vs production)
- Ensures all dependencies are provided
- Type-safe dependency resolution

### Pattern 4: Error Handling with Effect

**Best Practice**: Use Effect's error types, not try/catch. **Define error types clearly and verbosely**—avoid a single generic `Error` or opaque union; list concrete error types so callers can handle or map them.

```typescript
// ✅ GOOD - Explicit, verbose error types in the signature
export const getWalletRiskScore = (
  address: string,
): Effect.Effect<
  unknown,
  HttpClientError.HttpClientError | TimeoutException, // Explicit error types
  HttpClient.HttpClient
> => ...

// ❌ BAD - Vague error type (generic Error or broad union)
export const doSomething = (): Effect.Effect<Data, Error, R> => ...
```

Specify the error union **on the Effect itself** (inline), not as a separate named type:

```typescript
// ✅ GOOD - Error union specified directly on the Effect
export const getUser = (
  id: string,
): Effect.Effect<
  User,
  UserNotFoundError | ValidationError | DatabaseConnectionError,
  DatabaseService
> => ...

// Handle errors with Effect combinators
const program = getWalletRiskScore(address).pipe(
  Effect.catchAll((error) => {
    if (error instanceof HttpClientError.RequestError) {
      return Effect.succeed(defaultValue)
    }
    return Effect.fail(error)
  }),
  Effect.retry({ times: 3 }),
  Effect.timeout('10 seconds')
)
```

**Why**: Effect's error handling:
- Type-safe (errors are in type signature)
- Composable (can chain error handlers)
- Explicit (no hidden exceptions)

### Pattern 4: Integration with Async Code

**Best Practice**: Convert async functions to Effects at boundaries, not internally.

```typescript
// ✅ GOOD - Convert at the boundary
export const calculateRiskProfileScore = (
  primaryRiskScoreId: string,
  additionalData: Record<string, any> = {},
): Effect.Effect<number, Error, HttpClient.HttpClient> =>
  Effect.gen(function* () {
    // Use Effect-based functions
    const walletScore = yield* getWalletRiskScore(additionalData.walletAddress)
    // ... rest of logic
    return finalScore
  })

// ❌ BAD - Mixing async/await with Effect internally
export async function calculateRiskProfileScore(...) {
  try {
    const response = await Effect.runPromise(
      getWalletRiskScore(walletAddress).pipe(
        Effect.provide(FetchHttpClient.layer)
      )
    )
    // ... rest of logic
  } catch (error) {
    // Error handling
  }
}
```

**Why**: Keep Effect boundaries clean:
- Easier to test (all dependencies explicit)
- Better composition (can combine with other Effects)
- Type-safe error handling

### Pattern 6: Resource Management

**Best Practice**: Use Effect's resource management for cleanup.

```typescript
import { Effect, Scope } from 'effect'

// Effect.acquireUseRelease ensures cleanup
const program = Effect.gen(function* () {
  const resource = yield* Effect.acquireUseRelease(
    acquireResource(), // Create resource
    (resource) => useResource(resource), // Use resource
    (resource) => cleanupResource(resource), // Cleanup (always runs)
  )
  return resource
})
```

**Why**: Effect ensures:
- Resources are always cleaned up
- Cleanup runs even on errors
- Type-safe resource management

---

## Dependency Injection Patterns

### Pattern 1: Service Access with yield*

```typescript
// Access services in Effect.gen
const program = Effect.gen(function* () {
  const client = yield* HttpClient.HttpClient
  const db = yield* Database.Database
  const config = yield* Config.Config
  
  // Use services
  const data = yield* db.query('SELECT * FROM users')
  return data
})
```

### Pattern 2: Creating Layers

#### Layer.succeed: Services with No Dependencies

```typescript
// Create a layer for a service with no dependencies
const ConfigLayer = Layer.succeed(
  Config.Config,
  { apiKey: process.env.API_KEY }
)
// Type: Layer<Config, never, never>

const MockHttpClientLayer = Layer.succeed(
  HttpClient.HttpClient,
  createMockHttpClient()
)
// Type: Layer<HttpClient, never, never>
```

#### Layer.effect: Services with Dependencies

```typescript
// Create a layer that depends on other services
const LoggerLive = Layer.effect(
  Logger.Logger,
  Effect.gen(function* () {
    const config = yield* Config.Config  // Access dependency
    return {
      log: (message: string) => Effect.gen(function* () {
        const { logLevel } = yield* config.getConfig
        console.log(`[${logLevel}] ${message}`)
      })
    }
  })
)
// Type: Layer<Logger, never, Config>

// Provide layer to program
const result = await Effect.runPromise(
  program.pipe(
    Effect.provide(LoggerLive),
    Effect.provide(ConfigLayer)  // Must provide Config first
  )
)
```

### Pattern 3: Merging vs Composing Layers

```typescript
// MERGING: Combine independent layers concurrently
const IndependentLayers = Layer.mergeAll(
  HttpClientLayer,  // Layer<HttpClient, never, never>
  ConfigLayer       // Layer<Config, never, never>
)
// Type: Layer<HttpClient | Config, never, never>

// COMPOSING: Resolve dependency graph sequentially
const DependentLayer = LoggerLive.pipe(
  Layer.provide(ConfigLayer)  // Provides Config to LoggerLive
)
// Type: Layer<Logger, never, never> - Config dependency resolved

// COMBINED: Merge and compose together
const AppLayer = DatabaseLive.pipe(
  Layer.provide(LoggerLive),      // Provides Logger to DatabaseLive
  Layer.provide(ConfigLayer),     // Provides Config to LoggerLive
  Layer.provideMerge(HttpClientLayer)  // Also includes HttpClient
)
// Type: Layer<Database | HttpClient, never, never>
```

### Pattern 4: Conditional Dependencies

```typescript
// Provide different layers based on environment
const getAppLayer = () => {
  if (process.env.NODE_ENV === 'test') {
    return Layer.mergeAll(MockHttpClientLayer, MockDatabaseLayer)
  }
  return Layer.mergeAll(FetchHttpClient.layer, RealDatabaseLayer)
}
```

### Pattern 5: Layer Error Handling

Layers can fail during construction. Handle errors at the layer level:

#### Layer.catchAll: Recover from Errors

```typescript
const ServerLayer = Layer.effect(
  HTTPServer,
  Effect.gen(function* () {
    const host = yield* Config.string("HOST")  // May fail if missing
    console.log(`Listening on http://localhost:${host}`)
  })
).pipe(
  Layer.catchAll((error) => {
    // Fallback to default layer if HOST config is missing
    return Layer.effect(
      HTTPServer,
      Effect.gen(function* () {
        console.log("Listening on http://localhost:3000")
      })
    )
  })
)
```

#### Layer.orElse: Fallback to Alternative Layer

```typescript
const DatabaseLayer = PostgresDatabaseLayer.pipe(
  Layer.orElse(() => InMemoryDatabaseLayer)  // Fallback if Postgres fails
)
```

#### Layer.tap: Side Effects During Acquisition

```typescript
const ServerLayer = Layer.effect(HTTPServer, ...).pipe(
  Layer.tap((ctx) => 
    Console.log("Server layer acquired successfully")
  ),
  Layer.tapError((err) => 
    Console.log(`Server layer failed: ${err}`)
  )
)
```

**Why**: Layer error handling:
- Allows graceful degradation (fallback layers)
- Enables logging/monitoring during layer construction
- Provides type-safe error recovery

---

## Error Handling Patterns

### Pattern 1: Explicit Error Types

```typescript
// Define errors as a union directly on the Effect signature
const program: Effect.Effect<
  Data,
  HttpClientError.HttpClientError | DatabaseError | ValidationError,
  HttpClient.HttpClient
> = ...
```

### Pattern 2: Error Recovery

```typescript
// Recover from specific errors
program.pipe(
  Effect.catchTag('HttpClientError', (error) => {
    // Handle HTTP errors
    return Effect.succeed(defaultValue)
  }),
  Effect.catchAll((error) => {
    // Handle all other errors
    return Effect.fail(error)
  })
)
```

### Pattern 3: Retry Logic

```typescript
import { Schedule } from 'effect'

// Retry with exponential backoff
program.pipe(
  Effect.retry({
    schedule: Schedule.exponential(1000), // Start at 1 second
    times: 3, // Retry 3 times
  })
)

// Retry with custom schedule
program.pipe(
  Effect.retry({
    schedule: Schedule.recurs(5), // Retry 5 times
    while: (error) => error instanceof HttpClientError.RequestError,
  })
)
```

### Pattern 4: Timeout

```typescript
// Add timeout to operations
program.pipe(
  Effect.timeout('10 seconds'),
  Effect.timeoutTo({
    duration: '5 seconds',
    onTimeout: () => Effect.fail(new TimeoutError()),
  })
)
```

---

## Composition Patterns

### Pattern 1: Sequential Composition

```typescript
// Chain Effects sequentially
const program = Effect.gen(function* () {
  const user = yield* getUser(userId)
  const profile = yield* getProfile(user.id)
  const settings = yield* getSettings(profile.id)
  return { user, profile, settings }
})
```

### Pattern 2: Parallel Composition

```typescript
import { Effect } from 'effect'

// Run Effects in parallel
const program = Effect.gen(function* () {
  const [user, profile, settings] = yield* Effect.all([
    getUser(userId),
    getProfile(userId),
    getSettings(userId),
  ])
  return { user, profile, settings }
})
```

### Pattern 3: Conditional Composition

```typescript
// Compose based on conditions
const program = Effect.gen(function* () {
  const user = yield* getUser(userId)
  
  if (user.isAdmin) {
    return yield* getAdminData(user.id)
  } else {
    return yield* getRegularData(user.id)
  }
})
```

### Pattern 4: Effect.all with Options

```typescript
// Run in parallel with options
const program = Effect.all(
  [getUser(id1), getUser(id2), getUser(id3)],
  {
    concurrency: 2, // Max 2 concurrent
    batching: true, // Batch requests
  }
)
```

---

## Integration Patterns

### Pattern 1: Effect → Async/Await Boundary

```typescript
// Convert Effect to Promise at application boundary
export async function handler(request: Request) {
  const result = await Effect.runPromise(
    myEffectProgram.pipe(
      Effect.provide(AppLayer)
    )
  )
  return result
}
```

### Pattern 2: Async/Await → Effect Boundary

```typescript
// Convert Promise to Effect
const program = Effect.tryPromise({
  try: () => fetch('https://api.example.com'),
  catch: (error) => new HttpClientError.RequestError({
    request: {} as any,
    reason: 'Transport',
    cause: error,
  }),
})
```

### Pattern 3: Effect.gen with try/catch

```typescript
// Handle exceptions in Effect.gen
const program = Effect.gen(function* () {
  try {
    const result = yield* someEffect
    return result
  } catch (error) {
    // Convert to Effect error
    return yield* Effect.fail(new MyError(error))
  }
})
```

### Pattern 4: Layer.launch for Long-Running Services

Convert a Layer to an Effect for long-running services (like HTTP servers):

```typescript
import { Layer, Effect } from 'effect'

class HTTPServer extends Context.Tag("HTTPServer")<
  HTTPServer,
  void
>() {}

const ServerLayer = Layer.effect(
  HTTPServer,
  Effect.gen(function* () {
    console.log("Starting HTTP server...")
    // Server startup logic
  })
)

// Launch the server layer (keeps it alive until interrupted)
Effect.runFork(Layer.launch(ServerLayer))
// Server runs until process is interrupted
```

**Use Cases**:
- HTTP servers
- Background workers
- Long-running processes
- Services that should run until explicitly stopped

---

## Performance Considerations

### 1. Avoid Unnecessary Effect Wrapping

```typescript
// ❌ BAD - Unnecessary Effect wrapping
const value = yield* Effect.succeed(42)

// ✅ GOOD - Use value directly
const value = 42
```

### 2. Use Effect.all for Parallel Operations

```typescript
// ✅ GOOD - Parallel execution
const [a, b, c] = yield* Effect.all([
  fetchA(),
  fetchB(),
  fetchC(),
])

// ❌ BAD - Sequential execution
const a = yield* fetchA()
const b = yield* fetchB()
const c = yield* fetchC()
```

### 3. Batch Operations

```typescript
// ✅ GOOD - Batch database queries
const users = yield* Effect.all(
  userIds.map(id => getUser(id)),
  { batching: true }
)
```

### 4. Use Effect.cache for Expensive Operations

```typescript
import { Effect, Cache } from 'effect'

// Cache expensive computation
const cachedProgram = program.pipe(
  Effect.cached({ capacity: 100, timeToLive: '1 hour' })
)
```

---

## Real-World Examples

### Example 1: HTTP Client with Retry and Timeout

```typescript
import { HttpClient, HttpClientError } from '@effect/platform'
import { Effect, pipe, Schedule } from 'effect'
import type { TimeoutException } from 'effect/Cause'

export const getWalletRiskScore = (
  address: string,
): Effect.Effect<
  unknown,
  HttpClientError.HttpClientError | TimeoutException,
  HttpClient.HttpClient
> =>
  pipe(
    Effect.gen(function* () {
      const client = yield* HttpClient.HttpClient
      const response = yield* client
        .get(fullUrl, { headers })
        .pipe(
          Effect.timeout('10 seconds'),
          Effect.retry({
            schedule: Schedule.exponential(1000),
            times: 3,
          }),
        )

      if (response.status < 200 || response.status >= 300) {
        throw new HttpClientError.ResponseError({
          request: {} as any,
          response: { ...response, status: response.status } as any,
          reason: 'StatusCode' as const,
          error: `HTTP ${response.status}`,
        } as any)
      }

      return yield* response.json
    }),
    Effect.withSpan('getWalletRiskScore', { attributes: { address } }),
  )
```

**Key Points**:
- Explicit error types in signature
- Retry logic with exponential backoff
- Timeout protection
- OpenTelemetry tracing
- Proper error handling

### Example 2: Providing Dependencies

```typescript
import { FetchHttpClient } from '@effect/platform'
import { Effect } from 'effect'

// In production code
const result = await Effect.runPromise(
  getWalletRiskScore(address).pipe(
    Effect.provide(FetchHttpClient.layer)
  )
)

// In tests
const mockLayer = Layer.succeed(HttpClient.HttpClient, mockHttpClient)
const result = await Effect.runPromise(
  getWalletRiskScore(address).pipe(
    Effect.provide(mockLayer)
  )
)
```

**Key Points**:
- Same function, different dependencies
- Easy to test (just swap layers)
- Type-safe (TypeScript ensures correct types)

---

## Common Anti-Patterns

### Anti-Pattern 1: Creating Dependencies Internally

```typescript
// ❌ BAD - Creates HttpClient internally
export async function fetchData() {
  const httpClient = HttpClient.make(...)
  return await Effect.runPromise(
    program.pipe(Effect.provideService(..., httpClient))
  )
}

// ✅ GOOD - Accept dependencies via Effect context
export const fetchData = (): Effect.Effect<Data, Error, HttpClient.HttpClient> =>
  Effect.gen(function* () {
    const client = yield* HttpClient.HttpClient
    // ... use client
  })
```

### Anti-Pattern 2: Mixing Async/Await with Effect Internally

```typescript
// ❌ BAD - Mixing paradigms
export async function processData() {
  const result = await Effect.runPromise(effect1)
  const processed = await process(result)
  return await Effect.runPromise(effect2(processed))
}

// ✅ GOOD - Pure Effect composition
export const processData = (): Effect.Effect<Data, Error, R> =>
  Effect.gen(function* () {
    const result = yield* effect1
    const processed = process(result) // Pure function
    return yield* effect2(processed)
  })
```

### Anti-Pattern 3: Ignoring Error Types

```typescript
// ❌ BAD - Errors not in type signature
export const program = Effect.gen(function* () {
  try {
    return yield* riskyOperation()
  } catch (error) {
    // Error type lost
  }
})

// ✅ GOOD - Explicit error types
export const program: Effect.Effect<Data, MyError, R> =
  riskyOperation().pipe(
    Effect.catchAll((error) => Effect.fail(new MyError(error)))
  )
```

### Anti-Pattern 4: Not Using Layers

```typescript
// ❌ BAD - Manual dependency passing
function process(userId: string, httpClient: HttpClient, db: Database) {
  // ...
}

// ✅ GOOD - Use Effect's DI
const process = (userId: string): Effect.Effect<Data, Error, HttpClient.HttpClient | Database.Database> =>
  Effect.gen(function* () {
    const client = yield* HttpClient.HttpClient
    const db = yield* Database.Database
    // ...
  })
```

### Anti-Pattern 5: Leaking Dependencies in Service Interfaces

```typescript
// ❌ BAD - Service interface leaks dependencies
class Database extends Context.Tag("Database")<
  Database,
  {
    readonly query: (sql: string) => Effect.Effect<unknown, never, Config | Logger>
  }
>()

// Forces all code using Database to also require Config | Logger
const program: Effect.Effect<Data, Error, Database | Config | Logger> = ...

// ✅ GOOD - Service interface has no dependencies
class Database extends Context.Tag("Database")<
  Database,
  {
    readonly query: (sql: string) => Effect.Effect<unknown>  // R = never
  }
>()

// Dependencies managed in Layer, not service interface
const DatabaseLive = Layer.effect(
  Database,
  Effect.gen(function* () {
    const config = yield* Config.Config  // Dependency here
    const logger = yield* Logger.Logger // Dependency here
    return {
      query: (sql: string) => Effect.gen(function* () {
        yield* logger.log(`Executing: ${sql}`)
        // Use config, logger internally
        return { result: 'data' }
      })
    }
  })
)
// Type: Layer<Database, never, Config | Logger>

// Now code only requires Database, not Config | Logger
const program: Effect.Effect<Data, Error, Database> = ...
```

---

## Best Practices Summary

1. **Write Pure Effect Functions**
   - Return `Effect.Effect<A, E, R>`, not `Promise<A>`
   - Dependencies in type signature (`R`)
   - Errors in type signature (`E`)

2. **Avoid Requirement Leakage** ⚠️ CRITICAL
   - Service interfaces should have `R = never`
   - Dependencies managed at Layer construction level
   - Keeps services testable and composable

3. **Use Layers for Dependency Injection**
   - `Layer.succeed` for services with no dependencies
   - `Layer.effect` for services that depend on other services
   - Compose layers to build dependency graph
   - Use `Layer.merge` for concurrent combination
   - Use `Layer.provide` for sequential composition

4. **Layer Naming Conventions**
   - `Live` suffix for production implementations (e.g., `DatabaseLive`)
   - `Test` suffix for test implementations (e.g., `DatabaseTest`)

5. **Explicit, verbose error types on the Effect**
   - Specify the error union inline on the Effect (e.g. `Effect<A, FooError | BarError, R>`), not as a separate type; avoid a single generic `Error`.
   - Put errors in type signature; use Effect combinators (catchAll, retry, timeout).
   - Use Layer error handling (catchAll, orElse, tap) for layer construction.
   - Don't use try/catch for Effect errors.

6. **Requirement type: Tag, not `typeof Tag`**
   - In `Effect.Effect<A, E, R>`, use the Tag type (e.g. `UsersServiceTag`) in `R`, not `typeof UsersServiceTag`.

7. **Compose Effects, Don't Mix Paradigms**
   - Use Effect.gen for sequential composition
   - Use Effect.all for parallel composition
   - Convert at boundaries (Effect ↔ Promise)

8. **Use Built-in Layers**
   - `FetchHttpClient.layer` for HTTP
   - Don't create HttpClient manually
   - Leverage Effect's platform packages

9. **Performance**
   - Use Effect.all for parallel operations
   - Avoid unnecessary Effect wrapping
   - Cache expensive computations

---

## Migration Guide

### Step 1: Identify Dependencies

```typescript
// Before: Dependencies passed as parameters
function fetchData(httpClient: HttpClient, config: Config) {
  // ...
}

// After: Dependencies in Effect context
const fetchData = (): Effect.Effect<Data, Error, HttpClient.HttpClient | Config.Config> =>
  Effect.gen(function* () {
    const client = yield* HttpClient.HttpClient
    const config = yield* Config.Config
    // ...
  })
```

### Step 2: Convert Async Functions

```typescript
// Before: async/await
export async function processData() {
  const data = await fetchData()
  return process(data)
}

// After: Effect composition
export const processData = (): Effect.Effect<Data, Error, R> =>
  Effect.gen(function* () {
    const data = yield* fetchData()
    return process(data) // Pure function
  })
```

### Step 3: Create Layers

```typescript
// Create layers for dependencies
// Simple layers with no dependencies
const ConfigLayer = Layer.succeed(Config.Config, config)
const HttpClientLayer = FetchHttpClient.layer

// Layers with dependencies use Layer.effect
const LoggerLayer = Layer.effect(
  Logger.Logger,
  Effect.gen(function* () {
    const config = yield* Config.Config
    return {
      log: (message: string) => console.log(`[${config.logLevel}] ${message}`)
    }
  })
)

// Compose layers (merge independent, provide dependent)
const AppLayer = LoggerLayer.pipe(
  Layer.provide(ConfigLayer),
  Layer.provideMerge(HttpClientLayer)
)
```

### Step 4: Provide at Boundaries

```typescript
// At application boundaries (HTTP handlers, CLI, etc.)
const result = await Effect.runPromise(
  processData().pipe(Effect.provide(AppLayer))
)
```

---

## Advanced Patterns

### Effect.Service API (Alternative Approach)

Effect.ts 3.9.0+ introduced `Effect.Service` which simplifies service definitions by combining Tag and Layer creation:

```typescript
import { Effect } from 'effect'
import { FileSystem } from '@effect/platform'
import { NodeFileSystem } from '@effect/platform-node'

class Cache extends Effect.Service<Cache>()("app/Cache", {
  effect: Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    return {
      lookup: (key: string) => fs.readFileString(`cache/${key}`)
    }
  }),
  dependencies: [NodeFileSystem.layer]
}) {}

// Automatically generates Cache.Default layer
const program = Effect.gen(function* () {
  const cache = yield* Cache
  const data = yield* cache.lookup("my-key")
})

const runnable = program.pipe(Effect.provide(Cache.Default))
```

**When to Use**:
- `Effect.Service`: Application code with clear runtime implementation
- `Context.Tag`: Library code or dynamically-scoped values

**Note**: This skill focuses on the foundational `Context.Tag` approach, which provides more explicit control and is universally applicable. `Effect.Service` is syntactic sugar that can simplify common cases.

---

## References

- Effect.ts Documentation: https://effect.website/
- Effect Platform: https://effect.website/docs/platform/
- Managing Layers: https://effect.website/docs/requirements-management/layers/
- Layer System: https://effect.website/docs/guides/layer/
- Error Handling: https://effect.website/docs/guides/error-handling/
- Best Practices: https://effect.website/docs/guides/best-practices/

---

## Related Skills

- `effect.ts-fundamentals` - Effect as value, pipe/flatMap, FP data types, Schema
- `effect.ts-testing` - Testing Effect.ts code
- `typescript-expert` - TypeScript best practices
- `error-handling-patterns` - Error handling strategies

---

**Remember**: Effect.ts is designed for **explicit dependency management** and **type-safe composition**. Embrace its patterns rather than fighting them. Write pure Effect functions, use Layers for dependencies, **avoid requirement leakage**, and compose at boundaries.
