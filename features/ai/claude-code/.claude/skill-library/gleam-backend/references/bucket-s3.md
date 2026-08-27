# S3 Object Storage with bucket

Use `bucket` for S3-compatible object storage on any target (AWS S3, Cloudflare R2, MinIO, etc.).

## Installation

```sh
gleam add bucket@1
```

## Sans-IO Pattern

`bucket` uses a **sans-IO** design — it builds HTTP requests and decodes HTTP responses, but
never sends them. You bring any HTTP client. Every operation follows three steps:

```gleam
// 1. Create a request builder with operation parameters
let builder = some_operation.request(bucket: "my-bucket", key: "photo.jpg")

// 2. Build into an HTTP request using credentials
let request = some_operation.build(builder, creds)

// 3. Send with ANY HTTP client, then decode the response
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(result) = some_operation.response(response)
```

Optional builder functions (like `prefix`, `if_match`) pipe between steps 1 and 2.

## Quick Start

```gleam
import bucket
import bucket/put_object
import bucket/get_object.{Found}
import gleam/bit_array
import gleam/io
import httpc

pub fn main() {
  let creds =
    bucket.credentials(
      host: "s3.amazonaws.com",
      access_key_id: "AKIA...",
      secret_access_key: "wJal...",
    )
    |> bucket.with_region("us-east-1")

  // Upload an object
  let body = bit_array.from_string("Hello, S3!")
  let request =
    put_object.request(bucket: "my-bucket", key: "hello.txt", body: body)
    |> put_object.build(creds)
  let assert Ok(response) = httpc.send_bits(request)
  let assert Ok(result) = put_object.response(response)
  io.println("Uploaded with etag: " <> result.etag)

  // Download it back
  let request =
    get_object.request(bucket: "my-bucket", key: "hello.txt")
    |> get_object.build(creds)
  let assert Ok(response) = httpc.send_bits(request)
  let assert Ok(Found(body)) = get_object.response(response)
  let assert Ok(text) = bit_array.to_string(body)
  io.println(text)
}
```

## Credentials

### Constructor

```gleam
bucket.credentials(
  host: "s3.amazonaws.com",
  access_key_id: "AKIA...",
  secret_access_key: "wJal...",
)
```

Defaults: `scheme = Https`, `region = ""`, `port = None`, `session_token = None`.

### Builder Functions

```gleam
creds
|> bucket.with_region("us-east-1")        // set AWS region
|> bucket.with_port(9000)                  // custom port (MinIO)
|> bucket.with_scheme(http.Http)           // HTTP for local dev
|> bucket.with_session_token(Some(token))  // STS session token
```

### Provider Examples

```gleam
// AWS S3
let aws_creds =
  bucket.credentials(
    host: "s3.amazonaws.com",
    access_key_id: aws_key,
    secret_access_key: aws_secret,
  )
  |> bucket.with_region("eu-west-1")

// Cloudflare R2
let r2_creds =
  bucket.credentials(
    host: "<account-id>.r2.cloudflarestorage.com",
    access_key_id: r2_key,
    secret_access_key: r2_secret,
  )
  |> bucket.with_region("auto")

// MinIO (local dev)
let minio_creds =
  bucket.credentials(
    host: "localhost",
    access_key_id: "minioadmin",
    secret_access_key: "minioadmin",
  )
  |> bucket.with_port(9000)
  |> bucket.with_scheme(http.Http)
```

## Object Operations

### put_object — Upload

```gleam
import bucket/put_object

let request =
  put_object.request(bucket: "photos", key: "2024/cat.jpg", body: file_bytes)
  |> put_object.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(put_object.PutObjectResult(etag:)) = put_object.response(response)
```

Returns `PutObjectResult(etag: String)` on success.

### get_object — Download

```gleam
import bucket/get_object.{Found, NotFound}

let request =
  get_object.request(bucket: "photos", key: "2024/cat.jpg")
  |> get_object.build(creds)
let assert Ok(response) = httpc.send_bits(request)

case get_object.response(response) {
  Ok(Found(body)) -> Ok(body)
  Ok(NotFound) -> Error(ObjectNotFound)
  Error(e) -> Error(S3Error(e))
}
```

The response function is generic over body — `Outcome(body)` matches whatever body type
your HTTP client returns.

### head_object — Check Existence

```gleam
import bucket/head_object

let request =
  head_object.request(bucket: "photos", key: "2024/cat.jpg")
  |> head_object.build(creds)
let assert Ok(response) = httpc.send_bits(request)

case head_object.response(response) {
  Ok(head_object.Found) -> True
  Ok(head_object.NotFound) -> False
  Ok(head_object.PreconditionFailed) -> False  // if_match didn't match
  Error(_) -> False
}
```

Optional: conditional check with ETag:

```gleam
head_object.request(bucket: "photos", key: "2024/cat.jpg")
|> head_object.if_match("\"abc123\"")
|> head_object.build(creds)
```

### delete_object — Delete One

```gleam
import bucket/delete_object

let request =
  delete_object.request(bucket: "photos", key: "2024/cat.jpg")
  |> delete_object.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(Nil) = delete_object.response(response)
```

