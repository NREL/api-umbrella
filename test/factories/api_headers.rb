FactoryBot.define do
  factory :api_header, :class => "Api::Header" do
    key "X-Custom"
    value "value"
  end
end
