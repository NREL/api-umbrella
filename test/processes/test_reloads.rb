require_relative "../test_helper"

class TestProcessesReloads < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  def test_no_file_descriptor_leaks_across_nginx_reloads
    descriptor_counts = []
    urandom_descriptor_counts = []

    parent_pid = nginx_parent_pid

    # Now perform a number of reloads and gather file descriptor information
    # after each one.
    15.times do
      # Get the list of original nginx worker process PIDs on startup.
      original_child_pids = nginx_child_pids(parent_pid)

      # Send a reload signal to nginx.
      Process.kill("HUP", parent_pid.to_i)

      # After sending the reload signal, wait until only the new set of worker
      # processes is running. This prevents us from checking file descriptors
      # when some of the old worker processes are still alive, but in the
      # process of shutting down.
      output = nil
      begin
        Timeout.timeout(70) do
          loop do
            new_child_pids = nginx_child_pids(parent_pid)
            pid_intersection = new_child_pids & original_child_pids
            break if(pid_intersection.empty?)
            sleep 0.1
          end
        end
      rescue Timeout::Error
        raise Timeout::Error, "nginx child processes did not change during reload. original_child_pids: #{original_child_pids.inspect} Last output: #{output.inspect}"
      end

      # Make a number of concurrent requests to ensure that each nginx worker
      # process is warmed up. This ensures that each worker should at least
      # have initialized its usage of its urandom descriptors. Since we want to
      # test that these descriptors don't grow, we first need to ensure each
      # worker process is first fully initialized (so they don't grow due to be
      # initialized later on in the tests).
      hydra = Typhoeus::Hydra.new(:max_concurrency => 10)
      200.times do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/api/delay/5?#{rand}", http_options)
        request.on_complete do |response|
          assert_equal(200, response.code, response.body)
        end
        hydra.queue(request)
      end
      hydra.run

      # Now check for open file descriptors.
      output, status = Open3.capture2e("lsof -n -P -l -R -c nginx")
      assert_equal(0, status, output)
      descriptor_count = 0
      urandom_descriptor_count = 0
      lines = output.split("\n")
      lines.each_with_index do |line, line_index|
        columns = line.split(/\s+/)
        col_pid = columns[1]
        col_parent_pid = columns[2]
        col_type = columns[5]

        # Only count lines from the lsof output that belong to this nginx's PID
        # and aren't network sockets (we exclude those when checking for leaks,
        # since it's expected that there's much more variation in those
        # depending on the requests made by tests, keepalive connections, etc).
        if((line_index == 0 || col_pid == parent_pid || col_parent_pid == parent_pid) && !["IPv4", "IPv6", "unix", "sock"].include?(col_type))
          descriptor_count += 1

          if(line.include?("urandom"))
            urandom_descriptor_count += 1
          end
        end
      end

      descriptor_counts << descriptor_count
      urandom_descriptor_counts << urandom_descriptor_count
    end

    assert_equal(15, descriptor_counts.length)
    assert_equal(15, urandom_descriptor_counts.length)

    # Test to ensure ngx_txid isn't leaving open file descriptors around on
    # reloads test for this patch: https://github.com/streadway/ngx_txid/pull/6
    # Allow for some small fluctuations in the /dev/urandom sockets, since
    # other nginx modules might also be using them.
    assert_operator(urandom_descriptor_counts.min, :>, 0)
    range = urandom_descriptor_counts.max - urandom_descriptor_counts.min
    assert_operator(range, :<=, $config["nginx"]["workers"] * 2)

    # A more general test to ensure that we don't see other unexpected file
    # descriptor growth. We'll allow some growth for this test, though, just to
    # account for small fluctuations in sockets due to other things nginx may
    # be doing.
    assert_operator(descriptor_counts.min, :>, 0)
    range = descriptor_counts.max - descriptor_counts.min
    assert_operator(range, :<=, $config["nginx"]["workers"] * 2)
  end

  def test_no_dropped_connections_during_reloads
    # Be sure that these tests interact with a backend published via Mongo, so
    # we can also catch errors for when the mongo-based configuration data
    # experiences failures.
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/db-config/hello", :backend_prefix => "/hello" }],
      },
    ]) do
      # Fetch the PID of the nginx parent/master process.
      parent_pid = nginx_parent_pid

      # Gather the worker ids at the start (so we can sanity check that the reloads happened).
      original_child_pids = nginx_child_pids(parent_pid)

      # Randomly send reload signals every 5-500ms during the testing period.
      reload_thread = Thread.new do
        loop do
          sleep rand(0.005..0.5)
          ApiUmbrellaTestHelpers::Process.reload("--router")
        end
      end

      # Constantly make requests for 20 seconds while performing reloads in the
      # background thread.
      test_duration = 20
      start_time = Time.now.utc
      while(Time.now.utc - start_time < test_duration)
        response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/db-config/hello?#{rand}", http_options)
        assert_equal(200, response.code, response.body)
        assert_equal("Hello World", response.body)
      end

      reload_thread.exit

      # Gather the worker ids at the end (so we can sanity check that the reloads happened).
      final_child_pids = nginx_child_pids(parent_pid)

      refute_equal(original_child_pids.sort, final_child_pids.sort)
    end
  end

  def test_file_based_config_changes_updates_templates
    nginx_config_path = File.join($config["root_dir"], "etc/nginx/router.conf")
    nginx_config = File.read(nginx_config_path)
    assert_match("worker_processes #{$config["nginx"]["workers"]};", nginx_config)
    refute_match("worker_processes 1;", nginx_config)

    override_config({
      "nginx" => {
        "workers" => 1,
      },
    }, "--router") do
      nginx_config = File.read(nginx_config_path)
      assert_match("worker_processes 1;", nginx_config)
    end

    nginx_config = File.read(nginx_config_path)
    refute_match("worker_processes 1;", nginx_config)
  end

  def test_file_based_config_changes_updates_apis
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/file-config/info/", http_options)
    assert_equal(404, response.code, response.body)

    override_config({
      "apis" => [
        {
          "frontend_host" => "127.0.0.1",
          "backend_host" => "127.0.0.1",
          "servers" => [{ "host" => "127.0.0.1", "port" => 9444 }],
          "url_matches" => [{ "frontend_prefix" => "/#{unique_test_id}/file-config/info/", "backend_prefix" => "/info/" }],
          "settings" => {
            "headers" => [{ "key" => "X-Test-File-Config", "value" => "foo" }],
          },
        },
      ],
    }, "--router") do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/file-config/info/", http_options)
      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      assert_equal(data["headers"]["x-test-file-config"], "foo")
    end

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/file-config/info/", http_options)
    assert_equal(404, response.code, response.body)
  end

  private

  def nginx_parent_pid
    output, status = Open3.capture2e("perpstat -b #{File.join($config["root_dir"], "etc/perp")} nginx")
    assert_equal(0, status, output)
    parent_pid = output.match(/^\s*main:.*\(pid (\d+)\)\s*$/)[1]
    assert(parent_pid, output)

    parent_pid
  end

  def nginx_child_pids(parent_pid)
    pids = []
    output = nil
    expected_num_workers = $config["nginx"]["workers"]
    begin
      Timeout.timeout(70) do
        loop do
          output, status = Open3.capture2e("pgrep -P #{parent_pid}")
          assert_equal(0, status, output)
          pids = output.strip.split("\n")
          break if(pids.length == expected_num_workers)
          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise Timeout::Error, "Did not find expected number of nginx child processes. Last output: #{output.inspect}"
    end

    pids
  end
end
