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
    :version => "0.10.10",
    :checksum_linux_x64 => "ab42335b0e6e45bac62823d995d8062e9ba0344bc416c76a263a5e45773b2e7d",
  },
})

