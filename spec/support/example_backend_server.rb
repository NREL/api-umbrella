# encoding: utf-8

require "childprocess"

RACKUP_FILE = File.expand_path("../example_backend_server.ru", __FILE__)

BACKEND_CALLED_FILE = File.expand_path("../../tmp/backend_called.txt", __FILE__)
FileUtils.mkdir_p(File.dirname(BACKEND_CALLED_FILE))

process = ChildProcess.build("unicorn", "--listen", "127.0.0.1:9444", RACKUP_FILE)
process.io.inherit!
process.start
sleep 1 # Wait for unicorn to spin up

at_exit do
  process.stop
end

module ExampleBackendServer
  module Helpers
    def make_request(method, path, options = {})
      pre_request
      url = "http://127.0.0.1:9333#{path}"

      EM.run do
        ApiUmbrella::Gatekeeper::Server.run(:config => File.expand_path("../../config/gatekeeper.yml", __FILE__))

        EventMachine.add_timer(0.05) do
          http = EventMachine::HttpRequest.new(url, :connect_timeout => 1.5, :inactivity_timeout => 1.5).send(method, options)
          http.errback { @last_response = http.response; @last_header = http.response_header; EM.stop }
          http.callback { @last_response = http.response; @last_header = http.response_header; EM.stop }
        end
      end

      @backend_called = File.exists?(BACKEND_CALLED_FILE)
    end

    def make_multiple_requests(count, method, path, options = {})
      pre_request
      url = "http://127.0.0.1:9333#{path}"

      EM.run do
        ApiUmbrella::Gatekeeper::Server.run(:config => File.expand_path("../../config/gatekeeper.yml", __FILE__))

        EventMachine.add_timer(0.05) do
          http = nil
          EventMachine::Iterator.new(0...count, 5).map(
            proc { |index, iter|
              http = EventMachine::HttpRequest.new(url, :connect_timeout => 0.5, :inactivity_timeout => 0.5).send(method, options)
              http.errback { |h| iter.return(h) }
              http.callback { |h| iter.return(h) }
            },
            proc { |results|
               @last_response = results.last.response
               @last_header = results.last.response_header
               EM.stop
            }
          )
        end
      end

      @backend_called = File.exists?(BACKEND_CALLED_FILE)
    end

    def send_chunks(chunks, delay = 0.0)
      pre_request

      EM.run do
        ApiUmbrella::Gatekeeper::Server.run(:config => File.expand_path("../../config/gatekeeper.yml", __FILE__))

        EventMachine.add_timer(0.05) do
          SendHttpChunks.chunks = chunks
          SendHttpChunks.delay = delay
          conn = EventMachine.connect("127.0.0.1", 9333, SendHttpChunks)
          conn.errback { @last_response = conn.response; @last_headers_hash = conn.headers; EM.stop }
          conn.callback { @last_response = conn.response; @last_headers_hash = conn.headers; EM.stop }
        end
      end
    end

    private

    def pre_request
      FileUtils.rm_f(BACKEND_CALLED_FILE)
      @last_response = nil
      @last_header = nil
      @last_headers_hash = nil
    end
  end

  class SendHttpChunks < EventMachine::Connection
    include EventMachine::Deferrable

    mattr_accessor :chunks
    mattr_accessor :delay

    attr_reader :response
    attr_reader :headers

    def post_init
      @response = ""
      @headers = nil

      @parser = Http::Parser.new
      @parser.on_body = proc { |chunk| @response << chunk }
      @parser.on_headers_complete = proc { |headers| @headers = headers }

      EventMachine::Iterator.new(chunks, 1).each do |chunk, iter|
        EM.next_tick do
          send_data chunk
          if(delay > 0)
            sleep delay
          end

          iter.next
        end
      end
    end

    def receive_data(chunk)
      @parser << chunk
    end

    def unbind
      succeed
    end
  end
end

RSpec.configure do |config|
  config.include ExampleBackendServer::Helpers
end
