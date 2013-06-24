name "mongodb_replicaset"
description "A minimal role for all mongodb servers."

run_list([
  "role[mongodb_server]",
  "recipe[mongodb::replicaset]",
])

default_attributes({
  :mongodb => {
    :cluster_name => "apidatagov",
    :replicaset_name => "apidatagov",
  },
})
