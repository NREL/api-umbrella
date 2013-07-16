name "base"
description "A base role all servers."

run_list([
  # Ensure any custom root certificate changes get made prior to any HTTPS
  # calls.
  "recipe[ca_certificates]",

  # Manage the sudoers file
  "recipe[sudo]",
  "recipe[sudo::nrel_defaults]",
  "recipe[sudo::secure_path]",

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

  # Standardize the shasum implementation (used for deployments).
  "recipe[shasum]",

  # Screen is always nice to have for background processes.
  "recipe[screen]",

  # A much nicer replacement for grep.
  "recipe[ack]",

  # Default editors that are handy to have on all servers.
  "recipe[vim]",
  "recipe[nano]",

  # Unzip is typically handy to have.
  "recipe[unzip]",
])

default_attributes({
  :authorization => {
    :sudo => {
      :include_sudoers_d => true,
      :groups => [
        "wheel",
        "UnixISODesktopAdmins",
        "UnixISOServerAdmins",
        "rsa",
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
})
