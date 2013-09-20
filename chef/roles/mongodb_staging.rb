name "mongodb_staging"
description "A minimal role for all mongodb servers."

default_attributes({
  :iptables => {
    :mongodb => {
      :allowed_hosts => [
        "10.0.0.0/16",
      ],
    },
  },
})

override_attributes({
  :mongodb => {
    :cluster_name => "apidatagov-staging",
    :replicaset_name => "apidatagov-staging",
  },
})
