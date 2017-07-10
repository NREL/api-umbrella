FactoryGirl.define do
  factory :admin do
    id { SecureRandom.uuid }
    authentication_token { SecureRandom.hex(20) }
    sequence(:username) { |n| "aburnside#{n}@example.com" }
    email { username }
    encrypted_password { BCrypt::Password.create("password123456") }
    superuser true

    factory :limited_admin do
      superuser false
      groups do
        [FactoryGirl.create(:admin_group)]
      end

      factory :localhost_root_admin do
        groups do
          [FactoryGirl.create(:localhost_root_admin_group)]
        end
      end

      factory :google_admin do
        groups do
          [FactoryGirl.create(:google_admin_group)]
        end
      end

      factory :google_and_yahoo_multi_group_admin do
        groups do
          [
            FactoryGirl.create(:google_admin_group),
            FactoryGirl.create(:yahoo_admin_group),
          ]
        end
      end

      factory :google_and_yahoo_single_group_admin do
        groups do
          [
            FactoryGirl.create(:google_and_yahoo_multi_scope_admin_group),
          ]
        end
      end
    end
  end
end
