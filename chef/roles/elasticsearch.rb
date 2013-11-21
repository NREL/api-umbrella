name "elasticsearch"
description "A default role for elasticsearch"

run_list([
  "role[java]",
  "recipe[elasticsearch]",
  "recipe[iptables::elasticsearch]",
])

default_attributes({
  :elasticsearch => {
    :version => "0.90.7",
    :checksum => "d76e8805ba846ae4c1efd848b608d8ade6de6e538ab023c24b3315f557e71cbd",
  },
})
