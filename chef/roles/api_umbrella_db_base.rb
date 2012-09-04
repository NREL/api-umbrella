name "developer_db_base"
description "A base role for developer.nrel.gov database servers."

run_list([
  "role[base]",

  "role[mongodb_server]",
  "role[redis_server]",
])

default_attributes({
  :mongodb => {
    :server => {
      :db_dir => "/srv/developer/db/mongo",
    },
    :backup => {
      :dir => "/srv/developer/backups/mongo",
    },
  },
})
