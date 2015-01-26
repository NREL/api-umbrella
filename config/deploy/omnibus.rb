role :app, ["#{ENV["USER"]}@localhost"]
role :web, ["#{ENV["USER"]}@localhost"]
role :db, []

namespace :deploy do
  task :restart do
    # There's nothing to reload on a fresh omnibus install, so disable the
    # restart task.
  end
end
