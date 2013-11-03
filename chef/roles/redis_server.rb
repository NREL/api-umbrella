name "redis_server"
description "A minimal role for all redis servers."

run_list([
  "recipe[redisio::install]",
  "recipe[redisio::enable]",
])

default_attributes({
  :redisio => {
    :mirror => "http://download.redis.io/releases",
    :version => "2.6.16",
    :install_dir => "/opt/redis",
    :safe_install => false,
  },
})
