name "elasticsearch"
description "A default role for elasticsearch"

run_list([
  "role[java]",
  "recipe[elasticsearch]",
  "recipe[iptables::elasticsearch]",
])

default_attributes({
  :elasticsearch => {
    :version => "0.90.3",
    :checksum => "5ad8012919e20a17bd470a88ff090b896ad23c024e8d4dbef9e4d3edc9b5d9d0",
  },
})
