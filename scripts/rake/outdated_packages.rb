require "json"
require "open-uri"
require "rainbow"

class OutdatedPackages
  REPOS = {
    "api_umbrella_static_site" => {
      :git => "https://github.com/NREL/api-umbrella-static-site.git",
      :git_ref => "master",
    },
    "bundler" => {
      :git => "https://github.com/bundler/bundler.git",
    },
    "elasticsearch" => {
      :git => "https://github.com/elasticsearch/elasticsearch.git",
      :constraint => "~> 2.4.3",
    },
    "golang" => {
      :git => "https://go.googlesource.com/go",
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
    "libgeoip" => {
      :git => "https://github.com/maxmind/geoip-api-c.git",
    },
    "luarocks" => {
      :git => "https://github.com/keplerproject/luarocks.git",
    },
    "luarock_argparse" => {
      :luarock => "argparse",
    },
    "luarock_cmsgpack" => {
      :luarock => "lua-cmsgpack",
    },
    "luarock_iconv" => {
      :luarock => "lua-iconv",
    },
    "luarock_inspect" => {
      :luarock => "inspect",
    },
    "luarock_luacheck" => {
      :luarock => "luacheck",
    },
    "luarock_luaposix" => {
      :luarock => "luaposix",
    },
    "luarock_lustache" => {
      :luarock => "lustache",
    },
    "luarock_lyaml" => {
      :luarock => "lyaml",
    },
    "luarock_penlight" => {
      :luarock => "penlight",
    },
    "luarock_resty_uuid" => {
      :luarock => "lua-resty-uuid",
    },
    "lua_luasocket" => {
      :git => "https://github.com/diegonehab/luasocket.git",
      :git_ref => "master",
    },
    "lua_resty_logger_socket" => {
      :git => "https://github.com/cloudflare/lua-resty-logger-socket.git",
      :git_ref => "master",
    },
    "lua_resty_shcache" => {
      :git => "https://github.com/cloudflare/lua-resty-shcache.git",
      :git_ref => "master",
    },
    "mailhog" => {
      :git => "https://github.com/mailhog/MailHog.git",
    },
    "mongo_orchestration" => {
      :git => "https://github.com/10gen/mongo-orchestration.git",
    },
    "mongodb" => {
      :git => "https://github.com/mongodb/mongo.git",
      :constraint => "~> 3.2.9",
    },
    "mora" => {
      :git => "https://github.com/emicklei/mora.git",
      :git_ref => "master",
    },
    "nodejs" => {
      :git => "https://github.com/nodejs/node.git",
      :constraint => "~> 8.10",
    },
    "openldap" => {
      :git => "https://github.com/openldap/openldap.git",
    },
    "openresty" => {
      :git => "https://github.com/openresty/openresty.git",
    },
    "openssl" => {
      :git => "https://github.com/openssl/openssl.git",
      :string_version => true,
    },
    "opm_icu_date" => {
      :git => "https://github.com/GUI/lua-icu-date.git",
      :git_ref => "master",
    },
    "opm_libcidr" => {
      :git => "https://github.com/GUI/lua-libcidr-ffi.git",
    },
    "opm_resty_http" => {
      :git => "https://github.com/pintsized/lua-resty-http.git",
    },
    "opm_resty_txid" => {
      :git => "https://github.com/GUI/lua-resty-txid.git",
    },
    "pcre" => {
      :http => "https://ftp.pcre.org/pub/pcre/",
    },
    "perp" => {
      :http => "http://b0llix.net/perp/site.cgi?page=download",
    },
    "phantomjs" => {
      :git => "https://github.com/ariya/phantomjs.git",
    },
    "ruby" => {
      :git => "https://github.com/ruby/ruby.git",
      :constraint => "~> 2.4.3",
    },
    "rubygems" => {
      :git => "https://github.com/rubygems/rubygems.git",
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
    "trafficserver" => {
      :git => "https://github.com/apache/trafficserver.git",
    },
    "unbound" => {
      :http => "https://www.unbound.net/download.html",
    },
    "yarn" => {
      :git => "https://github.com/yarnpkg/yarn.git",
    },
  }

  def luarocks_manifest
    @luarocks_manifest ||= JSON.load(open("https://luarocks.org/manifest.json"))
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
    tag.gsub!(/^#{name.gsub("_", "-")}[\-_]/i, "")

    # Remove trailing "^{}" at end of git tags.
    tag.chomp!("^{}")

    # Remove "release-" prefixes.
    tag.gsub!(/^release-/, "")

    # Remove "v" or "r" prefixes before the version number.
    tag.gsub!(/^[vr](\d)/, '\1')

    # Project-specific normalizations.
    case(name)
    when "golang"
      tag.gsub!(/^go/, "")
    when "json_c"
      tag.gsub!(/-\d{8}$/, "")
    when "openldap"
      tag.gsub!(/^rel_eng_/, "")
      tag.gsub!(/_/, ".")
    when "openssl", "ruby"
      tag.gsub!(/_/, ".")
    end

    tag
  end

  def initialize
    seen_names = []
    versions = {}
    versions_content = `git grep -h "^set.*_VERSION" build/cmake`.strip
    versions_content.each_line do |line|
      current_version_matches = line.match(/set\((.+?)_VERSION (.+?)\)/)
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

      constraint = Gem::Dependency.new(name, options[:constraint])

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

        versions[name][:current_version] = current_commit[0,7]
        versions[name][:latest_version] = latest_commit[0,7]
        versions[name][:wanted_version] = latest_commit[0,7]
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
        content = open(options[:http]).read
        tags = content.scan(/#{name}-[\d\.]+.tar/)
        tags.map! { |f| tag_to_semver(name, File.basename(f, ".tar")) }
      end

      case(name)
      when "openssl"
        tags.select! { |tag| tag =~ /^1\.0\.\d+[a-z]?$/ }
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
          rescue ArgumentError => e
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

    versions.each do |name, info|
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

