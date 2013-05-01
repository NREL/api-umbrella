name "elasticsearch"
description "A default role for nodejs"

run_list([
  "role[java]",
  "recipe[elasticsearch]",
])

default_attributes({
  :elasticsearch => {
    :version => "0.90.0",
  },
})
