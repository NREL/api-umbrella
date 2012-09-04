name "base"
description "A base role all servers."

run_list([
  # Manage the sudoers file
  "recipe[sudo]",
  "recipe[sudo::nrel_defaults]",
  "recipe[sudo::secure_path]",
  "recipe[sudo::afdc_deployment]",

  # Default iptables setup on all servers.
  "recipe[iptables]",
  "recipe[iptables::ssh]",
  "recipe[iptables::icmp_timestamps]",

  # All nodes should be configured as a chef client.
  "recipe[chef-client::config]",

  # Manage misc /etc files.
  "recipe[etc::environment]",

  # Setup log rotation.
  "recipe[logrotate]",

  # man pages are handy.
  "recipe[man]",

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
  },
  # Rotate and compress logs daily by default.
  :logrotate => {
    :frequency => "daily",
    :rotate => 30,
    :compress => true,
    :delaycompress => true,
  },
})

override_attributes({
  :chef_client => { :server_url => "http://chef.devdev.nrel.gov" },
})
