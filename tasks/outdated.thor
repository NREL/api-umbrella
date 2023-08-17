# vi: set ft=ruby :

require "json"
require "net/http"
require "open3"
require "rainbow"
require "uri"

class Outdated < Thor
  REPOS = {
    "crane" => {
      :git => "https://github.com/google/go-containerregistry.git",
    },
    "cue" => {
      :git => "https://github.com/cue-lang/cue.git",
    },
    "envoy" => {
      :git => "https://github.com/envoyproxy/envoy.git",
    },
    "glauth" => {
      :git => "https://github.com/glauth/glauth.git",
    },
    "hugo" => {
      :git => "https://github.com/gohugoio/hugo.git",
    },
    "lrexlib_pcre2" => {
      :luarock => "lrexlib-pcre2",
    },
    "lua_icu_date_ffi" => {
      :git => "https://github.com/GUI/lua-icu-date-ffi.git",
      :git_ref => "master",
    },
    "lua_resty_logger_socket" => {
      :git => "https://github.com/cloudflare/lua-resty-logger-socket.git",
      :git_ref => "master",
    },
    "luarocks" => {
      :git => "https://github.com/keplerproject/luarocks.git",
    },
    "mailpit" => {
      :git => "https://github.com/axllent/mailpit.git",
    },
    "ngx_http_geoip2_module" => {
      :git => "https://github.com/leev/ngx_http_geoip2_module.git",
    },
    "nodejs" => {
      :git => "https://github.com/nodejs/node.git",
      :constraint => "~> 18.12",
    },
    "openresty" => {
      :git => "https://github.com/openresty/openresty.git",
    },
    "perp" => {
      :http => "http://b0llix.net/perp/site.cgi?page=download",
    },
    "rsyslog" => {
      :git => "https://github.com/rsyslog/rsyslog.git",
    },
    "shellcheck" => {
      :git => "https://github.com/koalaman/shellcheck.git",
    },
    "task" => {
      :git => "https://github.com/go-task/task.git",
    },
    "trafficserver" => {
      :http => "https://archive.apache.org/dist/trafficserver/",
    },
    "yarn" => {
      :git => "https://github.com/yarnpkg/yarn.git",
    },
  }.freeze

  class AdminUi < Thor
    namespace "outdated:admin-ui"

    desc "npm", "List outdated admin-ui NPM dependencies"
    def npm
      Dir.chdir(File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "src/api-umbrella/admin-ui")) do
        system("yarn", "outdated", exception: false)
      end
    end
  end

  class Test < Thor
    desc "gems", "List outdated test gem dependencies"
    def gems
      env = {
        "BUNDLE_GEMFILE" => File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "Gemfile"),
        "BUNDLE_APP_CONFIG" => File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "tasks/app-deps/web-app/bundle/_persist/.bundle"),
      }

      system(env, "bundle", "outdated", exception: false)
    end

    desc "luarocks", "List outdated test LuaRocks dependencies"
    def luarocks
      Outdated.outdated_luarocks(
        rockspec_path: File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "test/api-umbrella-test-git-1.rockspec"),
        lock_path: File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "test/luarocks.lock"),
      )
    end
  end

  class WebApp < Thor
    namespace "outdated:web-app"

    desc "npm", "List outdated web-app NPM dependencies"
    def npm
      Dir.chdir(File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "src/api-umbrella/web-app")) do
        system("yarn", "outdated", exception: false)
      end
    end
  end

  class ExampleWebsite < Thor
    namespace "outdated:example-website"

    desc "npm", "List outdated example-website NPM dependencies"
    def npm
      Dir.chdir(File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "src/api-umbrella/example-website")) do
        system("yarn", "outdated", exception: false)
      end
    end
  end

  desc "luarocks", "List outdated LuaRocks dependencies"
  def luarocks
    Outdated.outdated_luarocks(
      rockspec_path: File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "src/api-umbrella-git-1.rockspec"),
      lock_path: File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "src/luarocks.lock"),
    )
  end

  desc "packages", "List outdated package dependencies"
  def packages
    seen_names = []
    versions = {}
    versions_content = `git grep -hE "^\\s*\\w+_version=" tasks`.strip
    versions_content.each_line do |line|
      current_version_matches = line.match(/^\s*(.+?)_version=['"]([^'"]+)/)
      if(!current_version_matches)
        next
      end

      name = current_version_matches[1].downcase
      seen_names.push(name)
      options = REPOS[name] || {}
      current_version_string = current_version_matches[2]

      Outdated.add_version(versions: versions, name: name, current_version_string: current_version_string, options: options)
    end

    unused_repos = REPOS.keys - seen_names
    if(unused_repos.any?)
      warn Rainbow("\nWARNING: Unused repos defined in #{__FILE__}: #{unused_repos.sort.join(", ")}\n").yellow
    end

    Outdated.print_versions(versions: versions, luarock: true)
  end

  desc "all", "List outdated dependencies"
  def all
    puts "\n\n"
    puts "==== LUAROCKS ===="
    luarocks
    puts "\n\n"

    puts "==== ADMIN-UI: NPM ===="
    AdminUi.new.npm
    puts "\n\n"

    puts "==== WEB-APP: NPM ===="
    WebApp.new.npm
    puts "\n\n"

    puts "==== EXAMPLE-WEBSITE: NPM ===="
    ExampleWebsite.new.npm
    puts "\n\n"

    puts "==== TEST: LUAROCKS ===="
    Test.new.luarocks
    puts "\n\n"

    puts "==== TEST: GEMS ===="
    Test.new.gems
    puts "\n\n"

    puts "==== PACKAGES ===="
    packages
  end

  class << self
    def luarocks_manifest
      @luarocks_manifest ||= JSON.parse(Net::HTTP.get_response(URI.parse("https://luarocks.org/manifest.json")).body)
    end

    def luarock_version_to_semver(version)
      version.gsub(/-(\d+)$/, '.0.0.\1')
    end

    def semver_to_luarock_version(version)
      version.gsub(/\.0\.0\.(\d+)$/, '-\1')
    end

    def tag_to_semver(name, tag)
      tag.downcase!

      # Remove prefixes containing the project name.
      tag.gsub!(/^#{name}[-_]/i, "")
      tag.gsub!(/^#{name.tr("_", "-")}[-_]/i, "")

      # Remove trailing "^{}" at end of git tags.
      tag.chomp!("^{}")

      # Remove "release-" prefixes.
      tag.gsub!(/^release-/, "")

      # Remove "v" or "r" prefixes before the version number.
      tag.gsub!(/^[vr](\d)/, '\1')

      # Project-specific normalizations.
      case(name)
      when "postgresql"
        tag.gsub!(/^rel_?/, "")
        tag.tr!("_", ".")
      end

      tag
    end

    def add_version(versions:, name:, current_version_string:, options:)
      begin
        if(options[:luarock])
          current_version = Gem::Version.new(luarock_version_to_semver(current_version_string))
        else
          current_version = Gem::Version.new(current_version_string)
        end
      rescue ArgumentError
        current_version = current_version_string.dup
      end
      versions[name] = {
        :current_version => current_version,
      }

      tags = []
      unparsable_tags = []

      if(options[:git] && options[:git_ref])
        current_commit = current_version_string
        if(current_commit !~ /^[0-9a-f]{5,40}$/)
          current_commit = `git ls-remote #{options[:git]} #{current_version_string}`.split(/\s/).first
          if(current_commit.to_s.empty?)
            puts "#{name}: Could not parse version #{current_version_string}"
          end
        end

        latest_commit = `git ls-remote #{options[:git]} #{options[:git_ref]}`.split(/\s/).first
        if(latest_commit.to_s.empty?)
          puts "#{name}: Could not parse latest commit: git ls-remote #{options[:git]} #{options[:git_ref]}"
        end

        versions[name][:current_version] = current_commit[0, 7]
        versions[name][:latest_version] = latest_commit[0, 7]
        versions[name][:wanted_version] = latest_commit[0, 7]
      elsif(options[:git])
        tags = `git ls-remote --tags #{options[:git]}`.lines
        tags.map! { |tag| tag_to_semver(name, tag.match(%r{refs/tags/(.+)$})[1]) }
      elsif(options[:luarock])
        tags = luarocks_manifest.fetch("repository").fetch(options[:luarock]).keys
        tags.map! { |tag| luarock_version_to_semver(tag) }
      elsif(options[:http])
        content = Net::HTTP.get_response(URI.parse(options[:http])).body
        tags = content.scan(/#{name}-[\d.]+.tar/)
        tags.map! { |f| tag_to_semver(name, File.basename(f, ".tar")) }
      end

      tags.compact!
      tags.uniq!
      tags.each do |tag|
        if(options[:string_version])
          available_version = tag
          if(!versions[name][:latest_version] || available_version > versions[name][:latest_version])
            versions[name][:latest_version] = available_version
            versions[name][:wanted_version] = available_version
          end
        else
          constraint = Gem::Dependency.new(name, options[:constraint])

          begin
            available_version = Gem::Version.new(tag)
            next if(available_version.prerelease?)

            if(!versions[name][:latest_version] || available_version > versions[name][:latest_version])
              versions[name][:latest_version] = available_version
            end

            if(constraint.match?(name, available_version))
              if(!versions[name][:wanted_version] || available_version > versions[name][:wanted_version])
                versions[name][:wanted_version] = available_version
              end
            end
          rescue ArgumentError
            unparsable_tags << tag
          end
        end
      end

      if(unparsable_tags.any?)
        warn "#{name}: Could not parse version tag #{unparsable_tags.join(", ")}"
      end
    end

    def print_versions(versions:, luarock: false)
      print Rainbow("Package".ljust(32)).underline
      print Rainbow("Current".rjust(16)).underline
      print Rainbow("Wanted".rjust(16)).underline
      print Rainbow("Latest".rjust(16)).underline
      puts ""

      versions.keys.sort.each do |name|
        info = versions[name]
        name_column = name.ljust(32)
        if(info[:wanted_version].to_s != info[:current_version].to_s)
          print Rainbow(name_column).red
        elsif(info[:current_version].to_s != info[:latest_version].to_s)
          print Rainbow(name_column).yellow
        else
          print name_column
        end

        if luarock
          info[:current_version] = semver_to_luarock_version(info[:current_version].to_s)
          info[:wanted_version] = semver_to_luarock_version(info[:wanted_version].to_s)
          info[:latest_version] = semver_to_luarock_version(info[:latest_version].to_s)
        end

        print info[:current_version].to_s.rjust(16)
        print Rainbow(info[:wanted_version].to_s.rjust(16)).green
        print Rainbow(info[:latest_version].to_s.rjust(16)).magenta
        puts ""
      end
    end

    def outdated_luarocks(rockspec_path:, lock_path:)
      rockspec_output, rockspec_status = Open3.capture2("api-umbrella-exec", "resty", "--errlog-level", "error", "-e", "local cjson = require 'cjson'; dofile('#{rockspec_path}'); print(cjson.encode(dependencies))")
      unless rockspec_status.success?
        exit 1
      end
      rockspec = JSON.parse(rockspec_output)
      rockspec_constraints = rockspec.map { |r| r.split(/\s+/, 2) }.to_h

      lock_output, lock_status = Open3.capture2("api-umbrella-exec", "resty", "-e", "local cjson = require 'cjson'; print(cjson.encode(dofile('#{lock_path}')))")
      unless lock_status.success?
        exit 1
      end
      lock = JSON.parse(lock_output)

      versions = {}
      lock.fetch("dependencies").each do |name, version|
        next if name == "lua"

        options = {
          :luarock => name,
        }

        if rockspec_constraints[name]
          options[:constraint] = rockspec_constraints.fetch(name)
        end

        add_version(versions: versions, name: name, current_version_string: version, options: options)
      end

      print_versions(versions: versions, luarock: true)
    end
  end
end

# Outdated.start(ARGV)
