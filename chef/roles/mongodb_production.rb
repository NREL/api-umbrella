name "mongodb_production"
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
