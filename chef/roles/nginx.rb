name "nginx"
description "A minimal role for all nginx servers."

run_list([
  "recipe[nginx::source]",
])

default_attributes({
  :nginx => {
    :install_method => "source",

    :version => "1.0.11",

    :user => "www-data-local",

    :source => {
      :modules => [
        "http_realip_module",
        "http_stub_status_module",
      ],
    },

    :worker_processes => 4,
    :gzip_disable => "msie6",

    # Append file types to the list that will be gzipped by default.
    :gzip_types => [
      "text/csv",
    ],
  },
})

override_attributes({
  :nginx => {
    :source => {
      :prefix => "/opt/nginx",
    },
  },
})
