# Load DSL and Setup Up Stages
require "capistrano/setup"

# Includes default deployment tasks
require "capistrano/deploy"

# Includes additional plugins
require "capistrano/npm"

# Loads custom tasks from `lib/capistrano/tasks" if you have any defined.
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
