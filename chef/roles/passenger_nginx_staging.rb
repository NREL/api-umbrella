name "passenger_nginx_staging"
description "A default role for passenger through nginx in staging environments."

run_list([
  "role[passenger_nginx]",
])

default_attributes({
  :nginx => {
    :passenger => {
      # Set the default environment variables.
      :rails_env => "staging",
      :rack_env => "staging",
    },
  },
})
