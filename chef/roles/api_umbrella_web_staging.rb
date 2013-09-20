name "api_umbrella_web_staging"
description "A base role for API Umbrella database servers"

run_list([
  "role[api_umbrella_web_base]",
  "role[mongodb_staging]",
  "role[passenger_nginx_staging]",
])

default_attributes({
  # Environment for envbuilder.
  :ENV => "staging",

  :torquebox => {
    :clustered => true,
    :cluster_name => "apidatagov",
  },
})
