name "mongodb_arbiter"
description "A minimal role for all mongodb servers."

run_list([
  "role[mongodb_server]",
  "recipe[mongodb::arbiter]",
  "role[mongodb_replicaset]",
])

default_attributes({
  :mongodb => {
    # Don't enable journaling on arbiters, since it's unneeded and leads to the
    # consumption of 3GB of disk: https://jira.mongodb.org/browse/SERVER-3831
    :nojournal => true,
  },
})
