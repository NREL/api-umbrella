name "dotenv"
description "Manage environment specific app configuration settings"

run_list([
  "recipe[envbuilder]",
])

default_attributes({
  # Default environment.
  :ENV => "development",

  :envbuilder => {
    :base_dir => "/home/dotenv",
    :owner => "dotenv",
    :group => "dotenv",
  },
})
