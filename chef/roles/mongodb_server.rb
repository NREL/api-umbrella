name "mongodb_server"
description "A minimal role for all mongodb servers."

run_list([
  "recipe[mongodb::10gen_repo]",
  "recipe[mongodb]",
  "recipe[iptables::mongodb]",
])

default_attributes({
  :mongodb => {
    :package_version => "2.4.5-mongodb_1",

    :backup => {
      # We should probably revisit this so we can take advtange of oplog
      # backups, but to do that, we need to enable replica sets on the
      # databases.
      :oplog => false,
      :replica_on_slave => false,
    },
  },
})
