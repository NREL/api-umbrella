name "haproxy"
description "A minimal role for all haproxy servers."

run_list([
  "recipe[haproxy]",
])

default_attributes({
  :haproxy => {
    :install_method => "source",
    :source => {
      :version => "1.5-dev18",
      :url => "http://haproxy.1wt.eu/download/1.5/src/devel/haproxy-1.5-dev18.tar.gz",
      :checksum => "b18bf513585d36b9c4c8a74c3c7b4ad5ac6ebe86339d70894a1cdee74071629f",
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
