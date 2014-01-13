name "base_development"
description "A base role all development servers."

run_list([
  "role[base]",

  # Accept all incoming connections on development servers, so we're more free
  # to play with servers on different ports.
  "recipe[iptables::accept_all]",

  # Additional shells
  "recipe[zsh]",
])

default_attributes({
})
