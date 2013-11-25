name "api_umbrella_web_base"
description "A base role for API Umbrella web servers"

run_list([
  "role[base]",

  "role[dotenv]",
  "role[nginx]",
  "role[passenger_nginx]",
  "role[ruby]",

  "recipe[iptables::http]",
  "recipe[iptables::https]",
  "recipe[pygments]",
  "recipe[xml]",
])

default_attributes({
  :nginx => {
    :listen => 8082,

    :logrotate => {
      :extra_paths => [
        "/srv/api-umbrella-web/current/log/*.log",
      ],
    },
  },

  :torquebox => {
    :append_java_opts => [
      "-Xmn256m",
      "-Xms512m",
      "-Xmx512m",
    ],
  },
})
