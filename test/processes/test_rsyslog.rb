require_relative "../test_helper"

class Test::Processes::TestRsyslog < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging

  def setup
    super
    setup_server
  end

  # To make sure rsyslog doesn't leak memory while logging requests:
  # https://github.com/rsyslog/rsyslog/issues/1668
  def test_memory_leak
    # Make some initial requests, to ensure rsyslog is warmed up, which should
    # stabilize its memory use.
    make_requests(2000)
    warmed_memory_use = memory_use
    warmed_error_log_size = elasticsearch_error_log_size

    # Make more requests.
    make_requests(8000)
    final_memory_use = memory_use
    final_error_log_size = elasticsearch_error_log_size

    # Compare the memory use before and after making requests. We're going to
    # assume it should be not grow more than 4MB (we need to allow for some
    # fluctuations under normal use).
    rss_diff = final_memory_use.fetch(:rss) - warmed_memory_use.fetch(:rss)
    assert_operator(rss_diff, :<=, 4096)

    # Also ensure nothing was generated in the elasticsearch error log file,
    # since the specific problem in v8.28.0 generated error data.
    assert_equal(warmed_error_log_size, final_error_log_size)
  end

  private

  def make_requests(count)
    request = nil
    hydra = Typhoeus::Hydra.new
    count.times do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello/", log_http_options)
      hydra.queue(request)
    end
    hydra.run

    # Just check for the last request made and make sure it gets logged.
    assert_response_code(200, request.response)
    wait_for_log(request.response)
  end

  def memory_use
    pid = File.read(File.join($config["run_dir"], "rsyslogd.pid"))
    output, status = run_shell("ps -o vsz=,rss= #{pid}")
    assert_equal(0, status, output)

    columns = output.strip.split(/\s+/)
    assert_equal(2, columns.length, columns)

    memory = {
      :vsz => Integer(columns[0]),
      :rss => Integer(columns[1]),
    }

    assert_operator(memory[:vsz], :>, 0)
    assert_operator(memory[:rss], :>, 0)

    memory
  end

  def elasticsearch_error_log_size
    size = 0
    path = File.join($config["log_dir"], "rsyslog/elasticsearch_error.log")
    if(File.exist?(path))
      size = File.size(path)
    end

    size
  end
end
