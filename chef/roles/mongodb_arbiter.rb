name "mongodb_arbiter"
description "A minimal role for all mongodb servers."

run_list([
  "role[mongodb_server]",
  "recipe[mongodb::arbiter]",
  "role[mongodb_replicaset]",
])

default_attributes({
})
