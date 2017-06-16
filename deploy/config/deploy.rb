require "dotenv"
Dotenv.load

# config valid only for current version of Capistrano
lock "3.6.1"

set :application, "api-umbrella"

# Use rsync to copy the local repo to the servers (rather than checking the
# repo out directly on the server). This allows for the deployments to work
# from custom forks without having to update the URL.
set :scm, :rsync
set :repo_url, "file://#{File.expand_path("../../../", __FILE__)}"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/opt/api-umbrella/embedded/apps/core"

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, fetch(:linked_files, []).push("config/database.yml", "config/secrets.yml")

# Default value for linked_dirs is []
# set :linked_dirs, fetch(:linked_dirs, []).push()

# Default value for default_env is {}
set :default_env, fetch(:default_env, {}).merge({
  "PATH" => "/opt/api-umbrella/bin:/opt/api-umbrella/embedded/bin:$PATH",

  # Reset Ruby related environment variables. This is in case the system being
  # deployed to has something like rvm/rbenv/chruby in place. This ensures that
  # we're using our API Umbrella bundled version of Ruby on PATH rather than
  # another version.
  "GEM_PATH" => "/opt/api-umbrella/embedded/lib/ruby/gems/*",
  "RUBY_ROOT" => "",
  "RUBYLIB" => "",
})

# Default value for keep_releases is 5
set :keep_releases, 15

namespace :deploy do
  task :build do
    on roles(:app) do
      execute "mkdir", "-p", "#{shared_path}/deploy-build"

      # We must wipe cmake's cache file, since the `release_path` changes on
      # each deployment.
      execute "rm", "-f", "#{shared_path}/deploy-build/CMakeCache.txt"

      # Run our normal build process, but tweaked slightly for these type of
      # live deployments (so it only builds the core application release, and
      # does not compile all the software dependencies).
      within "#{shared_path}/deploy-build" do
        execute "#{release_path}/configure", "--enable-deploy-only"
        execute "make"
      end

      # The normal build process creates a staged version of a new "release".
      # Since we're running this inside Capistrano, which has already created a
      # release for us, this is a bit funky, but essentially we're going to
      # overwrite the current Capistrano release with the staged version from
      # the build prprocess (so the release process is consistent regardless of
      # whether the release comes from the package or a Capistrano deploy).
      execute "rsync", "-a", "-v", "--delete", "#{shared_path}/deploy-build/build/work/stage/opt/api-umbrella/embedded/apps/core/releases/0/", "#{release_path}/"
      execute "rsync", "-a", "-v", "--delete", "#{shared_path}/deploy-build/build/work/stage/opt/api-umbrella/embedded/apps/core/shared/vendor/", "#{shared_path}/vendor/"
    end
  end
  before :updated, :build

  desc "Reload application"
  task :reload do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute :sudo, "api-umbrella reload"
      execute "api-umbrella health --wait-for-status green"
    end
  end
  after :publishing, :reload
end
