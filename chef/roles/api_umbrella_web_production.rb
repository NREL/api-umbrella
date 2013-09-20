name "api_umbrella_web_production"
description "A base role for API Umbrella database servers"

run_list([
  "role[api_umbrella_web_base]",
  "role[mongodb_production]",
  "role[passenger_nginx_production]",
])

default_attributes({
  # Environment for envbuilder.
  :ENV => "production",

  :torquebox => {
    :clustered => true,
    :cluster_name => "apidatagov",
  },
})
