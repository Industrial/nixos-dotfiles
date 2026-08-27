# JWT Authentication with ywt

Use `ywt_core` + `ywt_erlang` for JWT authentication on Erlang targets.

## Installation

```toml
[dependencies]
ywt_core = ">= 1.2.0 and < 2.0.0"
ywt_erlang = ">= 1.0.1 and < 2.0.0"
```

## Quick Start

```gleam
import gleam/crypto
import gleam/dynamic/decode
import gleam/json
import gleam/time/duration
import ywt
import ywt/algorithm
import ywt/claim
import ywt/sign_key
import ywt/verify_key

// 1. Generate or load a signing key
let key = ywt.generate_key(algorithm.hs256)

// 2. Create a token
let token = ywt.encode(
  payload: [
    #("sub", json.string(user_id)),
    #("email", json.string(email)),
    #("role", json.string("admin")),
    #("tenant_id", json.string(tenant_id)),
  ],
  claims: [
    claim.issued_at(),
    claim.expires_at(max_age: duration.hours(24), leeway: duration.minutes(5)),
    claim.issuer("my-app", []),
  ],
  key: key,
)

// 3. Verify a token
let verify_key = verify_key.derived(key)
case ywt.decode(
  jwt: token,
  using: my_payload_decoder(),
  claims: [
    claim.expires_at(max_age: duration.hours(24), leeway: duration.minutes(5)),
    claim.issuer("my-app", []),
  ],
  keys: [verify_key],
) {
  Ok(payload) -> Ok(payload)
  Error(ywt.TokenExpired(_)) -> Error(TokenExpired)
  Error(ywt.InvalidSignature) -> Error(TokenInvalid)
  Error(_) -> Error(TokenInvalid)
}
```

## Algorithms

Choose based on your security requirements:

| Algorithm | Type | Use Case |
|-----------|------|----------|
| `algorithm.hs256` | HMAC | Simple apps with shared secret |
| `algorithm.hs384` | HMAC | Higher security margin |
| `algorithm.hs512` | HMAC | Maximum HMAC strength |
| `algorithm.es256` | ECDSA | Modern standard, efficient |
| `algorithm.es384` | ECDSA | **Recommended default** |
| `algorithm.es512` | ECDSA | Maximum security |
| `algorithm.rs256` | RSA | Traditional, wide compatibility |
| `algorithm.ps256` | RSA-PSS | Modern RSA with stronger proofs |

**Recommendation:** Use `es384` for new applications - it's secure, fast, and modern.

## Key Management

### Generate Keys

```gleam
// Generate a new random key
let key = ywt.generate_key(algorithm.es384)

// Key has auto-generated ID for rotation
case sign_key.id(key) {
  Ok(kid) -> wisp.log_info("Generated key: " <> kid)
  Error(_) -> Nil
}
```

### Load HMAC Key from Environment

```gleam
import gleam/bit_array

pub fn get_signing_key() -> Result(sign_key.SignKey, Nil) {
  use secret_str <- result.try(envoy.get("JWT_SECRET"))

  // HMAC-256 needs at least 32 bytes
  let secret = bit_array.from_string(secret_str)
  sign_key.hs256(secret)
}
```

### Key Requirements

| Algorithm | Minimum Key Size |
|-----------|------------------|
| HS256 | 32 bytes (256 bits) |
| HS384 | 48 bytes (384 bits) |
| HS512 | 64 bytes (512 bits) |
| ES256/384/512 | Auto-generated |
| RS256/384/512 | 4096-bit modulus |

### Store Keys as JWK

```gleam
// Export signing key to JWK (for secure storage)
let jwk = sign_key.to_jwk(key)
let jwk_string = json.to_string(jwk)

// Load signing key from JWK
case json.parse(jwk_string, sign_key.decoder()) {
  Ok(key) -> Ok(key)
  Error(_) -> Error(InvalidKey)
}

// Export verification key (safe to distribute)
let verify_jwk = verify_key.to_jwk(verify_key.derived(key))

// Serve at /.well-known/jwks.json for key rotation
let jwks = verify_key.to_jwks([current_key, previous_key])
```

## Claims

### Standard Claims

```gleam
// Always include expiration!
claim.expires_at(max_age: duration.hours(1), leeway: duration.minutes(5))

// Issue time (for audit)
claim.issued_at()

// Not valid before (for delayed activation)
claim.not_before(time: timestamp, leeway: duration.minutes(1))

// Issuer (who created the token)
claim.issuer("https://auth.example.com", [])

// Audience (who should accept it)
claim.audience("https://api.example.com", ["https://admin.example.com"])

// Subject (who the token is about)
claim.subject("user_12345", [])

// Token ID (for revocation)
claim.id("token_abc123", [])

// JWT type header
claim.typ("JWT")
```

### Custom Claims

```gleam
claim.custom(
  name: "role",
  value: "admin",
  encode: json.string,
  decoder: decode.string,
)

claim.custom(
  name: "permissions",
  value: ["read", "write"],
  encode: json.array(_, json.string),
  decoder: decode.list(decode.string),
)
```

### Optional Claims

```gleam
// Make a claim optional (won't fail if missing)
claim.id("abc", []) |> claim.optional
```

## Error Handling

