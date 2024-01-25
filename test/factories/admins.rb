FactoryBot.define do
  factory :admin do
    authentication_token { SecureRandom.hex(20) }
    sequence(:username) { |n| "aburnside#{n}@example.com" }
    email { username }
    password_hash { BCrypt::Password.create("password123456") }
    superuser { true }

    factory :limited_admin do
      superuser { false }
      groups do
        [FactoryBot.create(:admin_group)]
      end

      factory :localhost_root_admin do
        groups do
          [FactoryBot.create(:localhost_root_admin_group)]
        end
      end

      factory :google_admin do
        groups do
          [FactoryBot.create(:google_admin_group)]
        end
      end

      factory :yahoo_admin do
        groups do
          [FactoryBot.create(:yahoo_admin_group)]
        end
      end

      factory :google_and_yahoo_multi_group_admin do
        groups do
          [
            FactoryBot.create(:google_admin_group),
            FactoryBot.create(:yahoo_admin_group),
          ]
        end
      end

      factory :google_and_yahoo_single_group_admin do
        groups do
          [
            FactoryBot.create(:google_and_yahoo_multi_scope_admin_group),
          ]
        end
      end
    end

    factory :empty_attributes_admin do
      # Empty attributes
    end

    factory :filled_attributes_admin do
      created_at { Time.utc(2017, 1, 1) }
      created_by_id { SecureRandom.uuid }
      created_by_username { "creator@example.com" }
      current_sign_in_at { Time.utc(2017, 1, 5) }
      current_sign_in_ip { "10.11.2.3" }
      current_sign_in_provider { "Provider1" }
      failed_attempts { 3 }
      last_sign_in_at { Time.utc(2017, 1, 6) }
      last_sign_in_ip { "10.11.2.4" }
      last_sign_in_provider { "Provider2" }
      locked_at { Time.utc(2017, 1, 7) }
      name { "Name" }
      notes { "Notes" }
      remember_created_at { Time.utc(2017, 1, 4) }
      reset_password_sent_at { Time.utc(2017, 1, 3) }
      reset_password_token_hash { SecureRandom.hex(20) }
      sign_in_count { 10 }
      unlock_token_hash { SecureRandom.hex(20) }
      updated_at { Time.utc(2017, 1, 2) }
      updated_by_id { SecureRandom.uuid }
      updated_by_username { "updater@example.com" }
      groups do
        [FactoryBot.create(:admin_group, :name => "ExampleFilledGroup")]
      end
    end
  end
end
