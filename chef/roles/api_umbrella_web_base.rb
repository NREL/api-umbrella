name "api_umbrella_web_base"
description "A base role for API Umbrella web servers"

run_list([
  "role[base]",

  "role[nginx]",
  "role[torquebox]",
  "role[ruby]",

  "recipe[pygments]",
  "recipe[xml]",
])

default_attributes({
  :nginx => {
    :listen => 8082,
  },

  :torquebox => {
    :append_java_opts => [
      "-Xmn256m",
      "-Xms512m",
      "-Xmx512m",
    ],
  },
})