```gleam
pub type AuthError {
  TokenExpired
  TokenInvalid
  TokenNotYetValid
  InvalidIssuer
  InvalidAudience
  MissingClaim(String)
  KeyError
}

pub fn validate_token(token: String) -> Result(Payload, AuthError) {
  case ywt.decode(jwt: token, using: decoder, claims: claims, keys: keys) {
    Ok(payload) -> Ok(payload)

    // Expiration errors
    Error(ywt.TokenExpired(expired_at)) -> {
      wisp.log_info("Token expired at: " <> timestamp.to_string(expired_at))
      Error(TokenExpired)
    }
    Error(ywt.TokenNotYetValid(_)) -> Error(TokenNotYetValid)

    // Signature errors - potential attack
    Error(ywt.InvalidSignature) -> {
      wisp.log_warning("Invalid JWT signature detected")
      Error(TokenInvalid)
    }
    Error(ywt.NoMatchingKey) -> Error(TokenInvalid)

    // Claim validation errors
    Error(ywt.InvalidIssuer(expected, actual)) -> {
      wisp.log_warning("Wrong issuer: expected " <> string.inspect(expected) <> ", got " <> actual)
      Error(InvalidIssuer)
    }
    Error(ywt.InvalidAudience(_, _)) -> Error(InvalidAudience)
    Error(ywt.MissingClaim(name)) -> Error(MissingClaim(name))

    // Format errors
    Error(ywt.MalformedToken) -> Error(TokenInvalid)
    Error(ywt.InvalidHeaderEncoding) -> Error(TokenInvalid)
    Error(ywt.InvalidPayloadEncoding) -> Error(TokenInvalid)
    Error(_) -> Error(TokenInvalid)
  }
}
```

## Complete Auth Module Example

```gleam
//// auth/auth.gleam - JWT authentication module

import envoy
import gleam/bit_array
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/time/duration
import ywt
import ywt/algorithm
import ywt/claim
import ywt/sign_key.{type SignKey}
import ywt/verify_key.{type VerifyKey}

pub type AuthError {
  TokenExpired
  TokenInvalid
  MissingSecret
}

pub type AuthContext {
  AuthContext(
    user_id: String,
    email: String,
    role: String,
    tenant_id: String,
  )
}

/// Get signing key from environment
pub fn get_signing_key() -> Result(SignKey, AuthError) {
  use secret_str <- result.try(
    envoy.get("JWT_SECRET")
    |> result.map_error(fn(_) { MissingSecret })
  )

  let secret = bit_array.from_string(secret_str)
  sign_key.hs256(secret)
  |> result.map_error(fn(_) { MissingSecret })
}

/// Get verification key
pub fn get_verify_key() -> Result(VerifyKey, AuthError) {
  use sign_key <- result.try(get_signing_key())
  Ok(verify_key.derived(sign_key))
}

/// Create a JWT token
pub fn create_token(
  user_id: String,
  email: String,
  role: String,
  tenant_id: String,
) -> Result(String, AuthError) {
  use key <- result.try(get_signing_key())

  let token = ywt.encode(
    payload: [
      #("sub", json.string(user_id)),
      #("email", json.string(email)),
      #("role", json.string(role)),
      #("tenant_id", json.string(tenant_id)),
    ],
    claims: [
      claim.issued_at(),
      claim.expires_at(max_age: duration.hours(24), leeway: duration.minutes(5)),
    ],
    key: key,
  )

  Ok(token)
}

/// Validate a JWT token
pub fn validate_token(token: String) -> Result(AuthContext, AuthError) {
  use verify_key <- result.try(get_verify_key())

  let claims = [
    claim.expires_at(max_age: duration.hours(24), leeway: duration.minutes(5)),
  ]

  case ywt.decode(
    jwt: token,
    using: auth_context_decoder(),
    claims: claims,
    keys: [verify_key],
  ) {
    Ok(ctx) -> Ok(ctx)
    Error(ywt.TokenExpired(_)) -> Error(TokenExpired)
    Error(_) -> Error(TokenInvalid)
  }
}

fn auth_context_decoder() -> decode.Decoder(AuthContext) {
  use user_id <- decode.field("sub", decode.string)
  use email <- decode.field("email", decode.string)
  use role <- decode.field("role", decode.string)
  use tenant_id <- decode.field("tenant_id", decode.string)
  decode.success(AuthContext(user_id:, email:, role:, tenant_id:))
}
```

## Security Best Practices

1. **Always include expiration** - Tokens without `exp` are valid forever if compromised
2. **Use short-lived tokens** - 15-60 minutes for access tokens, longer for refresh tokens
3. **Include leeway** - 5 minutes handles clock skew between servers
4. **Validate issuer/audience** - Prevents token confusion attacks
5. **Never log tokens** - Tokens are credentials
6. **Rotate keys** - Use key IDs and maintain previous keys during rotation
7. **Use asymmetric keys** for distributed systems - Sign with private, verify with public

## Token Revocation

ywt tokens cannot be revoked once issued. For revocation:

1. **Short expiration** - Minimize window of exposure
2. **Database blacklist** - Check token ID against blacklist on each request
3. **Refresh tokens** - Short-lived access + long-lived refresh pattern

```gleam
// Check if token is revoked (requires database lookup)
pub fn is_token_revoked(db: pog.Connection, token_id: String) -> Bool {
  case sql.check_token_blacklist(db, token_id) {
    Ok(pog.Returned(1, _)) -> True
    _ -> False
  }
}
```

## Migration from Custom JWT

If migrating from a custom JWT implementation:

1. Add ywt dependencies to gleam.toml
2. Replace custom token creation with `ywt.encode`
3. Replace custom validation with `ywt.decode`
4. Update error handling to use `ywt.ParseError` variants
5. Test both old and new tokens during transition
