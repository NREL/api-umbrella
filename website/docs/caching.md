---
title: Caching - Documentation - API Umbrella
header: Documentation
---

## Caching

API Umbrella provides a standard HTTP caching layer in front of your APIs (using [Varnish](https://www.varnish-cache.org)). In order to utilize the cache, your API backend must set HTTP headers on the response. In addition to the standard `Cache-Control` or `Expires` HTTP headers, we also support the `Surrogate-Control` header.

### Surrogate-Control

The `Surrogate-Control` header will only have an effect on the API Umbrella cache. This header will be stripped before the response is delivered publicly.

```
Surrogate-Control: max-age=(time in seconds)
```

### Cache-Control: s-maxage

The `Cache-Control: s-maxage` header will be respected by the API Umbrella cache, as well as any other intermediate caches between us and the user.

```
Cache-Control: s-maxage=(time in seconds)
```

### Cache-Control: max-age

The `Cache-Control: max-age` header will be respected by the API Umbrella cache, intermediate caching servers, and the user's client.

```
Cache-Control: max-age=(time in seconds)
```

### Expires

The `Expires` header will be respected by the API Umbrella cache, intermediate caching servers, and the user's client.

```
Expires: (HTTP date)
```
