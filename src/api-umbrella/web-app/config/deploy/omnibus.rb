role :app, ["#{ENV["USER"]}@localhost"]
role :web, ["#{ENV["USER"]}@localhost"]
role :db, []

set :keep_releases, 1

Rake::Task["deploy:restart"].clear_actions
namespace :deploy do
  task :restart do
    # There's nothing to reload on a fresh omnibus install, so disable the
    # restart task.
  end
end
