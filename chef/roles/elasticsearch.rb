name "elasticsearch"
description "A default role for elasticsearch"

run_list([
  "role[java]",
  "recipe[elasticsearch]",
  "recipe[iptables::elasticsearch]",
])

default_attributes({
  :elasticsearch => {
    :version => "0.90.5",
    :checksum => "f14ff217039b5c398a9256b68f46a90093e0a1e54e89f94ee6a2ee7de557bd6d",
  },
})
