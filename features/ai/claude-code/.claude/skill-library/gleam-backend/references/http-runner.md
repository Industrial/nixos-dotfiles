# HTTP Runner Pattern

## Overview

The HTTP Runner pattern centralizes all external HTTP calls through a single module. This provides unified logging, error handling, and makes external API interactions consistent across the application.

## Why Use a Centralized Runner?

1. **Unified Logging** - Log all requests/responses in one place
2. **Consistent Error Handling** - Map HTTP errors to your unified Error type
3. **Less Code Duplication** - Remove repeated `make_request` helpers from services
4. **Easy Debugging** - One place to add request inspection
5. **Future Extensibility** - Easy to add retries, circuit breakers, rate limiting

## Implementation

### Core Types

```gleam
// http/runner.gleam

import error/error.{type Error}
import gleam/dynamic/decode
import gleam/hackney
import gleam/http.{type Method, Delete, Get, Patch, Post, Put}
import gleam/http/request
import gleam/json
import gleam/option.{type Option, None, Some}

pub type RequestConfig {
  RequestConfig(
    base_url: String,
    default_headers: List(#(String, String)),
    service_name: String,
  )
}
```

### Configuration Builder

```gleam
pub fn new_config(base_url: String, service_name: String) -> RequestConfig {
  RequestConfig(
    base_url: base_url,
    default_headers: [#("Content-Type", "application/json")],
    service_name: service_name,
  )
}

pub fn with_bearer_token(config: RequestConfig, token: String) -> RequestConfig {
  let auth_header = #("Authorization", "Bearer " <> token)
  RequestConfig(
    ..config,
    default_headers: [auth_header, ..config.default_headers],
  )
}

pub fn with_header(
  config: RequestConfig,
  key: String,
  value: String,
) -> RequestConfig {
  RequestConfig(
    ..config,
    default_headers: [#(key, value), ..config.default_headers],
  )
}
```

### HTTP Methods

```gleam
pub fn get(
  config: RequestConfig,
  path: String,
  decoder: decode.Decoder(t),
) -> Result(t, Error) {
  execute(config, Get, path, None, decoder)
}

pub fn post(
  config: RequestConfig,
  path: String,
  body: json.Json,
  decoder: decode.Decoder(t),
) -> Result(t, Error) {
  execute(config, Post, path, Some(json.to_string(body)), decoder)
}

pub fn put(
  config: RequestConfig,
  path: String,
  body: json.Json,
  decoder: decode.Decoder(t),
) -> Result(t, Error) {
  execute(config, Put, path, Some(json.to_string(body)), decoder)
}

pub fn delete_no_content(
  config: RequestConfig,
  path: String,
) -> Result(Nil, Error) {
  execute_no_content(config, Delete, path, None)
}
```

### Core Execution

```gleam
fn execute(
  config: RequestConfig,
  method: Method,
  path: String,
  body: Option(String),
  decoder: decode.Decoder(t),
) -> Result(t, Error) {
  let url = config.base_url <> path

  use req <- result.try(build_request(url, method, config.default_headers, body))

  // Log outgoing request
  log_request(config.service_name, method, url, body)

  case hackney.send(req) {
    Ok(resp) -> {
      log_response(config.service_name, resp.status, Some(resp.body))
      handle_response(resp, decoder)
    }
    Error(err) -> {
      let error_msg = hackney_error_to_string(err)
      log_error(config.service_name, "Network error: " <> error_msg)
      Error(error.InternalServerError("Network error: " <> error_msg))
    }
  }
}
```

### Response Handling

```gleam
fn handle_response(
  resp: Response(String),
  decoder: decode.Decoder(t),
) -> Result(t, Error) {
  case resp.status {
    s if s >= 200 && s < 300 -> {
      case json.parse(resp.body, decoder) {
        Ok(data) -> Ok(data)
        Error(e) ->
          Error(error.UnprocessableContent(
            "Failed to decode response: " <> string.inspect(e),
          ))
      }
    }
    400 -> Error(error.BadRequest(extract_error_message(resp.body)))
    401 -> Error(error.Unauthorized(extract_error_message(resp.body)))
    403 -> Error(error.Forbidden(extract_error_message(resp.body)))
    404 -> Error(error.NotFound(extract_error_message(resp.body)))
    422 -> Error(error.UnprocessableContent(extract_error_message(resp.body)))
    s if s >= 500 ->
      Error(error.InternalServerError(
        "External service error: HTTP " <> int.to_string(s),
      ))
    s ->
      Error(error.InternalServerError(
        "Unexpected HTTP status: " <> int.to_string(s),
      ))
  }
}
```

