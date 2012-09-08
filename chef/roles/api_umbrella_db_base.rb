name "api_umbrella_db_base"
description "A base role for API Umbrella database servers"

run_list([
  "role[base]",

  "role[mongodb_server]",
  "role[redis_server]",
])

default_attributes({
})
