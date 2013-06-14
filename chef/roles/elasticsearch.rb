name "elasticsearch"
description "A default role for elasticsearch"

run_list([
  "role[java]",
  "recipe[elasticsearch]",
  "recipe[iptables::elasticsearch]",
])

default_attributes({
  :elasticsearch => {
    :version => "0.90.1",
  },
})
