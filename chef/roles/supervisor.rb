name "supervisor"
description "A minimal role for all supervisor servers."

run_list([
  "recipe[supervisor]",
])
