name "api_umbrella_router_development"
description "A role for development API Umbrella router servers"

run_list([
  "role[api_umbrella_router_base]",
  "role[base_development]",
])

default_attributes({
})
