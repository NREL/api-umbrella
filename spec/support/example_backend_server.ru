require "sinatra"

BACKEND_CALLED_FILE = File.expand_path("../../tmp/backend_called.txt", __FILE__)

class ExampleBackendApp < Sinatra::Base
  before do
    FileUtils.touch(BACKEND_CALLED_FILE)
    # A shared variable between 
    #DRb.start_service
    #shared_vars = DRbObject.new(nil, 'druby://localhost:9000')
    #shared_vars[:backend_called] = true
  end

  get "/hello" do
    "Hello World"
  end

  post "/hello" do
    "Goodbye"
  end

  post "/echo" do
    request.env["rack.input"].read
  end

  get "/api/geocode" do
    "Private Geocoding"
  end

  get "/utf8" do
    response["X-Example"] = "tést"
    "Hellö Wörld"
  end

  get "/sleep" do
    sleep 1
    "Sleepy head"
  end

  get "/sleep_timeout" do
    sleep 2
    "Sleepy head"
  end

  get "/chunked" do
    response["Content-Length"] = 11
    response['Transfer-Encoding'] = 'chunked'
    stream(:keep_open) do |out|
      out << "5\r\nHello\r\n"
      sleep 0.1
      out << "7\r\nGoodbye\r\n"
      sleep 0.1
      out << "0\r\n\r\n"
    end
  end
end

run ExampleBackendApp
