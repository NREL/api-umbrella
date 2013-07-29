name "yum"
description "A base role for yum setup on all servers."

run_list([
  # Plugin for picking out only security updates
  "recipe[yum::security]",

  # Automatically apply updates from yum every night.
  "recipe[yum::cron]",
])

default_attributes({
  :yum => {
    :cron => {
      # Only apply updates from the official RedHat repos automatically. We
      # assume the RHEL updates are stable, but other repos might not be as
      # stable.
      :yum_parameter => "--disablerepo=* --enablerepo=rhel-* --enablerepo=rhn-tools-rhel-*"
    },
  },
})
