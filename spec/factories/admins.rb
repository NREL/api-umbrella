FactoryGirl.define do
  factory :admin do
    sequence(:username) { |n| "aburnside#{n}" }
  end
end
