name "nginx"
description "A minimal role for all nginx servers."

run_list([
  "recipe[nginx::source]",
])

default_attributes({
  :nginx => {
    :install_method => "source",

    :version => "1.2.9",

    :user => "www-data-local",

    :source => {
      :checksum => "71486674b757f6aa93a4f7ec6e68ef82557d4944deeb08f3ad3de00079d22b1c",
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
