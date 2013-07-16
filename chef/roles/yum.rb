name "yum"
description "A base role for yum setup on all servers."

run_list([
  # Plugin for picking out only security updates
  "recipe[yum::security]",
])

default_attributes({
})
