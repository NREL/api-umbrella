name "nodejs"
description "A default role for nodejs"

run_list([
  "recipe[nodejs]",
  "recipe[nodejs::profile_path]",
])

default_attributes({
  :nodejs => {
    :install_method => "binary",
    :dir => "/opt/nodejs",
    :version => "0.10.11",
    :checksum_linux_x64 => "0fa2be9b44d6acd4bd43908bade00053de35e6e27f72a2dc41d072c86263b52a",
  },
})

