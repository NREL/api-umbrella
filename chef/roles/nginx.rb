name "nginx"
description "A minimal role for all nginx servers."

run_list([
  "recipe[nginx::source]",
])

default_attributes({
  :nginx => {
    :install_method => "source",

    :user => "www-data-local",

    :version => "1.4.4",
    :source => {
      :version => "1.4.4",
      :checksum => "7c989a58e5408c9593da0bebcd0e4ffc3d892d1316ba5042ddb0be5b0b4102b9",
      :modules => [
        "nginx::headers_more_module",
        "nginx::http_echo_module",
        "nginx::http_realip_module",
        "nginx::http_stub_status_module",
        "nginx::x_rid_header_module",
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
      :addresses => ["10.0.0.0/16"],
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
