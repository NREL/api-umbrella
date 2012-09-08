name "api_umbrella_db_base_development"
description "A base role for development API Umbrella database servers"

run_list([
  "role[api_umbrella_db_base]",
  "role[base_development]",
])

default_attributes({
})
