require "active_support/core_ext/hash/deep_merge"
require "fileutils"
require "securerandom"
require "yaml"

require_relative "./config_template"

module ApiUmbrella
  class CLI
    DEFAULT_CONFIG_PATH = File.expand_path("../../../config/default.yml", __FILE__)

    attr_reader :global_options
    attr_reader :options
    attr_reader :args

    def initialize(global_options, options, args)
      @global_options = global_options
      @options = options
      @args = args
    end

    def run
      permission_check
      write_runtime_config
      prepare
      write_templates
      set_permissions
      start_perp
    end

    def start
      @background = true
      run
    end

    private

    def config
      unless @config
        @config = YAML.load_file(DEFAULT_CONFIG_PATH)
        @config.deep_merge!(YAML.load_file(global_options[:config]))

        apply_config_variables!(@config)

        @config.deep_merge!({
          "mongodb" => {
            "host" => @config["mongodb"]["url"].match(%r{//([^,:/]+)})[1],
            "port" => @config["mongodb"]["url"].match(/:(\d+)/)[1].to_i,
            "database" => @config["mongodb"]["url"].split("/").last,
          },
          "service_general_db_enabled?" => config["services"].include?("general_db"),
          "service_log_db_enabled?" => config["services"].include?("log_db"),
          "service_router_enabled?" => config["services"].include?("router"),
          "service_web_enabled?" => config["services"].include?("web"),
          "router" => {
            "trusted_proxies" => ["127.0.0.1", config["router"]["trusted_proxies"]].flatten.compact.uniq,
          },
          "internal_apis" => [
            {
              "_id" => "api-umbrella-gatekeeper-backend",
              "name" => "API Umbrella - Gatekeeper APIs",
              "frontend_host" => "*",
              "backend_host" => "127.0.0.1",
              "backend_protocol" => "http",
              "balance_algorithm" => "least_conn",
              "sort_order" => 1,
              "servers" => [
                {
                  "_id" => SecureRandom.uuid,
                  "host" => "127.0.0.1",
                  "port" => 14008,
                }
              ],
              "url_matches" => [
                {
                  "_id" => SecureRandom.uuid,
                  "frontend_prefix" => "/api-umbrella/v1/health",
                  "backend_prefix" => "/api-umbrella/v1/health",
                },
                {
                  "_id" => SecureRandom.uuid,
                  "frontend_prefix" => "/api-umbrella/v1/state",
                  "backend_prefix" => "/api-umbrella/v1/state",
                }
              ],
              "settings" => {
                "disable_api_key" => true,
                "rate_limit_mode" => "unlimited",
                "require_https" => "optional",
              },
            },
            {
              "_id" => "api-umbrella-web-backend",
              "name" => "API Umbrella - Web APIs",
              "frontend_host" => "*",
              "backend_host" => "127.0.0.1",
              "backend_protocol" => "http",
              "balance_algorithm" => "least_conn",
              "sort_order" => 1,
              "servers" => [
                {
                  "_id" => SecureRandom.uuid,
                  "host" => "127.0.0.1",
                  "port" => @config["web"]["port"],
                }
              ],
              "url_matches" => [
                {
                  "_id" => SecureRandom.uuid,
                  "frontend_prefix" => "/api-umbrella/",
                  "backend_prefix" => "/api-umbrella/",
                }
              ],
              "sub_settings" => [
                {
                  "_id" => SecureRandom.uuid,
                  "http_method" => "post",
                  "regex" => "^/api-umbrella/v1/users",
                  "settings" => {
                    "_id" => SecureRandom.uuid,
                    "required_roles" => ["api-umbrella-key-creator"],
                  },
                },
                {
                  "_id" => SecureRandom.uuid,
                  "http_method" => "post",
                  "regex" => "^/api-umbrella/v1/contact",
                  "settings" => {
                    "_id" => SecureRandom.uuid,
                    "required_roles" => ["api-umbrella-contact-form"],
                  },
                },
              ],
            },
          ],
        })

        if(@config["static_site"]["dir"] && !@config["static_site"]["build_dir"])
          @config.deep_merge!({
            "static_site" => {
              "build_dir" => File.join(@config["static_site"]["dir"], "build"),
            },
          })
        end

        if(@config["app_env"] == "test")
          @config.deep_merge!({
            "gatekeeper" => {
              "dir" => File.expand_path("../../../", __FILE__),
            },
          })
        end
      end

      @config
    end

    def apply_config_variables!(config)
      if(config.kind_of?(Hash))
        config.each do |key, value|
          next if(key == "apiSettings")

          if(value.kind_of?(String))
            value.gsub!("{{root_dir}}", @config["root_dir"])
          elsif(value.kind_of?(Hash))
            apply_config_variables!(value)
          end
        end
      end
    end

    def template_config
      unless @template_config
        @template_config = config.merge({
          "api_umbrella_config_runtime_file" => runtime_config_path,
          "api_umbrella_config_args" => '--config ' + runtime_config_path,
          #"gatekeeper_hosts" => gatekeeperHosts,
          #"gatekeeper_supervisor_process_names" => _.pluck(gatekeeperHosts, 'process_name'),
          "test_env?" => (config["app_env"] == 'test'),
          "development_env?" => (config["app_env"] == 'development'),
          #"primary_hosts" => _.filter(config.get('hosts'), function(host) { return !host.secondary; }),
          #"secondary_hosts" => _.filter(config.get('hosts'), function(host) { return host.secondary; }),
          #"has_default_host" => (_.where(config.get('hosts'), { default: true }).length > 0),
          #"supervisor_conditional_user" => (config.get('user')) ? 'user=' + config.get('user') : '',
          "mongodb_yaml" => YAML.dump({
            "storage" => {
              "dbPath" => File.join(config["db_dir"], "mongodb"),
            },
          }.deep_merge(config["mongodb"]["embedded_server_config"])),
          "elasticsearch_yaml" => YAML.dump({
            "path" => {
              "conf" => File.join(config["etc_dir"], "elasticsearch"),
              "data" => File.join(config["db_dir"], "elasticsearch"),
              "logs" => File.join(config["log_dir"]),
            },
          }.deep_merge(config["elasticsearch"]["embedded_server_config"]))
        })
      end

      @template_config
    end

    def runtime_config_path
      @runtime_config_path ||= File.join(config["run_dir"], "runtime_config.yml")
    end

    def permission_check
      if(config["user"])
        if(Process.euid != 0)
          raise "Must be started with super-user privileges to change user to '#{config["user"]}'"
        end

        begin
          Etc.getpwnam(config["user"])
        rescue
          raise "User '#{config["user"]}' does not exist"
        end
      end

      if(config["group"])
        if(Process.euid != 0)
          raise "Must be started with super-user privileges to change group to '#{config["group"]}'"
        end

        begin
          Etc.getgrnam(config["group"])
        rescue
          raise "Group '#{config["group"]}' does not exist"
        end
      end

      if(config["http_port"] < 1024 || config["https_port"] < 1024)
        if(Process.euid != 0)
          raise "Must be started with super-user privileges to use http ports below 1024"
        end
      end

      if(Process.euid == 0)
        if(!config["user"] || !config["group"])
          raise "Must define a user and group to run worker processes as when starting with with super-user privileges"
        end
      end
    end

    def write_runtime_config
      FileUtils.mkdir_p(File.dirname(runtime_config_path))
      File.open(runtime_config_path, "w") { |f| f.write(YAML.dump(config)) }
    end

    def prepare
      dirs = [
        config["db_dir"],
        config["log_dir"],
        config["run_dir"],
        config["tmp_dir"],
        File.join(config["db_dir"], "beanstalkd"),
        File.join(config["db_dir"], "elasticsearch"),
        File.join(config["db_dir"], "mongodb"),
        File.join(config["db_dir"], "redis"),
        File.join(config["etc_dir"], "trafficserver/snapshots"),
        File.join(config["log_dir"], "trafficserver"),
        File.join(config["root_dir"], "var/trafficserver"),
        File.join(config["run_dir"], "varnish/api-umbrella"),
      ]

      dirs.each do |dir|
        FileUtils.mkdir_p(dir)
      end
    end

    def write_templates
      template_root = File.expand_path("../../../templates/etc", __FILE__)
      templates = Dir.glob(File.join(template_root, "**/*"))
      templates += Dir.glob(File.join(template_root, "perp/.boot/**/*"))
      templates.each do |template_path|
        next if(File.directory?(template_path))
        next if(@config["app_env"] != "test" && template_path.include?("test-env"))

        install_path = template_path.gsub(template_root, "")
        install_path.chomp!(".mustache")
        install_path.chomp!(".hbs")
        install_path = File.join(config["etc_dir"], install_path)

        content = File.read(template_path)
        if(File.extname(template_path) == ".mustache")
          content = ConfigTemplate.render(content, template_config)
        end

        FileUtils.mkdir_p(File.dirname(install_path))
        File.open(install_path, "w") do |file|
          file.write(content)
          file.chmod(File.stat(template_path).mode)
        end
      end

      perp_service_dirs = Dir.glob(File.join(config["etc_dir"], "perp/*"))
      perp_service_dirs.each do |service_dir|
        FileUtils.chmod("+t", service_dir)
      end
    end

    def set_permissions
      FileUtils.chmod(0777, config["tmp_dir"])

      if(config["user"])
        FileUtils.chown(config["user"], config["group"], File.join(config["root_dir"], "var/trafficserver"))
        FileUtils.chown(config["user"], config["group"], File.join(config["log_dir"], "trafficserver"))
        FileUtils.chown_R(config["user"], config["group"], File.join(config["etc_dir"], "trafficserver"))
      end
    end

    def start_perp
      ENV["PATH"] = [
        "/tmp/api-umbrella-build/embedded/sbin",
        "/tmp/api-umbrella-build/embedded/bin",
        # "/opt/api-umbrella-openresty/embedded/openresty/nginx/sbin",
        # "/opt/api-umbrella-openresty/embedded/elasticsearch/bin",
        # "/opt/api-umbrella-openresty/embedded/jre/bin",
        # "/opt/api-umbrella-openresty/embedded/sbin",
        # "/opt/api-umbrella-openresty/embedded/bin",
        # "/opt/api-umbrella/embedded/elasticsearch/bin",
        # "/opt/api-umbrella/embedded/sbin",
        # "/opt/api-umbrella/embedded/bin",
        # "/opt/api-umbrella/embedded/jre/bin",
        # "/vagrant/mora",
        # "/opt/trafficserver/bin",
      ].join(":") + ":#{ENV["PATH"]}"

      perp_base = File.join(config["etc_dir"], "perp")
      detach = if(@background) then "-d" else nil end

      commands = [
        "runtool",
          "-0", "api-umbrella (perpboot)",
          "-P", "/tmp/perpboot.lock",
        "perpboot",
          detach,
          perp_base,
      ].compact
      exec(*commands)
    end
  end
end
