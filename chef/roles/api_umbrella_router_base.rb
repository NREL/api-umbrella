name "api_umbrella_router_base"
description "A base role for API Umbrella router servers"

run_list([
  "role[base]",

  "role[haproxy]",
  "role[nginx]",
  "role[nodejs]",
  "role[redis_server]",
  "role[supervisor]",
])

default_attributes({
  :rsyslog => {
    :network => {
      :enable => true,
    },
  },
})
