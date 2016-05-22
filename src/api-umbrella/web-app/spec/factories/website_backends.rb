FactoryGirl.define do
  factory :website_backend do
    frontend_host "localhost"
    backend_protocol "http"
    server_host "example.com"
    server_port 80

    factory :amazon_website_backend do
      frontend_host "amazon.com"
    end
  end
end
