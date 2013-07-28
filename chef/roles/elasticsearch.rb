name "elasticsearch"
description "A default role for elasticsearch"

run_list([
  "role[java]",
  "recipe[elasticsearch]",
  "recipe[iptables::elasticsearch]",
])

default_attributes({
  :elasticsearch => {
    :version => "0.90.2",
    :checksum => "22ebe4cd49015d118b5a5f7179688337ff48fe96caad161dc0ab70553d9b95c2",
  },
})
