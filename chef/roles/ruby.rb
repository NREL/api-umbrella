name "ruby"
description "The bare essentials for servers that are using ruby."

run_list([
  "recipe[rbenv::global_version]",
  "recipe[rubygems::client]",
  "recipe[bundler]",
  "recipe[bundler::auto_exec]",
])

default_attributes({
  :rbenv => {
    # Don't use the git:// protocol behind our firewall.
    :git_repository => "http://github.com/sstephenson/rbenv.git",
    :git_revision => "c3fe192243bff9a00866d81af38d9012bfba419a",
    :install_global_version => "1.9.3-p362",
  },
  :ruby_build => {
    # Don't use the git:// protocol behind our firewall.
    :git_repository => "http://github.com/sstephenson/ruby-build.git",
    :version => "20121227",
    :git_revision => "v20121227",
  },
  :rubygems => {
    :version => "1.8.24",
    :default_options => "--no-ri --no-rdoc",
  },
  :bundler => {
    :version => "1.2.3",
  },
})
