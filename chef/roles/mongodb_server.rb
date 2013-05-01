name "mongodb_server"
description "A minimal role for all mongodb servers."

run_list([
  "recipe[mongodb::server]",
  "recipe[mongodb::backup]",
])

default_attributes({
  :mongodb => {
    :client => {
      :version => "2.4.3-mongodb_1",
    },

    :server => {
      :version => "2.4.3-mongodb_1",
    },

    :backup => {
      # We should probably revisit this so we can take advtange of oplog
      # backups, but to do that, we need to enable replica sets on the
      # databases.
      :oplog => false,
      :replica_on_slave => false,
    },
  },
})
