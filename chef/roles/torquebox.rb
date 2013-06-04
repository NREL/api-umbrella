name "torquebox"
description "A role for torquebox servers"

run_list([
  "role[java]",

  # Use node.js for execjs (this is faster than therubyrhino).
  # Hopefully revisit once Nashorn is more of a reality.
  "role[nodejs]",

  # Used by the capistrano torquebox recipe to watch files.
  "recipe[inotify_tools]",

  # Some sudo things the capistrano torquebox recipe needs.
  "recipe[sudo::torquebox_deployment]",

  "recipe[iptables::torquebox]",
  "recipe[torquebox]",

  "recipe[torquebox::backstage]",
])

default_attributes({
  :rbenv => {
    :rubies => ["jruby-1.7.4"],
  },

  :torquebox => {
    :rbenv_version => "jruby-1.7.4",
    :http_port => 8180,
    :bind_ip => "127.0.0.1",
  },
})
