FactoryGirl.define do
  factory :api_backend_rewrite do
    matcher_type "regex"
    http_method "any"
    frontend_matcher "^/foo"
    backend_replacement "/bar"
  end
end
