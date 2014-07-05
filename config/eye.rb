require "net/http"

ENV["PATH"] = [
  "/vagrant/workspace/router/bin",
  "/vagrant/workspace/router/gatekeeper/bin",
  "/opt/api-umbrella/embedded/sbin",
  "/opt/api-umbrella/embedded/bin",
  "/usr/local/sbin",
  "/usr/local/bin",
  "/usr/sbin",
  "/usr/bin",
  "/sbin",
  "/bin",
].join(":")

def check_tcp(host, port, timeout = 10, step = 0.1)
  Proc.new do
    process.state = :starting
    process.wait_for_condition(timeout, step) do
      begin
        puts TCPSocket.new(host, port).inspect
        process.state = :up
        true
      rescue
        puts "Port #{port}: #{$!.inspect}"
        false
      end
    end
  end
end

def check_unix(path, timeout = 10, step = 0.1)
  Proc.new do
    process.state = :starting
    process.wait_for_condition(timeout, step) do
      begin
        puts UNIXSocket.new(path).inspect
        process.state = :up
        true
      rescue
        puts "Socket #{path}: #{$!.inspect}"
        false
      end
    end
  end
end


def check_http(host, port, path, timeout = 10, step = 0.1)
  Proc.new do
    process.state = :starting
    process.wait_for_condition(timeout, step) do
      begin
        puts Net::HTTP.get_response(host, path, port).code.inspect
        process.state = :up
        true
      rescue
        puts "Port #{port}: #{$!.inspect}"
        false
      end
    end
  end
end


Eye.application("api-umbrella") do
  process "mongod" do
    stdall "mongod.log"
    pid_file "mongod.pid"
    start_command "mongod --config /vagrant/workspace/router/config/mongod.conf"
    daemonize true
    trigger :transition, :to => :up, :do => check_tcp("localhost", 50217)
  end

  process "elasticsearch" do
    stdall "elasticsearch.log"
    pid_file "elasticsearch.pid"
    start_command "elasticsearch"
    env({
      "ES_INCLUDE" => "/vagrant/workspace/router/config/elasticsearch/elasticsearch-env.sh",
    })
    daemonize true
    trigger :transition, :to => :up, :do => check_http("localhost", 50200, "/", 60)
  end

  process "redis" do
    stdall "redis.log"
    pid_file "redis.pid"
    start_command "redis-server /vagrant/workspace/router/config/redis.conf"
    daemonize true
    trigger :transition, :to => :up, :do => check_tcp("localhost", 50831)
  end

  process "varnishd" do
    stdall "varnishd.log"
    pid_file "varnishd.pid"
    start_command "varnishd -F -a :51700 -f /vagrant/workspace/router/config/varnish.vcl -t 0 -n /tmp/api-umbrella"
    daemonize true
    trigger :transition, :to => :up, :do => check_tcp("localhost", 51700)
  end

  process "varnishlog" do
    pid_file "varnishlog.pid"
    start_command "varnishlog -a -w /vagrant/workspace/router/log/varnishncsa.log -n /tmp/api-umbrella"
    daemonize true
  end

  process "varnishncsa" do
    stdall "varnishncsa.log"
    pid_file "varnishncsa.pid"
    start_command "varnishncsa -a -f -w /vagrant/workspace/router/log/varnishncsa.log -n /tmp/api-umbrella"
    daemonize true
  end

  process "nginx_router" do
    stdall "nginx_router.log"
    pid_file "nginx_router.pid"
    start_command "nginx -c /vagrant/workspace/router/config/nginx/router.conf"
    daemonize true
    trigger :transition, :to => :up, :do => check_tcp("localhost", 9080)
  end

  group "gatekeeper" do
    4.times do |i|
      port = 50000 + i
      process("gatekeeper-#{port}") do
        stdall "gatekeeper-#{port}.log"
        working_dir "/vagrant/workspace/router"
        pid_file "gatekeeper-#{port}.pid"
        start_command "api_umbrella_gatekeeper --config /tmp/api-umbrella-runtime11465-32594-lekfcd.yml -p #{port}"
        daemonize true
        trigger :transition, :to => :up, :do => check_tcp("localhost", port)
      end
    end
  end

  process "config_reloader" do
    stdall "config_reloader.log"
    working_dir "/vagrant/workspace/router"
    pid_file "config_reloader.pid"
    start_command "api-umbrella-config-reloader --config /tmp/api-umbrella-runtime11465-32594-lekfcd.yml"
    daemonize true
  end

  process "logging" do
    stdall "logging.log"
    working_dir "/vagrant/workspace/router/gatekeeper"
    pid_file "logging.pid"
    start_command "api_umbrella_logging --config /tmp/api-umbrella-runtime11465-32594-lekfcd.yml"
    daemonize true
  end

  process "distributed_rate_limits_sync" do
    stdall "distributed_rate_limits_sync.log"
    working_dir "/vagrant/workspace/router"
    pid_file "distributed_rate_limits_sync.pid"
    start_command "api_umbrella_distributed_rate_limits_sync --config /tmp/api-umbrella-runtime11465-32594-lekfcd.yml"
    daemonize true
  end

  process "web_puma" do
    stdall "web_puma.log"
    working_dir "/vagrant/workspace/web"
    pid_file "web_puma.pid"
    start_command "bundle exec puma -q -e development -w 2 -t 2:24 -b unix:///tmp/puma.sock"
    daemonize true
    trigger :transition, :to => :up, :do => check_unix("/tmp/puma.sock", 60)
    env({
      "MONGODB_URL" => "mongodb://127.0.0.1:50217/api_umbrella_test",
      "ELASTICSEARCH_URL" => "http://127.0.0.1:50200",
    })
  end

  process "web_nginx" do
    stdall "web_nginx.log"
    pid_file "web_nginx.pid"
    start_command "nginx -c /vagrant/workspace/router/config/nginx/web.conf"
    daemonize true
    trigger :transition, :to => :up, :do => check_tcp("localhost", 51000)
  end
end
