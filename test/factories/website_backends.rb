FactoryBot.define do
  factory :website_backend do
    sequence(:frontend_host) { |n| "#{n}.example.com" }
    backend_protocol "http"
    server_host "example.com"
    server_port 80

    factory :website_backend_localhost do
      frontend_host "localhost"
    end
  end
end
