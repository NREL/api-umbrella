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
    :git_revision => "6778c8e905d774d4dc70724c455e6fcff4c1d3e1",
    :install_global_version => "1.9.3-p194",
  },
  :ruby_build => {
    # Don't use the git:// protocol behind our firewall.
    :git_repository => "http://github.com/sstephenson/ruby-build.git",
    :version => "20120815",
    :git_revision => "v20120815",
  },
  :rubygems => {
    :version => "1.8.24",
    :default_options => "--no-ri --no-rdoc",
  },
  :bundler => {
    :version => "1.1.5",
  },
})
