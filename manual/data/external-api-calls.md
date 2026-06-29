# External API Calls

Mantra can issue synchronous HTTP and HTTPS requests through an explicit
external-operation boundary:

```mantra
system http <response-prefix> <request-path>;
```

Network access is disabled by default. Enable it explicitly:

```bash
./bin/mantra --set mantra.external.enabled=true program.m
```

HTTPS is the default allowed scheme. HTTP, private networks, and individual
hosts require additional policy settings.

## Basic GET

Build a request as structured trie data, then execute it:

```mantra
request.method = "GET";
request.url = "https://api.example.test/users/42";
request.headers.Accept = "application/json";

system http response request;

print { response.ok }
print { response.status }
print { response.body.name }
```

The operation runs in the statement execution phase. The completed operation
node is replaced by the response path, so later evaluation cannot accidentally
repeat the request.

## JSON POST

Values under `request.body` are encoded as JSON:

```mantra
request.method = "POST";
request.url = "https://api.example.test/items";
request.body.name = "sample";
request.body.count = 3;

system http response request;

print { response.status }
print { response.body.id }
```

Without an explicit `Content-Type`, a structured body uses
`application/json`. Use `request.body_text` for a raw text body. A request
cannot contain both `body` and `body_text`.

## Request Fields

| Path | Type | Default |
| --- | --- | --- |
| `method` | string | `GET` |
| `url` | string | required |
| `headers.*` | scalar or scalar array | none |
| `query.*` | scalar or scalar array | none |
| `body.*` | JSON-compatible subtree | none |
| `body_text` | string | none |
| `timeout_ms` | integer | policy timeout |
| `connect_timeout_ms` | integer | request timeout |
| `follow_redirects` | boolean | `false` |
| `max_response_bytes` | integer | policy limit |

Supported methods are `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, and `HEAD`.

Transport-managed headers such as `Host`, `Content-Length`,
`Transfer-Encoding`, and `Connection` cannot be supplied by the program.

## Response Fields

| Path | Type | Meaning |
| --- | --- | --- |
| `ok` | boolean | True for status codes from 200 through 299 |
| `status` | integer | HTTP status, or zero before a response exists |
| `reason` | string | HTTP reason text |
| `url` | string | Final URL |
| `headers.*` | string | Response headers |
| `contentType` | string | Response media type |
| `body.*` | typed subtree | Parsed JSON body |
| `bodyText` | string | Unparsed response bytes |
| `elapsedMs` | integer | Total operation duration |
| `error.kind` | string | Structured failure category |
| `error.message` | string | Failure detail |

HTTP error statuses remain normal responses. Transport and policy failures use
status zero and an error object.

Error kinds include `disabled`, `configuration`, `invalid_request`, `policy`,
`dns`, `timeout`, `response_too_large`, `transport`, `redirect_limit`,
`invalid_redirect`, and `redirect_policy`.

If a JSON media type contains malformed JSON, `bodyText` is preserved and
`bodyParseError` contains the parser error.

## Security Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `mantra.external.enabled` | `false` | Global external-operation gate |
| `mantra.external.http.enabled` | `true` | HTTP provider gate |
| `mantra.external.http.allowed_schemes` | `"https"` | Comma-separated schemes |
| `mantra.external.http.allowed_hosts` | empty | Optional host allowlist |
| `mantra.external.http.denied_hosts` | empty | Host denylist |
| `mantra.external.http.allow_private_networks` | `false` | Permit loopback/private targets |
| `mantra.external.http.timeout_ms` | `10000` | Maximum total request time |
| `mantra.external.http.max_response_bytes` | `1048576` | Maximum response body |
| `mantra.external.http.max_redirects` | `3` | Redirect limit |

Host lists support exact names and leading wildcard forms such as
`*.example.test`.

DNS results are checked against the private-network policy. Redirects are
revalidated and restricted to the original scheme, host, and port. TLS
certificate verification is explicitly enabled.

For local development against a loopback service:

```bash
./bin/mantra \
  --set mantra.external.enabled=true \
  --set 'mantra.external.http.allowed_schemes="http,https"' \
  --set mantra.external.http.allow_private_networks=true \
  program.m
```

Do not enable private-network access for untrusted programs.

## JSON Key Escaping

External JSON object keys use the same trie-segment escaping as `json_load`.
For example, a response key named `content_type` is stored as
`content_x5F_type`, and a header named `X-Fixture` is best read with:

```mantra
print { get "response.headers.X-Fixture" }
```

See [JSON Loading](rendering-structured-output/json-loading.md) and
[JSON Encoding](rendering-structured-output/json-encoding.md) for the shared
typed trie representation.
