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
    :version => "0.10.5",
    :checksum_linux_x64 => "182b0992401ff04a288b5777e2892f14d912a509a6c15edc7c0daded3a20d3c7",
  },
})

