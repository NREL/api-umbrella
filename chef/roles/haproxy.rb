name "haproxy"
description "A minimal role for all haproxy servers."

run_list([
  "recipe[haproxy]",
])
