name "api_umbrella_web_base_development"
description "A base role for development API Umbrella web servers"

run_list([
  "role[api_umbrella_web_base]",
  "role[base_development]",
])

default_attributes({
})
