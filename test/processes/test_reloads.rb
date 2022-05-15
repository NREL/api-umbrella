require_relative "../test_helper"

class Test::Processes::TestReloads < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Lsof

  def setup
    super
    setup_server
  end

  def test_no_file_descriptor_leaks_across_nginx_reloads
    all_reload_descriptors = []
    all_reload_urandom_descriptors = []

    parent_pid = nginx_parent_pid

    # Now perform a number of reloads and gather file descriptor information
    # after each one.
    num_reloads = 15
    num_reloads.times do
      # Get the list of original nginx worker process PIDs on startup.
      original_child_pids = api_umbrella_process.nginx_child_pids(parent_pid, $config["nginx"]["workers"])

      # Send a reload signal to nginx.
      ::Process.kill("HUP", parent_pid.to_i)

      # After sending the reload signal, wait until only the new set of worker
      # processes is running. This prevents us from checking file descriptors
      # when some of the old worker processes are still alive, but in the
      # process of shutting down.
      api_umbrella_process.nginx_wait_for_new_child_pids(parent_pid, $config["nginx"]["workers"], original_child_pids)

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
          assert_response_code(200, response)
        end
        hydra.queue(request)
      end
      hydra.run

      # Now check for open file descriptors.
      files = lsof("-c", "nginx")

      reload_descriptors = []
      reload_urandom_descriptors = []
      files.each do |file|
        # Only count lines from the lsof output that belong to this nginx's PID
        # and aren't network sockets (we exclude those when checking for leaks,
        # since it's expected that there's much more variation in those
        # depending on the requests made by tests, keepalive connections, etc).
        if([file.fetch(:pid), file.fetch(:ppid)].include?(parent_pid) && !["IPv4", "IPv6", "unix", "sock"].include?(file[:type]))
          reload_descriptors << file

          if(file.fetch(:file).include?("urandom"))
            reload_urandom_descriptors << file
          end
        end
      end

      all_reload_descriptors << reload_descriptors
      all_reload_urandom_descriptors << reload_urandom_descriptors
    end

    assert_equal(num_reloads, all_reload_descriptors.length)
    assert_equal(num_reloads, all_reload_urandom_descriptors.length)

    all_reload_descriptors.sort_by! { |d| d.length }
    all_reload_urandom_descriptors.sort_by! { |d| d.length }

    # Test to ensure nginx modules aren't leaking urandom descriptors. Allow
    # for some small fluctuations in the /dev/urandom sockets, since nginx
    # modules might be using them.
    #
    # This stems from this leak with ngx_tixd:
    # https://github.com/streadway/ngx_txid/pull/6 We're no longer using
    # ngx_txid (using lua-resty-txid instead), so urandom descriptors shouldn't
    # actually be present, but we'll keep this test in place to ensure similar
    # leaks don't crop up again.
    min_reload_urandom_descriptors = all_reload_urandom_descriptors.first
    max_reload_urandom_descriptors = all_reload_urandom_descriptors.last
    range = max_reload_urandom_descriptors.length - min_reload_urandom_descriptors.length
    assert_operator(range, :<=, $config["nginx"]["workers"] * 4, "Minimum reload urandom descriptors: #{min_reload_urandom_descriptors.length}\n#{MultiJson.dump(min_reload_urandom_descriptors)}\n\nMaximum reload urandom descriptors: #{max_reload_urandom_descriptors.length}\n#{MultiJson.dump(max_reload_urandom_descriptors)}")

    # A more general test to ensure that we don't see other unexpected file
    # descriptor growth. We'll allow some growth for this test, though, just to
    # account for small fluctuations in sockets due to other things nginx may
    # be doing.
    min_reload_descriptors = all_reload_descriptors.first
    max_reload_descriptors = all_reload_descriptors.last
    assert_operator(min_reload_descriptors.length, :>, 0)
    range = max_reload_descriptors.length - min_reload_descriptors.length
    assert_operator(range, :<=, $config["nginx"]["workers"] * 4, "Minimum reload descriptors: #{min_reload_descriptors.length}\n#{MultiJson.dump(min_reload_descriptors)}\n\nMaximum reload descriptors: #{max_reload_descriptors.length}\n#{MultiJson.dump(max_reload_descriptors)}")
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
      original_child_pids = api_umbrella_process.nginx_child_pids(parent_pid, $config["nginx"]["workers"])

      # Randomly send reload signals every 5-500ms during the testing period.
      reload_thread = Thread.new do
        loop do
          sleep rand(0.005..0.5)
          api_umbrella_process.reload
        end
      end

      # Constantly make requests for 20 seconds while performing reloads in the
      # background thread.
      test_duration = 20
      start_time = Time.now.utc
      while(Time.now.utc - start_time < test_duration)
        response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/db-config/hello?#{rand}", http_options)
        assert_response_code(200, response)
        assert_equal("Hello World", response.body)
      end

      reload_thread.exit

      # Gather the worker ids at the end (so we can sanity check that the reloads happened).
      final_child_pids = api_umbrella_process.nginx_child_pids(parent_pid, $config["nginx"]["workers"])

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
    }) do
      nginx_config = File.read(nginx_config_path)
      assert_match("worker_processes 1;", nginx_config)
    end

    nginx_config = File.read(nginx_config_path)
    refute_match("worker_processes 1;", nginx_config)
  end

  def test_file_based_config_changes_updates_apis
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/file-config/info/", http_options)
    assert_response_code(404, response)

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
    }) do
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/file-config/info/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(data["headers"]["x-test-file-config"], "foo")
    end

    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/file-config/info/", http_options)
    assert_response_code(404, response)
  end

  private

  def nginx_parent_pid
    parent_pid = api_umbrella_process.perp_pid("nginx")
    assert(parent_pid)

    parent_pid
  end
end
