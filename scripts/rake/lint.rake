namespace :lint do
  desc "Lint JavaScript files using eslint"
  task :js do
    require "childprocess"
    require "rainbow"

    print "Checking admin-ui... "
    process = ChildProcess.build("yarn", "run", "lint:js")
    process.cwd = File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/admin-ui")
    process.io.inherit!
    process.start
    process.wait
    exit(process.exit_code) if(process.crashed?)
    puts Rainbow("OK").green.bright
  end

  desc "Lint Lua files using luacheck"
  task :lua do
    require "childprocess"

    lua_files = `git ls-files #{API_UMBRELLA_SRC_ROOT} | grep "\\.lua$"`.split("\n")
    process = ChildProcess.build("build/work/test-env/vendor/bin/luacheck", *lua_files)
    process.cwd = API_UMBRELLA_SRC_ROOT
    process.environment["LUA_PATH"] = "build/work/test-env/vendor/share/lua/5.1/?.lua;build/work/test-env/vendor/share/lua/5.1/?/init.lua;;"
    process.environment["LUA_CPATH"] = "build/work/test-env/vendor/lib/lua/5.1/?.so;;"
    process.io.inherit!
    process.start
    process.wait
    exit(process.exit_code) if(process.crashed?)
  end

  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:ruby) do |t|
    t.patterns = [
      File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/web-app/**/*.rb"),
      File.join(API_UMBRELLA_SRC_ROOT, "test/**/*.rb"),
      File.join(API_UMBRELLA_SRC_ROOT, "Rakefile"),
      File.join(API_UMBRELLA_SRC_ROOT, "script/rake/*.rb"),
      File.join(API_UMBRELLA_SRC_ROOT, "script/rake/*.rake"),
    ]
    t.options = [
      "--display-cop-names",
      "--extra-details",
    ]
  end

  desc "Lint shell files using shellcheck"
  task :shell do
    require "childprocess"
    require "rainbow"

    # Ignore certain vendored files for linting.
    ignore_files = [
      "configure",
    ]

    ["sh", "bash"].each do |shell|
      shell_files = `git grep -l "^#\!/bin/#{shell}" #{API_UMBRELLA_SRC_ROOT}`.split("\n")
      shell_files += `git grep -l "^#\!/usr/bin/env #{shell}" #{API_UMBRELLA_SRC_ROOT}`.split("\n")
      shell_files -= ignore_files

      if(shell_files.any?)
        print "Checking (#{shell}): #{shell_files.join(" ")}... "
        process = ChildProcess.build("build/work/test-env/bin/shellcheck", "-s", shell, *shell_files)
        process.cwd = API_UMBRELLA_SRC_ROOT
        process.io.inherit!
        process.start
        process.wait
        exit(process.exit_code) if(process.crashed?)
        puts Rainbow("OK").green.bright
      end
    end
  end
end

desc "Lint all source code for errors and style"
task :lint do
  Rake::Task["lint:lua"].invoke
  Rake::Task["lint:ruby"].invoke
  Rake::Task["lint:js"].invoke
  Rake::Task["lint:shell"].invoke
end
