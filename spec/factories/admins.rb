FactoryGirl.define do
  factory :admin do
    sequence(:username) { |n| "aburnside#{n}" }
    superuser true

    factory :limited_admin do
      superuser false
      group_ids do
        FactoryGirl.create(:admin_group).id
      end
    end
  end
end
