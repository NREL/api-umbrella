name "developer_web_development"
description "A role for the development developer web servers, devdev.nrel.gov."

run_list([
  "role[api_umbrella_web_base]",
])

default_attributes({
  :chef_client => {
    :cache_path => "/srv/developer/chef/cache",
    :backup_path => "/srv/developer/chef/backup",
  },
  :chef_server => {
    :path => "/srv/developer/chef",
    :cache_path => "/srv/developer/chef/cache",
    :backup_path => "/srv/developer/chef/backup",
  },
  :docs_site => {
    :host => "docs.devdev.nrel.gov",
    :root => "/srv/developer/devdev/docs",
  },

  :vagrant_extras => {
    :boxes_server => {
      :host => "vagrant.devdev.nrel.gov",
      :root => "/srv/developer/devdev/vagrant",
    },
  },
  :mysql => {
    :data_dir => "/srv/developer/db/mysql",
  },
})

override_attributes({
  :nginx => {
    :logrotate => {
      :extra_paths => [
        "/srv/developer/devdev/developer_router/current/log/ssl_proxy-*.log",
        "/srv/developer/devdev/common/*/current/log/*.log",
        "/srv/developer/devdev/sandboxes/*/*/current/log/*.log",
      ],
    },
  },
  :supervisor => {
    :logrotate => {
      :extra_paths => [
        "/srv/developer/devdev/developer_router/current/log/*-auth_proxy_*.log",
      ],
    },
  },
})
