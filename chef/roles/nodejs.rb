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
    :version => "0.10.22",
    :checksum_linux_x64 => "ca5bebc56830260581849c1099f00d1958b549fc59acfc0d37b1f01690e7ed6d",
  },
})

