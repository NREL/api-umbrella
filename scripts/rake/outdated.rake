namespace :outdated do
  namespace "admin-ui" do
    desc "List outdated admin-ui NPM dependencies"
    task :npm do
      require "childprocess"
      process = ChildProcess.build("yarn", "outdated")
      process.cwd = File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/admin-ui")
      process.io.inherit!
      process.start
      process.wait
    end
  end

  namespace "test" do
    desc "List outdated test gem dependencies"
    task :gems do
      require "childprocess"
      Bundler.with_original_env do
        process = ChildProcess.build("bundle", "outdated")
        process.environment["BUNDLE_GEMFILE"] = File.join(API_UMBRELLA_SRC_ROOT, "Gemfile")
        process.environment["BUNDLE_APP_CONFIG"] = File.join(API_UMBRELLA_SRC_ROOT, "tasks/app-deps/web-app/bundle/_persist/.bundle")
        process.io.inherit!
        process.start
        process.wait
      end
    end
  end

  namespace "web-app" do
    desc "List outdated web-app NPM dependencies"
    task :npm do
      require "childprocess"
      process = ChildProcess.build("yarn", "outdated")
      process.cwd = File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/web-app")
      process.io.inherit!
      process.start
      process.wait
    end
  end

  namespace "example-website" do
    desc "List outdated example-website NPM dependencies"
    task :npm do
      require "childprocess"
      process = ChildProcess.build("yarn", "outdated")
      process.cwd = File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/example-website")
      process.io.inherit!
      process.start
      process.wait
    end
  end

  desc "List outdated package dependencies"
  task :packages do
    require_relative "./outdated_packages"
    OutdatedPackages.new
  end
end

desc "List outdated dependencies"
task :outdated do
  puts "==== ADMIN-UI: NPM ===="
  Rake::Task["outdated:admin-ui:npm"].invoke
  puts "\n\n"

  puts "==== WEB-APP: NPM ===="
  Rake::Task["outdated:web-app:npm"].invoke
  puts "\n\n"

  puts "==== EXAMPLE-WEBSITE: NPM ===="
  Rake::Task["outdated:example-website:npm"].invoke
  puts "\n\n"

  puts "==== TEST: GEMS ===="
  Rake::Task["outdated:test:gems"].invoke
  puts "\n\n"

  puts "==== PACKAGES ===="
  Rake::Task["outdated:packages"].invoke
end
