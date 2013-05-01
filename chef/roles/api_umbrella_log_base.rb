name "api_umbrella_log_base"
description "A base role for API Umbrella database servers"

run_list([
  "role[base]",

  "role[elasticsearch]",
])

default_attributes({
})
