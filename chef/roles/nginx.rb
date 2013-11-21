name "nginx"
description "A minimal role for all nginx servers."

run_list([
  "recipe[nginx::source]",
])

default_attributes({
  :nginx => {
    :install_method => "source",

    :version => "1.4.4",

    :user => "www-data-local",

    :source => {
      :checksum => "4ae123885c923a6c3f5bab0a8b7296ef21c4fdf6087834667ebbc16338177de84",
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
