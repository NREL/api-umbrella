require "json"
require "net/http"
require "rainbow"
require "uri"

class OutdatedPackages
  REPOS = {
    "crane" => {
      :git => "https://github.com/google/go-containerregistry.git",
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
    "icu4c" => {
      :git => "https://github.com/unicode-org/icu.git",
    },
    "libbson" => {
      :git => "https://github.com/mongodb/mongo-c-driver.git",
    },
    "libcidr" => {
      :http => "https://www.over-yonder.net/~fullermd/projects/libcidr",
    },
    "libestr" => {
      :git => "https://github.com/rsyslog/libestr.git",
    },
    "libfastjson" => {
      :git => "https://github.com/rsyslog/libfastjson.git",
    },
    "libmaxminddb" => {
      :git => "https://github.com/maxmind/libmaxminddb.git",
    },
    "libpsl" => {
      :git => "https://github.com/rockdaboot/libpsl.git",
    },
    "lua_argparse" => {
      :luarock => "argparse",
    },
    "lua_bcrypt" => {
      :luarock => "bcrypt",
    },
    "lua_cbson" => {
      :git => "https://github.com/isage/lua-cbson.git",
      :git_ref => "master",
    },
    "lua_cmsgpack" => {
      :luarock => "lua-cmsgpack",
    },
    "lua_icu_date_ffi" => {
      :git => "https://github.com/GUI/lua-icu-date-ffi.git",
      :git_ref => "master",
    },
    "lua_inspect" => {
      :luarock => "inspect",
    },
    "lua_lapis" => {
      :luarock => "lapis",
    },
    "lua_libcidr_ffi" => {
      :git => "https://github.com/GUI/lua-libcidr-ffi.git",
    },
    "lua_lrexlib_pcre2" => {
      :luarock => "lrexlib-pcre2",
    },
    "lua_luacheck" => {
      :luarock => "luacheck",
    },
    "lua_lualdap" => {
      :luarock => "lualdap",
    },
    "lua_luaposix" => {
      :luarock => "luaposix",
    },
    "lua_luasocket" => {
      :git => "https://github.com/diegonehab/luasocket.git",
      :git_ref => "master",
    },
    "lua_luautf8" => {
      :luarock => "luautf8",
    },
    "lua_lustache" => {
      :luarock => "lustache",
    },
    "lua_lyaml" => {
      :luarock => "lyaml",
    },
    "lua_penlight" => {
      :luarock => "penlight",
    },
    "lua_psl" => {
      :luarock => "psl",
    },
    "lua_resty_auto_ssl" => {
      :luarock => "lua-resty-auto-ssl",
    },
    "lua_resty_http" => {
      :git => "https://github.com/ledgetech/lua-resty-http.git",
    },
    "lua_resty_logger_socket" => {
      :git => "https://github.com/cloudflare/lua-resty-logger-socket.git",
      :git_ref => "master",
    },
    "lua_resty_mail" => {
      :git => "https://github.com/GUI/lua-resty-mail.git",
    },
    "lua_resty_mlcache" => {
      :git => "https://github.com/thibaultcha/lua-resty-mlcache.git",
    },
    "lua_resty_moongoo" => {
      :git => "https://github.com/isage/lua-resty-moongoo.git",
      :git_ref => "master",
    },
    "lua_resty_nettle" => {
      :git => "https://github.com/bungle/lua-resty-nettle.git",
    },
    "lua_resty_openidc" => {
      :git => "https://github.com/zmartzone/lua-resty-openidc.git",
    },
    "lua_resty_session" => {
      :git => "https://github.com/bungle/lua-resty-session.git",
    },
    "lua_resty_txid" => {
      :git => "https://github.com/GUI/lua-resty-txid.git",
    },
    "lua_resty_uuid" => {
      :luarock => "lua-resty-uuid",
    },
    "lua_resty_validation" => {
      :git => "https://github.com/bungle/lua-resty-validation.git",
    },
    "lua_shell_games" => {
      :git => "https://github.com/GUI/lua-shell-games.git",
    },
    "luarocks" => {
      :git => "https://github.com/keplerproject/luarocks.git",
    },
    "mailhog" => {
      :git => "https://github.com/mailhog/MailHog.git",
    },
    "ngx_http_geoip2_module" => {
      :git => "https://github.com/leev/ngx_http_geoip2_module.git",
    },
    "nodejs" => {
      :git => "https://github.com/nodejs/node.git",
      :constraint => "~> 16.14",
    },
    "openresty" => {
      :git => "https://github.com/openresty/openresty.git",
    },
    "openssl" => {
      :git => "https://github.com/openssl/openssl.git",
      :string_version => true,
    },
    "perp" => {
      :http => "http://b0llix.net/perp/site.cgi?page=download",
    },
    "postgresql" => {
      :git => "https://github.com/postgres/postgres.git",
      :constraint => "~> 10.6",
    },
    "rsyslog" => {
      :git => "https://github.com/rsyslog/rsyslog.git",
    },
    "runit" => {
      :http => "http://smarden.org/runit/install.html",
    },
    "shellcheck" => {
      :git => "https://github.com/koalaman/shellcheck.git",
    },
    "task" => {
      :git => "https://github.com/go-task/task.git",
    },
    "trafficserver" => {
      :git => "https://github.com/apache/trafficserver.git",
    },
    "yarn" => {
      :git => "https://github.com/yarnpkg/yarn.git",
    },
  }.freeze

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
    tag.gsub!(/^#{name}[\-_]/i, "")
    tag.gsub!(/^#{name.tr("_", "-")}[\-_]/i, "")

    # Remove trailing "^{}" at end of git tags.
    tag.chomp!("^{}")

    # Remove "release-" prefixes.
    tag.gsub!(/^release-/, "")

    # Remove "v" or "r" prefixes before the version number.
    tag.gsub!(/^[vr](\d)/, '\1')

    # Project-specific normalizations.
    case(name)
    when "openssl"
      tag.tr!("_", ".")
    when "icu4c"
      tag.tr!("-", ".")
    when "postgresql"
      tag.gsub!(/^rel_?/, "")
      tag.tr!("_", ".")
    end

    tag
  end

  def initialize
    seen_names = []
    versions = {}
    versions_content = `git grep -hE "^\\w+_version=" tasks`.strip
    versions_content.each_line do |line|
      current_version_matches = line.match(/^(.+?)_version=['"]([^'"]+)/)
      if(!current_version_matches)
        next
      end

      name = current_version_matches[1].downcase
      seen_names.push(name)
      options = REPOS[name] || {}
      current_version_string = current_version_matches[2]

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
      elsif(options[:svn])
        tags = `svn ls #{options[:svn]}`.lines
        tags.map! { |tag| tag_to_semver(name, tag) }
      elsif(options[:luarock])
        tags = luarocks_manifest["repository"][options[:luarock]].keys
        tags.map! { |tag| luarock_version_to_semver(tag) }
      elsif(options[:http])
        content = Net::HTTP.get_response(URI.parse(options[:http])).body
        tags = content.scan(/#{name}-[\d.]+.tar/)
        tags.map! { |f| tag_to_semver(name, File.basename(f, ".tar")) }
      end

      case(name)
      when "openssl"
        tags.select! { |tag| tag =~ /^1\.1\.0[a-z]?$/ }
      when "mailhog"
        tags.reject! { |tag| tag =~ /^0\.0\d$/ }
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
        puts "#{name}: Could not parse version tag #{unparsable_tags.join(", ")}"
      end
    end

    unused_repos = REPOS.keys - seen_names
    if(unused_repos.any?)
      puts "\n\nNOTICE: Unused repos defined in scripts/rake/outdated_packages.rb: #{unused_repos.sort.join(", ")}"
    end

    puts "\n\n"

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

      if(REPOS[name] && REPOS[name][:luarock])
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
end
