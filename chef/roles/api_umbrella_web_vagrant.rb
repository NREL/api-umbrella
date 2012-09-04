name "api_umbrella_web_vagrant"
description "A role for the local vagrant development ctts instances"

run_list([
  # Run vagrant things first off so the sudoers file doesn't get hosed if chef
  # fails while running.
  "role[vagrant]",

  "role[api_umbrella_web_development]",
])

default_attributes({
  :afdc => {
    :shared_uploads_site_root => "/srv/sites/shared_uploads/current",
  },

  # Use dnsmasq to redirect all local traffic directly to the server to save
  # the cost of a remote DNS lookup.
  :dnsmasq => {
    :addresses => ["/eere.vagrant/127.0.0.1"],
  },
})
