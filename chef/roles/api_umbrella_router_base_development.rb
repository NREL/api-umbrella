name "api_umbrella_router_base_development"
description "A base role for development API Umbrella router servers"

run_list([
  "role[api_umbrella_router_base]",
  "role[base_development]",
])

default_attributes({
})
