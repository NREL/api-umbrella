name "api_umbrella_db_development"
description "A role for the development developer database servers, devdev-db.nrel.gov."

run_list([
  "role[api_umbrella_db_base]",
])

default_attributes({
  :developer => {
    :database => {
      :environment => "development",
    },
  },
  :iptables => {
    :redis => {
      # devdev.nrel.gov
      :allowed_hosts => ["10.20.5.138"],
    },
    :mongodb => {
      # devdev.nrel.gov
      :allowed_hosts => ["10.20.5.138"],
    },
  },
})
