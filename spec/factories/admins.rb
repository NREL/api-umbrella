FactoryGirl.define do
  factory :admin do
    sequence(:username) { |n| "aburnside#{n}" }
    superuser true

    factory :limited_admin do
      superuser false
    end
  end
end
