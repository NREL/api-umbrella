name "api_umbrella_log_staging"
description "A base role for API Umbrella database servers"

run_list([
  "role[api_umbrella_log_base]",
])

default_attributes({
  :elasticsearch => {
    :custom_config => {
      "discovery.zen.ping.multicast.enabled" => false,
      "discovery.zen.ping.unicast.hosts" => ["10.0.10.159", "10.0.11.105"],
    },
  },
})
