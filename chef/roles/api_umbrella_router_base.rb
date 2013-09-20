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
  :nginx => {
    # Allow for longer host names
    :server_names_hash_bucket_size => 128,
  },

  :rsyslog => {
    :network => {
      :enable => true,
    },
  },
})
