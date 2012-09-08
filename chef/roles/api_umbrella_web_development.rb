name "api_umbrella_web_development"
description "A role for development API Umbrella web servers"

run_list([
  "role[api_umbrella_web_base]",
  "role[base_development]",
])

default_attributes({
})