### Logging

```gleam
fn log_request(
  service: String,
  method: Method,
  url: String,
  body: Option(String),
) {
  let method_str = method_to_string(method)
  io.println("[HTTP] " <> service <> " -> " <> method_str <> " " <> url)
  case body {
    Some(b) -> log_body(service, "->", b)
    None -> Nil
  }
}

fn log_response(service: String, status: Int, body: Option(String)) {
  io.println("[HTTP] " <> service <> " <- " <> int.to_string(status))
  case body {
    Some(b) -> log_body(service, "<-", b)
    None -> Nil
  }
}

fn log_body(service: String, direction: String, body: String) {
  let len = string.length(body)
  case len {
    0 -> Nil
    l if l < 500 ->
      io.println("[HTTP] " <> service <> " " <> direction <> " Body: " <> body)
    l ->
      io.println(
        "[HTTP] " <> service <> " " <> direction
        <> " Body: [" <> int.to_string(l) <> " bytes]",
      )
  }
}
```

## Usage in Services

### Before (Without Runner)

```gleam
// integration/vendor/service/order.gleam - OLD WAY

import gleam/hackney
import gleam/http
import gleam/http/request
import integration/vendor/base.{type ApiError, type VendorClient, DecodeError, RequestError}

pub fn get_order(client: VendorClient, order_id: Int)
  -> Result(VendorOrder, ApiError) {
  let url = client.base_url <> "/orders/" <> int.to_string(order_id)

  let req_result = request.to(url)
  use req <- result.try(
    result.map_error(req_result, fn(_) { RequestError("Invalid URL") }),
  )

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_header("Authorization", "Bearer " <> client.api_key)

  case hackney.send(req) {
    Ok(resp) -> {
      case json.parse(resp.body, order_decoder()) {
        Ok(data) -> Ok(data)
        Error(e) -> Error(DecodeError(string.inspect(e)))
      }
    }
    Error(e) -> Error(RequestError(string.inspect(e)))
  }
}
```

### After (With Runner)

```gleam
// integration/vendor/service/order.gleam - NEW WAY

import error/error.{type Error}
import http/runner
import integration/vendor/base.{type VendorClient}

pub fn get_order(client: VendorClient, order_id: Int)
  -> Result(VendorOrder, Error) {
  let config =
    runner.new_config(client.base_url, "Vendor")
    |> runner.with_bearer_token(client.api_key)

  runner.get(
    config,
    "/orders/" <> int.to_string(order_id),
    order_decoder(),
  )
}
```

## Benefits Summary

| Aspect          | Before               | After                 |
| --------------- | -------------------- | --------------------- |
| Lines of code   | ~25 per endpoint     | ~8 per endpoint       |
| Error handling  | Custom per service   | Unified Error type    |
| Logging         | Manual, inconsistent | Automatic, consistent |
| Testing         | Hard to mock         | Easy to mock runner   |
| Adding features | Modify each service  | Modify runner once    |

## Extending the Runner

### Adding Retry Logic

```gleam
pub fn get_with_retry(
  config: RequestConfig,
  path: String,
  decoder: decode.Decoder(t),
  max_retries: Int,
) -> Result(t, Error) {
  do_get_with_retry(config, path, decoder, max_retries, 0)
}

fn do_get_with_retry(
  config: RequestConfig,
  path: String,
  decoder: decode.Decoder(t),
  max_retries: Int,
  attempt: Int,
) -> Result(t, Error) {
  case get(config, path, decoder) {
    Ok(result) -> Ok(result)
    Error(err) if attempt < max_retries -> {
      // Wait and retry
      process.sleep(1000 * attempt)
      do_get_with_retry(config, path, decoder, max_retries, attempt + 1)
    }
    Error(err) -> Error(err)
  }
}
```

### Adding Request ID Tracking

```gleam
pub fn with_request_id(config: RequestConfig, request_id: String) -> RequestConfig {
  with_header(config, "X-Request-ID", request_id)
}
```

### Adding Timeout Configuration

```gleam
pub type RequestConfig {
  RequestConfig(
    base_url: String,
    default_headers: List(#(String, String)),
    service_name: String,
    timeout_ms: Int,  // Add timeout
  )
}
```
