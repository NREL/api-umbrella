# HTTP Headers

## Request Headers

After API Umbrella verifies an incoming request (a valid API key, below rate limits, etc), it will then proxy the incoming request to your API backend. The request your API backend receives will have additional HTTP headers added to the request. These headers can optionally be used to identify details about the requesting user.

### X-Api-User-Id

A unique identifier for the requesting user (UUID format). This should be used if your API backend needs to uniquely identify the user making the request.

```
X-Api-User-Id: (UUID)
```

Example:

```
X-Api-User-Id: d44a13a0-926a-11e3-baa8-0800200c9a66
```

### X-Api-Roles

If the user accessing the API has roles assigned to them, these will be present in the `X-Api-Roles` header as a comma-separated list of roles:

```
X-Api-Roles: (comma separated list)
```

Example:

```
X-Api-Roles: write_permissions,private_access
```

### X-Forwarded-For

Used for identifying the original IP address of the client. See [X-Forwarded-For](https://en.wikipedia.org/wiki/X-Forwarded-For) for usage and details.

```
X-Forwarded-For: (comma separated list)
```

Example:

```
X-Forwarded-For: 203.0.113.54, 198.51.100.18
```

### X-Forwarded-Proto

The original protocol of the client's request (either `http` or `https`). This can be used to determine how the client originally connected to the API regardless of what protocol is being used for API backend communication.

```
X-Forwarded-Proto: (http or https)
```

Example:

```
X-Forwarded-Proto: https
```

### X-Forwarded-Port

The original port of the client's request (for example, `80` or `443`). This can be used to determine how the client originally connected to the API regardless of what port is being used for API backend communication.

```
X-Forwarded-Port: (number)
```

Example:

```
X-Forwarded-Port: 443
```

### X-Api-Umbrella-Request-Id

A unique string identifier for each individual request. This can be used in log data to trace a specific request through multiple servers or proxy layers. This same header will be set as a _response_ header that the API consumer will receive for tracing purposes too.

```
X-Api-Umbrella-Request-Id: (unique string identifier)
```

Example:

```
X-Api-Umbrella-Request-Id: aelqdj9lfoe7c2itheg0
```

### X-Api-Key (Deprecated)

Currently the API passed in by the user is passed along to API backends in the `X-Api-Key` header. However, this header is deprecated and will be removed in the future. Instead, the `X-Api-User-Id` should be used if you need to uniquely identify the requesting user.

```
X-Api-Key: (api key)
```

Example:

```
X-Api-Key: 5WH3bgykjP9ihtrRl5ib9nQY5NzUGOixdXjBnx18
```

## Response Headers

API Umbrella may add certain HTTP headers to the public response, or other headers can be set by the API backend for internal usage by API Umbrella.

### X-Api-Umbrella-Analytics-Custom1, X-Api-Umbrella-Analytics-Custom2, X-Api-Umbrella-Analytics-Custom3

These 3 optional response headers can be set by the API backend and will be logged by the API Umbrella analytics system. These can be used to log custom, application-specific values to the analytics system for later querying and analysis. These headers will be stripped and removed by API Umbrella before returning to the API consumer, so the values will not be part of the public HTTP response. If the HTTP header value length exceeds 400 characters, only the first 400 characters will be logged in the analytics system.

```
X-Api-Umbrella-Analytics-Custom1: (any value)
X-Api-Umbrella-Analytics-Custom2: (any value)
X-Api-Umbrella-Analytics-Custom3: (any value)
```

Example:

```
X-Api-Umbrella-Analytics-Custom1: my-custom-value
```

### X-Api-Umbrella-Request-Id

A unique string identifier for each individual request. This can be used in log data to trace a specific request through multiple servers or proxy layers. This header will be returned to the API consumer and is not something API backends can change. This same header will be set as a _request_ header that the API backend will receive for tracing purposes too.

```
X-Api-Umbrella-Request-Id: (unique string identifier)
```

Example:

```
X-Api-Umbrella-Request-Id: aelqdj9lfoe7c2itheg0
```

