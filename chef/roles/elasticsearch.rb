name "elasticsearch"
description "A default role for elasticsearch"

run_list([
  "role[java]",
  "recipe[elasticsearch]",
  "recipe[iptables::elasticsearch]",
])

default_attributes({
  :elasticsearch => {
    :version => "0.90.6",
    :checksum => "2ff87847e993d52723b4e789db3cbba887f414b85bf04fd897032bc52fe0ad3a",
  },
})
