import std;

backend default {
  .host = "localhost";
  .port = "50100";
  .first_byte_timeout = 60s;
}

acl internal_networks {
    "localhost";
}

sub vcl_recv {
  if(req.http.X-Forwarded-For) {
    # Collect multiple, separate X-Forwarded-For headers into a single
    # comma-delimited header. Without this, Varnish's default logic to append
    # the client's IP to this header will incorrectly pick the first
    # X-Forwarded-For header present and use that (which allows for IP address
    # spoofing by the client).
    std.collect(req.http.X-Forwarded-For);
  }

  # Remove all stats cookies:
  #
  # - Google Analytic cookies named __utm* (utma, utmb, utmmobile, etc)
  # - Crazy Egg "is_returning" cookie
  set req.http.Cookie = regsuball(req.http.Cookie, "(^|; ) *(__utm[^=]+|is_returning)=[^;]+;? *", "\1");

  # Remove the cookie if it's now empty, so simple stats cookies don't prevent caching.
  if(req.http.Cookie == "") {
    remove req.http.Cookie;
  }

  # Remove the cookie for all static files, so they can always be returned from
  # the cache, even if the user has other cookies set.
  if(req.url ~ "\.(html|js|css|png|gif|jpg|jpeg)$") {
    remove req.http.Cookie;
  }

  # Allow internal connections to bypass the cache for testing/debug purposes.
  # This leaves the current cached content intact.
  if(req.http.X-Bypass-Cache && client.ip ~ internal_networks) {
    # Force a cache miss by making sure a cookie is set (this approach ensures
    # that Varnish's default vcl_recv still gets run so things like
    # X-Forwarded-For get handled).
    if(!req.http.Cookie) {
      set req.http.Cookie = "Bypass-Cache";
    }
  }

  # Allow internal connections to force cache refreshes for testing/debug
  # purposes. This replaces the current cached content with the newly fetched
  # data.
  if(req.http.X-Refresh-Cache && client.ip ~ internal_networks) {
    set req.hash_always_miss = true;
  }
}

sub vcl_hash {
  # Add the original protocol to the hash, so HTTPS and HTTP caches are kept
  # separate.
  if(req.http.X-Forwarded-Proto) {
    hash_data(req.http.X-Forwarded-Proto);
  }
}

sub vcl_fetch {
  # Don't cache error pages.
  #
  # (While it might be tempting to cache error pages, this stemmed from a
  # situtation where a user accessed an uncached page using FrontPage, somehow
  # generating a 406 error from the server. This error then got cached and was
  # being served up to all users.)
  if(beresp.status >= 400) {
    # Allow not found errors to be cached, since those seem safe.
    if(beresp.status != 404) {
      set beresp.ttl = 0s;
    }
  }

  # Parse cache control headers out of the custom Surrogate-Control header.
  # This header controls only Varnish, and is not passed onto the end-user.
  # This allows for independant control of how the end-user should cache things
  # (Cache-Control) and how Varnish should cache things (Surrogate-Control).
  if(beresp.http.Surrogate-Control) {
    # Parse the max-age from the Surrogate-Control header and set the
    # response's TTL to this value.
    set beresp.http.surrogate_max_age = regsub(beresp.http.Surrogate-Control, "max-age\s*=\s*(\d+)", "\1s");
    if(beresp.http.surrogate_max_age ~ "^\d+s$") {
      set beresp.ttl = std.duration(beresp.http.surrogate_max_age, 0s);
    }

    # Remove temp variable.
    unset beresp.http.surrogate_max_age;

    # Remove the Surrogate-Control header which is intended for internal
    # Varnish use only.
    unset beresp.http.Surrogate-Control;
  }

  # Allow for streaming responses.
  set beresp.do_stream = true;
}
