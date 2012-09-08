name "api_umbrella_db_vagrant"
description "A role for local development API Umbrella database servers running in Vagrant"

run_list([
  # Run vagrant things first off so the sudoers file doesn't get hosed if chef
  # fails while running.
  "role[vagrant]",

  "role[api_umbrella_db_base_development]",
])

default_attributes({
  # Use dnsmasq to redirect all local traffic directly to the server to save
  # the cost of a remote DNS lookup.
  :dnsmasq => {
    :addresses => ["/api.vagrant/127.0.0.1"],
  },
})
