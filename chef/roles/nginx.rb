name "nginx"
description "A minimal role for all nginx servers."

run_list([
  "recipe[nginx::source]",
])

default_attributes({
  :nginx => {
    :install_method => "source",

    :version => "1.4.2",

    :user => "www-data-local",

    :source => {
      :checksum => "5361ffb7b0ebf8b1a04369bc3d1295eaed091680c1c58115f88d56c8e51f3611",
      :modules => [
        "headers_more_module",
        "http_echo_module",
        "http_realip_module",
        "http_stub_status_module",
        "x_rid_header_module",
      ],
    },

    :worker_processes => 4,
    :gzip_disable => "msie6",

    # Append file types to the list that will be gzipped by default.
    :gzip_types => [
      "text/csv",
    ],

    :realip => {
      :real_ip_recursive => "on",
    },
  },
})

override_attributes({
  :nginx => {
    :source => {
      :prefix => "/opt/nginx",
    },
  },
})
