require "dotenv"
Dotenv.load

# config valid only for current version of Capistrano
lock "3.3.5"

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

  # Reset Ruby related environment variables. This is in case the system being
  # deployed to has something like rvm/rbenv/chruby in place. This ensures that
  # we're using our API Umbrella bundled version of Ruby on PATH rather than
  # another version.
  "GEM_PATH" => "/opt/api-umbrella/embedded/lib/ruby/gems/*",
  "RUBY_ROOT" => "",
  "RUBYLIB" => "",

  # The real secret tokens are read from the api-umbrella config file when the
  # web app is started. But for rake task purposes (like asset precompilation
  # where these don't matter), just set some dummy values during deploy.
  "RAILS_SECRET_TOKEN" => "TEMP",
  "DEVISE_SECRET_KEY" => "TEMP",
})

# Default value for keep_releases is 5
set :keep_releases, 15

set :ssh_options, {
  :forward_agent => true,
}

set :assets_prefix, "web-assets"

namespace :deploy do
  # The ember-rails gem's handling of temp files isn't ideal when multiple users
  # might touch the files. So for now, just make these temp files globally
  # writable. See:
  # https://github.com/emberjs/ember-rails/issues/315#issuecomment-47703370
  # https://github.com/emberjs/ember-rails/pull/357
  task :ember_permissions do
    on roles(:app) do
      execute "mkdir -p #{release_path}/tmp/ember-rails && chmod -R 777 #{release_path}/tmp/ember-rails"
    end
  end

  after :updated, :ember_permissions

  desc "Restart application"
  task :restart do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute :sudo, "api-umbrella reload --web"
    end
  end

  after :publishing, :restart
end
