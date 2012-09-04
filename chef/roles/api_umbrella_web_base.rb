name "api_umbrella_web_base"
description "A base role for developer.nrel.gov web servers."

run_list([
  "role[base]",

  "role[haproxy]",
  "role[nginx]",
  "role[passenger_nginx_module]",
  "role[ruby]",
  "role[supervisor]",

  "recipe[pygments]",
])

default_attributes({
  :nginx => {
    :version => "1.2.3",
    :listen => 8082,
  },

  :passenger => {
    :version => "3.0.17",
  },

  :rsyslog => {
    :network => {
      :enable => true,
    },
  },
})
