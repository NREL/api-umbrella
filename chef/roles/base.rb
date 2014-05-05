name "base"
description "A base role all servers."

run_list([
  # Keep the Chef omnibus installation up-to-date.
  "recipe[omnibus_updater]",

  # Default iptables setup on all servers.
  "recipe[iptables]",
  "recipe[iptables::ssh]",
  "recipe[iptables::icmp_timestamps]",

  # All nodes should be configured as a chef client.
  "recipe[chef-client::config]",

  # Manage misc /etc files.
  "recipe[etc::environment]",

  # Default setup for yum on all servers.
  "role[yum]",

  # Setup log rotation.
  "recipe[logrotate]",

  # For fetching and committing our code.
  "recipe[git]",

  # man pages are handy.
  "recipe[man]",

  # Ensure ntp is used to keep clocks in sync.
  "recipe[ntp]",

  # Screen is always nice to have for background processes.
  "recipe[screen]",

  # A much nicer replacement for grep.
  "recipe[ack]",

  # Default editors that are handy to have on all servers.
  "recipe[vim]",
  "recipe[nano]",
])

default_attributes({
  :authorization => {
    :sudo => {
      :include_sudoers_d => true,
      :groups => [
        "wheel",
      ],
    },
  },

  :chef_client => {
    :verbose_logging => false,
    :server_url => "https://api.opscode.com/organizations/apidatagov",
    :validation_client_name => "apidatagov-validator",
  },

  # Rotate and compress logs daily by default.
  :logrotate => {
    :frequency => "daily",
    :rotate => 30,
    :compress => true,
    :delaycompress => true,
  },

  :omnibus_updater => {
    :version => "11.12.4",
    :always_download => false,
    :remove_chef_system_gem => true,
  },
})
