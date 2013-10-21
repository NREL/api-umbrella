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
    :version => "0.10.21",
    :checksum_linux_x64 => "2791efef0a1e9a9231b937e55e5b783146e23291bca59a65092f8340eb7c87c8",
  },
})

