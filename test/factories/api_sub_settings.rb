FactoryBot.define do
  factory :api_sub_setting, :class => "Api::SubSettings" do
    http_method "POST"
    regex ".*"
  end
end
