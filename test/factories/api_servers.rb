FactoryBot.define do
  factory :api_server, :class => "Api::Server" do
    host "example.com"
    port 80
  end
end
