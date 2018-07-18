FactoryBot.define do
  factory :api_rewrite, :class => "Api::Rewrite" do
    matcher_type "regex"
    http_method "any"
    frontend_matcher "^/foo"
    backend_replacement "/bar"
  end
end
