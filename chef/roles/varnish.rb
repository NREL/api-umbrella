name "varnish"
description "A minimal role for all varnish servers."

run_list([
  "recipe[varnish]",
  "recipe[varnish::ban]",
])

default_attributes({
  :varnish => {
    :backend_port => 50100,

    # Don't set a default TTL so responses won't be cached unless a header
    # explicitly says to. We want the API Umbrella proxy to be as transparent as
    # possible, so caching should be opt-in only.
    :ttl => 0,


    # Attempt to work around the ocassional random crash:
    # https://www.varnish-cache.org/trac/ticket/1119
    :cli_timeout => 60,
  },
})
