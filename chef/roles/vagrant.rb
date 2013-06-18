name "vagrant"
description "A role for the local vagrant development instances"

run_list([
  "recipe[vagrant_extras]",
  "recipe[vagrant_extras::ssl_cert]",
  "recipe[vagrant_extras::passwordless_internal_ssh]",
])

default_attributes({
})

# Run everything as the vagrant user, so the file permissions match the user
# that owns all the files on the shared folders.
override_attributes({
  :common_writable_group => "vagrant",
  :nginx => {
    :user => "vagrant",
  },
  :passenger => {
    :default_user => "vagrant",
  },
  :php => {
    :fpm_user => "vagrant",
    :fpm => {
      :www => {
        :user => "vagrant",
        :group => "vagrant",
      },
    },
  },
  :spawn_fcgi => {
    :user => "vagrant",
    :group => "vagrant",
  },

  :elasticsearch => {
    :allocated_memory => "512m",
  },

  :torquebox => {
    :backstage => {
      :password => "admin",
    },
  },
})
