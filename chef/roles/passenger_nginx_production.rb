name "passenger_nginx_production"
description "A default role for passenger through nginx in production environments."

run_list([
  "role[passenger_nginx]",
])

default_attributes({
  :nginx => {
    :passenger => {
      # Set the default environment variables.
      :rails_env => "production",
      :rack_env => "production",
    },
  },
})
