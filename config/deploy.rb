require "dotenv"
Dotenv.load

# config valid only for current version of Capistrano
lock "3.3.3"

set :application, "web"
set :repo_url, "https://github.com/NREL/api-umbrella-web.git"
set :branch, "master"

# Default deploy_to directory is /var/www/my_app
set :deploy_to, "/opt/api-umbrella/embedded/apps/web"

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w(bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system)

# Default value for default_env is {}
fetch(:default_env).merge!({
  "PATH" => "/opt/api-umbrella/bin:/opt/api-umbrella/embedded/bin:$PATH",
})

# Default value for keep_releases is 5
set :keep_releases, 15

set :ssh_options, {
  :forward_agent => true,
}

set :assets_prefix, "web-assets"

namespace :deploy do
  desc "Restart application"
  task :restart do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute :sudo, "api-umbrella reload --web"
    end
  end

  after :publishing, :restart
end
