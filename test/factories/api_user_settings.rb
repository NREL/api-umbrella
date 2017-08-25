FactoryGirl.define do
  factory :api_user_settings do
    id { SecureRandom.uuid }
  end
end
