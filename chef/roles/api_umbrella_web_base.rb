name "api_umbrella_web_base"
description "A base role for API Umbrella web servers"

run_list([
  "role[base]",

  "role[nginx]",
  "role[passenger_nginx_module]",
  "role[ruby]",

  "recipe[pygments]",
  "recipe[xml]",
])

default_attributes({
  :nginx => {
    :listen => 8082,
  },

  :passenger => {
    :version => "3.0.18",
  },
})
