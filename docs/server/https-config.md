# HTTPS Configuration

By default, API Umbrella requires HTTPS for a variety of endpoints. On initial installation, API Umbrella will use as self-signed certificate which won't be valid for production use. For production, you have two primary options:

- **SSL Termination:** If you're placing API Umbrella behind a load balancer in a multi-server setup, you can handle the SSL termination with that external load balancer.

  SSL termination should work without any further configuration assuming your external load balancer passes the appropriate `X-Forwarded-Proto` and `X-Forwarded-Port` headers to API Umbrella. If your load balancer does not support setting these headers, then see how you can [override public ports](listen-ports.html#override-public-ports).
- **SSL Certificate Installation:** You can configure API Umbrella with a valid SSL certificate, rather than the self-signed default one. To do so, install the certificates on your server, and then adjust the `/etc/api-umbrella/api-umbrella.yml` to point to these certificate files for your domain:

  ```yaml
  hosts:
    - hostname: api.example.com
      default: true
      ssl_cert: /etc/ssl/your_cert.crt
      ssl_cert_key: /etc/ssl/your_cert.key
  ```

  `ssl_cert` should point to a valid certificate file in the format supported by nginx's [`ssl_certificate`](http://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate).

  `ssl_cert_key` should point to a valid private key file in the format supported by nginx's [`ssl_certificate_key`](http://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate_key).