### delete_objects — Batch Delete

```gleam
import bucket/delete_objects.{Deleted, ObjectIdentifier}
import gleam/option.{None}

let objects = [
  ObjectIdentifier(key: "old/file1.txt", version_id: None),
  ObjectIdentifier(key: "old/file2.txt", version_id: None),
  ObjectIdentifier(key: "old/file3.txt", version_id: None),
]

let request =
  delete_objects.request("my-bucket", objects)
  |> delete_objects.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(results) = delete_objects.response(response)

// Each object gets its own Result
list.each(results, fn(result) {
  case result {
    Ok(Deleted(key:, ..)) -> io.println("Deleted: " <> key)
    Error(err) -> io.println("Failed: " <> err.code)
  }
})
```

### list_objects — List with Prefix & Pagination

```gleam
import bucket/list_objects

let request =
  list_objects.request("my-bucket")
  |> list_objects.prefix("uploads/2024/")
  |> list_objects.start_after("uploads/2024/last-seen-key.txt")
  |> list_objects.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(result) = list_objects.response(response)

// result.is_truncated: Bool — more pages available?
// result.contents: List(Object) — key, last_modified, etag, size
list.each(result.contents, fn(obj) {
  io.println(obj.key <> " (" <> int.to_string(obj.size) <> " bytes)")
})
```

`Object` fields: `key: String`, `last_modified: String`, `etag: String`, `size: Int`.

Paginate by passing the last key to `start_after` in the next request when `is_truncated`
is `True`.

## Bucket Operations

### create_bucket

```gleam
import bucket/create_bucket

let request =
  create_bucket.request(name: "new-bucket")
  |> create_bucket.region("us-west-2")
  |> create_bucket.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(Nil) = create_bucket.response(response)
```

### delete_bucket

```gleam
import bucket/delete_bucket

let request =
  delete_bucket.request(name: "old-bucket")
  |> delete_bucket.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(Nil) = delete_bucket.response(response)
```

### head_bucket — Check Bucket Exists

```gleam
import bucket/head_bucket

let request =
  head_bucket.request(name: "my-bucket")
  |> head_bucket.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(exists) = head_bucket.response(response)
// exists: Bool — True if bucket exists and you have access
```

### list_buckets

```gleam
import bucket/list_buckets

let request =
  list_buckets.request()
  |> list_buckets.max_buckets(100)
  |> list_buckets.build(creds)
let assert Ok(response) = httpc.send_bits(request)
let assert Ok(result) = list_buckets.response(response)

// result.buckets: List(bucket.Bucket) — name, creation_date
// result.continuation_token: Option(String) — for pagination
list.each(result.buckets, fn(b) { io.println(b.name) })
```

Paginate with `continuation_token`:

```gleam
case result.continuation_token {
  option.Some(token) ->
    list_buckets.request()
    |> list_buckets.continuation_token(token)
    |> list_buckets.build(creds)
  option.None -> // no more pages
}
```

## Multipart Upload

For large files, use multipart upload (three modules in sequence):

```gleam
import bucket/complete_multipart_upload.{Part}
import bucket/create_multipart_upload
import bucket/upload_part

/// Upload a large file in chunks
pub fn upload_multipart(
  creds: bucket.Credentials,
  bucket_name: String,
  key: String,
  chunks: List(BitArray),
) -> Result(String, bucket.BucketError) {
  // 1. Initiate the upload
  let request =
    create_multipart_upload.request(bucket: bucket_name, key: key)
    |> create_multipart_upload.build(creds)
  use response <- result.try(
    httpc.send_bits(request) |> result.map_error(fn(_) { unexpected_error() }),
  )
  use initiate_result <- result.try(create_multipart_upload.response(response))
  let upload_id = initiate_result.upload_id

  // 2. Upload each chunk as a part (part numbers start at 1)
  use parts <- result.try(
    list.index_map(chunks, fn(chunk, index) {
      let part_number = index + 1
      let request =
        upload_part.request(
          bucket: bucket_name,
          key: key,
          upload_id: upload_id,
          part_number: part_number,
          body: chunk,
        )
        |> upload_part.build(creds)
      use response <- result.try(
        httpc.send_bits(request) |> result.map_error(fn(_) { unexpected_error() }),
      )
      use part_result <- result.map(upload_part.response(response))
      Part(part_number: part_number, etag: part_result.etag)
    })
    |> result.all,
  )

  // 3. Complete the upload with all part ETags
  let request =
    complete_multipart_upload.request(
      bucket: bucket_name,
      key: key,
      upload_id: upload_id,
      parts: parts,
    )
    |> complete_multipart_upload.build(creds)
  use response <- result.try(
    httpc.send_bits(request) |> result.map_error(fn(_) { unexpected_error() }),
  )
  use complete_result <- result.map(complete_multipart_upload.response(response))
  complete_result.etag
}
```

## Error Handling

### BucketError Variants

