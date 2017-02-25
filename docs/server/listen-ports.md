# HTTP/HTTPS Listen Ports

By default API Umbrella will startup and listen on the default HTTP and HTTPS ports (80 and 443). If you'd like to run API Umbrella on different ports, you can make changes to the `/etc/api-umbrella/api-umbrella.yml` config file:

```yaml
http_port: 8080
https_port: 8443
```

## Override Public Ports

If API Umbrella is placed behind a load balancer or other proxy, it should generally work without further configuration if the load balancer passes back the `X-Forwarded-Proto` and `X-Forwarded-Port` headers. These headers are commonly passed by other proxies by default, and it is the recommended approach to ensuring users see.

However, if your load balancer does not support sending back `X-Forwarded-Proto` and `X-Forwarded-Port` headers, and API Umbrella's internal ports differ from the public-facing ports, then you can explicitly override the public-facing port and protocol. The following configuration options can be defined in `/etc/api-umbrella/api-umbrella.yml`:

- `override_public_http_port`: Override the public port used when API Umbrella receives traffic on its `http_port` listener.
- `override_public_http_proto`: Override the public protocol (`http` or `https`) used when API Umbrella receives traffic on its `http_port` listener.
- `override_public_https_port`: Override the public port used when API Umbrella receives traffic on its `https_port` listener.
- `override_public_https_proto`: Override the public protocol (`http` or `https`) used when API Umbrella receives traffic on its `https_port` listener.

As an example, if you're terminating SSL outside of API Umbrella and sending all traffic to API Umbrella's HTTP port, then you could force API Umbrella into thinking the traffic to API Umbrella's HTTP port was originally received over HTTPS by overriding the public port and protocol for HTTP traffic:

```yaml
override_public_http_port: 443
override_public_http_proto: https
```

However, note that in this case, API Umbrella has no way to distinguish between traffic that was originally HTTP or HTTPS (since they're both received on API Umbrella's HTTP port), so we're assuming the SSL terminator has already forced all traffic to HTTPS.
