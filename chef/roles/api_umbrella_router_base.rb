name "api_umbrella_router_base"
description "A base role for API Umbrella router servers"

run_list([
  "role[base]",

  "role[nginx]",
  "role[nodejs]",
  "role[redis_server]",
  "role[supervisor]",
  "role[varnish]",

  "recipe[api-umbrella::router]",
  "recipe[geoip::nodejs]",
])

default_attributes({
  :api_umbrella => {
    :gatekeeper => {
      :logrotate_paths => [
        "/srv/api-umbrella-router/current/log/gatekeeper/production.log",
        "/srv/api-umbrella-router/current/log/gatekeeper/staging.log",
        "/srv/api-umbrella-router/current/log/gatekeeper/development.log",
      ],
    },
  },

  :nginx => {
    # Allow for longer host names
    :server_names_hash_bucket_size => 128,

    :logrotate => {
      :extra_paths => [
        "/srv/api-umbrella-router/current/log/*.log",
        "/srv/api-umbrella-router/current/log/gatekeeper/access.log",
        "/srv/api-umbrella-router/current/log/gatekeeper/error.log",
        "/srv/api-umbrella-router/current/log/gatekeeper/router.log",
      ],
    },
  },

  :rsyslog => {
    :network => {
      :enable => true,
    },
  },

  :supervisor => {
    :logrotate => {
      :extra_paths => [
        "/srv/api-umbrella-router/current/log/gatekeeper/supervisor.log",
      ],
    },
  },
})
