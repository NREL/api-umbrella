FactoryBot.define do
  factory :api_url_match, :class => "Api::UrlMatch" do
    frontend_prefix "/example-frontend/"
    backend_prefix "/example-backend/"
  end
end
