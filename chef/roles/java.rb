name "java"
description "A default role for java"

run_list([
  "recipe[java]",
])

default_attributes({
  :java => {
    :jdk_version => "7",
  },
})
