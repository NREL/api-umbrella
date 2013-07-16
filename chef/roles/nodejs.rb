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
    :version => "0.10.13",
    :checksum_linux_x64 => "dcbad86b863faf4a1e10fec9ecd7864cebbbb6783805f1808f563797ce5db2b8",
  },
})

