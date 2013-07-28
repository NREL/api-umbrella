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
    :version => "0.10.15",
    :checksum_linux_x64 => "0b5191748a91b1c49947fef6b143f3e5e5633c9381a31aaa467e7c80efafb6e9",
  },
})

