class ApiScope
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :name, :type => String
  field :host, :type => String
  field :path_prefix, :type => String

  def self.find_or_create_by_instance!(other)
    attributes = other.attributes.slice("host", "path_prefix")
    record = self.where(attributes).first
    unless(record)
      record = other
      record.save!
    end

    record
  end
end

class AdminPermission
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true
  field :name, :type => String
  field :display_order, :type => Integer
end

class AdminGroup
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :name, :type => String
  has_and_belongs_to_many :api_scopes, :class_name => "ApiScope", :inverse_of => nil
  has_and_belongs_to_many :permissions, :class_name => "AdminPermission", :inverse_of => nil
end

class Admin
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :username, :type => String
  field :email, :type => String
  field :name, :type => String
  field :notes, :type => String
  field :superuser, :type => Boolean
  field :authentication_token, :type => String
  field :last_sign_in_provider, :type => String
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String
  has_and_belongs_to_many :groups, :class_name => "AdminGroup", :inverse_of => nil
end

FactoryGirl.define do
  factory :api_scope do
    name "Example"
    host "localhost"
    path_prefix "/example"

    factory :localhost_root_api_scope do
      path_prefix "/"
    end

    factory :google_api_scope do
      path_prefix "/google"
    end

    factory :yahoo_api_scope do
      path_prefix "/yahoo"
    end

    factory :extra_api_scope do
      path_prefix "/extra"
    end

    factory :bing_all_api_scope do
      path_prefix "/bing"
    end

    factory :bing_search_api_scope do
      path_prefix "/bing/search"
    end

    factory :bing_images_api_scope do
      path_prefix "/bing/images"
    end

    factory :bing_maps_api_scope do
      path_prefix "/bing/maps"
    end
  end
end

FactoryGirl.define do
  factory :admin_group do
    sequence(:name) { |n| "Example#{n}" }
    api_scopes { [ApiScope.find_or_create_by_instance!(FactoryGirl.build(:api_scope))] }
    permission_ids [
      "analytics",
      "user_view",
      "user_manage",
      "admin_manage",
      "backend_manage",
      "backend_publish",
    ]

    trait :analytics_permission do
      permission_ids ["analytics"]
    end

    trait :user_view_permission do
      permission_ids ["user_view"]
    end

    trait :user_manage_permission do
      permission_ids ["user_manage"]
    end

    trait :admin_manage_permission do
      permission_ids ["admin_manage"]
    end

    trait :backend_manage_permission do
      permission_ids ["backend_manage"]
    end

    trait :backend_publish_permission do
      permission_ids ["backend_publish"]
    end

    factory :localhost_root_admin_group do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryGirl.build(:localhost_root_api_scope))] }
    end

    factory :google_admin_group do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))] }
    end

    factory :yahoo_admin_group do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))] }
    end

    factory :google_and_yahoo_multi_scope_admin_group do
      api_scopes do
        [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope)),
        ]
      end
    end

    factory :bing_admin_group_single_all_scope do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryGirl.build(:bing_all_api_scope))] }
    end

    factory :bing_admin_group_single_restricted_scope do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryGirl.build(:bing_search_api_scope))] }
    end

    factory :bing_admin_group_multi_scope do
      api_scopes do
        [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:bing_search_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:bing_images_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:bing_maps_api_scope)),
        ]
      end
    end
  end
end

FactoryGirl.define do
  factory :admin do
    sequence(:username) { |n| "aburnside#{n}" }
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
