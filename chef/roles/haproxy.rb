name "haproxy"
description "A minimal role for all haproxy servers."

run_list([
  "recipe[haproxy]",
])

default_attributes({
  :haproxy => {
    :install_method => "source",
    :source => {
      :version => "1.5-dev19",
      :url => "http://haproxy.1wt.eu/download/1.5/src/devel/haproxy-1.5-dev19.tar.gz",
      :checksum => "cb411f3dae1309d2ad848681bc7af1c4c60f102993bb2c22d5d4fd9f5d53d30f",
      :prefix => "/opt/haproxy",
      :target_os => "linux2628",
      :target_cpu => "native",
      :use_pcre => true,
      :use_zlib => true,
      :use_openssl => true,
    },
  },
})

override_attributes({
  :haproxy => {
    :conf_dir => "/etc/haproxy",
  },
})
