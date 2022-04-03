# Config Format
This file begins to describe some of the configuration options for running the
`gatekeeper`. Look at `config/default.yml` for sane defaults.

Note that this documentation is not complete.

## apis
This contains a list of configurations, each describing a proxied API. At its
simplest, this needs only a `frontend_host`, `backend_host`, and one
entry in `url_matches`

### Fields

* `apis.frontend_host` - The domain name (possibly including port) that user
    requests will hit.
* `apis.backend_host` - The domain name (possibly including port) which
    gatekeeper will proxy. This might be considered sensitive
* `apis.url_matches` - An array of path mappings between the frontend path and
    the backend path (see below)
* `apis.settings` - A configuration object which contains various settings for
    this API. Notably, these are _per_ API. They are merged on top of (or in
    addition to) the same keys found in `default_api_backend_settings`, which provides
    gatekeeper-wide defaults. See `default_api_backend_settings` for more.

### apis.url_matches
These objects have two fields, a `frontend_prefix` and a `backend_prefix`.
When requests hit gatekeeper with a path beginning with the `frontend_prefix`
they will get proxied to the corresponding `backend_prefix`. You might think
of this as a prefix-only search-and-replace.

## default_api_backend_settings
These are the default settings to use across APIs. Individual APIs can
override them or append to them via `apis.settings`.

* `default_api_backend_settings.rate_limit_bucket_name` - This provides an explicit bucket for api
    rate limits to count against. Defaults to the `frontend_host` associated
    with the api.
* `default_api_backend_settings.rate_limits` - An array of configurations for how to limit the default
    user (individual API keys might have their own restrictions/permissions).
    See below for details on these configurations

### default_api_backend_settings.rate_limits
Calculating usage rates involves some practical limitations. Notably, we don't
want to create a new record for every request; we really only need a counter.
To implement that, the timeline is cut into evenly-sized, indexable periods
(of size `accuracy` milliseconds). Daily usage, then, is the summation of the
usage counts for each of the periods between now and 24 hours ago.

* `default_api_backend_settings.rate_limits.duration` - This is the length of time (in
    milliseconds) over which a usage rate should be calculated.
* `default_api_backend_settings.rate_limits.accuracy` - Effectively, the granularity (in
    milliseconds) to split the timeline. The smaller granularity, the more
    frequently a user' requests are forgotten
* `default_api_backend_settings.rate_limits.limit_by` - what we should bucket requests by.
    Options include `ip` and `apiKey`, which count each request towards the
    associated IP address or API key's rate limits.
* `default_api_backend_settings.rate_limits.limit` - the number of requests allowed for this
    `limit_by` over a period of `duration`
* `default_api_backend_settings.rate_limits.distributed` - a boolean, indicating whether or
    not this limit should be aggregated between multiple servers. Generally,
    this should only be false for very small `durations`
* `default_api_backend_settings.rate_limits.response_headers` - a boolean, indicating whether
    or not the rate limit and remaining number of requests should be added as
    headers to the response