```gleam
pub type BucketError {
  InvalidXmlSyntaxError(String)        // XML parse failure
  UnexpectedXmlFormatError(String)     // XML parsed but unexpected structure
  UnexpectedResponseError(Response(BitArray))  // unexpected HTTP status
  S3Error(http_status: Int, error: ErrorObject)  // structured S3 error
}

pub type ErrorObject {
  ErrorObject(
    code: String,       // e.g. "NoSuchKey", "AccessDenied"
    message: String,    // human-readable description
    resource: String,   // the resource involved
    request_id: String, // for AWS support reference
  )
}
```

### Mapping to Application Errors

```gleam
pub type AppError {
  ObjectNotFound
  AccessDenied
  StorageError(String)
}

fn map_s3_error(error: bucket.BucketError) -> AppError {
  case error {
    bucket.S3Error(404, _) -> ObjectNotFound
    bucket.S3Error(403, _) -> AccessDenied
    bucket.S3Error(_, err) -> StorageError(err.message)
    bucket.UnexpectedResponseError(_) -> StorageError("Unexpected response")
    bucket.InvalidXmlSyntaxError(msg) -> StorageError("XML error: " <> msg)
    bucket.UnexpectedXmlFormatError(msg) -> StorageError("XML format: " <> msg)
  }
}
```

## Complete S3 Service Module

```gleam
//// storage/s3.gleam - S3 service module

import bucket
import bucket/delete_object
import bucket/get_object.{Found, NotFound}
import bucket/list_objects
import bucket/put_object
import envoy
import gleam/bit_array
import gleam/http
import gleam/list
import gleam/option
import gleam/result
import httpc

pub type StorageError {
  MissingCredentials
  ObjectNotFound
  S3ApiError(bucket.BucketError)
  HttpError
}

/// Load credentials from environment variables
pub fn credentials() -> Result(bucket.Credentials, StorageError) {
  use host <- result.try(
    envoy.get("S3_HOST") |> result.replace_error(MissingCredentials),
  )
  use access_key <- result.try(
    envoy.get("S3_ACCESS_KEY_ID") |> result.replace_error(MissingCredentials),
  )
  use secret_key <- result.try(
    envoy.get("S3_SECRET_ACCESS_KEY")
    |> result.replace_error(MissingCredentials),
  )

  let creds =
    bucket.credentials(
      host: host,
      access_key_id: access_key,
      secret_access_key: secret_key,
    )

  // Optional region
  let creds = case envoy.get("S3_REGION") {
    Ok(region) -> bucket.with_region(creds, region)
    Error(_) -> creds
  }

  Ok(creds)
}

/// Upload a file
pub fn upload(
  creds: bucket.Credentials,
  bucket_name: String,
  key: String,
  body: BitArray,
) -> Result(String, StorageError) {
  let request =
    put_object.request(bucket: bucket_name, key: key, body: body)
    |> put_object.build(creds)

  use response <- result.try(
    httpc.send_bits(request) |> result.replace_error(HttpError),
  )
  use result <- result.map(
    put_object.response(response) |> result.map_error(S3ApiError),
  )
  result.etag
}

/// Download a file
pub fn download(
  creds: bucket.Credentials,
  bucket_name: String,
  key: String,
) -> Result(BitArray, StorageError) {
  let request =
    get_object.request(bucket: bucket_name, key: key)
    |> get_object.build(creds)

  use response <- result.try(
    httpc.send_bits(request) |> result.replace_error(HttpError),
  )
  case get_object.response(response) {
    Ok(Found(body)) -> Ok(body)
    Ok(NotFound) -> Error(ObjectNotFound)
    Error(e) -> Error(S3ApiError(e))
  }
}

/// List files under a prefix
pub fn list(
  creds: bucket.Credentials,
  bucket_name: String,
  prefix: String,
) -> Result(List(list_objects.Object), StorageError) {
  let request =
    list_objects.request(bucket_name)
    |> list_objects.prefix(prefix)
    |> list_objects.build(creds)

  use response <- result.try(
    httpc.send_bits(request) |> result.replace_error(HttpError),
  )
  use result <- result.map(
    list_objects.response(response) |> result.map_error(S3ApiError),
  )
  result.contents
}

/// Delete a file
pub fn delete(
  creds: bucket.Credentials,
  bucket_name: String,
  key: String,
) -> Result(Nil, StorageError) {
  let request =
    delete_object.request(bucket: bucket_name, key: key)
    |> delete_object.build(creds)

  use response <- result.try(
    httpc.send_bits(request) |> result.replace_error(HttpError),
  )
  delete_object.response(response) |> result.map_error(S3ApiError)
}
```

## Best Practices

1. **Load credentials from environment** — never hardcode keys
2. **Use multipart upload for large files** — S3 limits single PUT to 5 GB
3. **Treat `NotFound` as a normal outcome** — `get_object` and `head_object` return
   `NotFound` as an `Ok` variant, not an error
4. **Use prefixes for folder organization** — S3 has no real folders, only key prefixes
5. **Use `head_object` before expensive downloads** — check existence/ETag first
6. **Batch deletes with `delete_objects`** — more efficient than individual deletes
7. **Paginate `list_objects`** — use `start_after` with the last key when `is_truncated`
   is `True`
8. **Keep the HTTP client choice flexible** — the sans-IO pattern lets you swap `httpc`
   for any client (hackney, mist, fetch on JS target)
