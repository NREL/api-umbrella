module ApiUmbrellaTestHelpers
  module AdminPermissions
    def assert_default_admin_permissions(factory, options)
      # Define what all of the permissions would be except for the required one
      # so we can test to ensure no other permissions grant privileges except
      # the required ones.
      options[:except_required_permissions] = AdminPermission.pluck(:id) - options[:required_permissions]

      # One exception is if the only required permission is admin_view, then
      # when testing users without permissions, we don't want to include the
      # admin_manage permission, since admin_manage also grants permissions to
      # some actions admin_view normally would. We don't expect a user to have
      # admin_manage without admin_view, so this should be okay.
      if options[:required_permissions] == ["admin_view"]
        options[:except_required_permissions] -= ["admin_manage"]
      end

      assert_as_superuser(factory, options)
      assert_as_localhost_prefix_full_admin(factory, options)
      assert_as_localhost_prefix_admin_only_required_permissions(factory, options)
      assert_as_localhost_prefix_admin_except_required_permissions(factory, options)
      assert_as_localhost_sub_prefix_full_admin(factory, options)
      assert_as_google_prefix_full_admin(factory, options)
      assert_as_google_prefix_admin_only_required_permissions(factory, options)
      assert_as_google_prefix_admin_except_required_permissions(factory, options)
      assert_as_google_parent_prefix_full_admin(factory, options)
      assert_as_google_sub_prefix_full_admin(factory, options)
      assert_as_localhost_incomplete_host_full_admin(factory, options)
      assert_as_localhost_trailing_host_full_admin(factory, options)
      assert_as_google_incomplete_host_full_admin(factory, options)
      assert_as_google_trailing_host_full_admin(factory, options)
      assert_overlapping_scopes_as_localhost_and_google_full_admin(factory, options)
      assert_overlapping_scopes_as_google_and_yahoo_full_admin(factory, options)
      assert_overlapping_scopes_as_localhost_full_admin(factory, options)
      assert_overlapping_scopes_as_google_full_admin(factory, options)
      assert_overlapping_scopes_as_yahoo_full_admin(factory, options)
    end

    def assert_as_superuser(factory, options)
      admin = FactoryBot.create(:admin)
      assert_admin_permitted(factory, admin)
    end

    def assert_as_localhost_prefix_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:localhost_root_admin_group),
      ])
      assert_admin_permitted(factory, admin)
    end

    def assert_as_localhost_prefix_admin_only_required_permissions(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:localhost_root_admin_group, :permission_ids => options[:required_permissions]),
      ])
      assert_admin_permitted(factory, admin)
    end

    def assert_as_localhost_prefix_admin_except_required_permissions(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:localhost_root_admin_group, :permission_ids => options[:except_required_permissions]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_as_localhost_sub_prefix_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:localhost_root_api_scope, :path_prefix => "/z")),
        ]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_as_google_prefix_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:google_admin_group),
      ])
      if(options[:root_required])
        assert_admin_forbidden(factory, admin)
      else
        assert_admin_permitted(factory, admin)
      end
    end

    def assert_as_google_prefix_admin_only_required_permissions(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:google_admin_group, :permission_ids => options[:required_permissions]),
      ])
      if(options[:root_required])
        assert_admin_forbidden(factory, admin)
      else
        assert_admin_permitted(factory, admin)
      end
    end

    def assert_as_google_prefix_admin_except_required_permissions(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:google_admin_group, :permission_ids => options[:except_required_permissions]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_as_google_parent_prefix_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope, :path_prefix => "/googl")),
        ]),
      ])
      if(options[:root_required])
        assert_admin_forbidden(factory, admin)
      else
        assert_admin_permitted(factory, admin)
      end
    end

    def assert_as_google_sub_prefix_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope, :path_prefix => "/googlez")),
        ]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_as_localhost_incomplete_host_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:localhost_root_admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:localhost_root_api_scope, :host => "localhos")),
        ]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_as_localhost_trailing_host_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:localhost_root_admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:localhost_root_api_scope, :host => "localhostz")),
        ]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_as_google_incomplete_host_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope, :host => "localhos")),
        ]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_as_google_trailing_host_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope, :host => "localhostz")),
        ]),
      ])
      assert_admin_forbidden(factory, admin)
    end

    def assert_overlapping_scopes_as_localhost_and_google_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:localhost_root_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
        ]),
      ])
      assert_admin_permitted(factory, admin)
    end

    def assert_overlapping_scopes_as_google_and_yahoo_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
        ]),
      ])
      if(options[:root_required])
        assert_admin_forbidden(factory, admin)
      else
        assert_admin_permitted(factory, admin)
      end
    end

    def assert_overlapping_scopes_as_localhost_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:localhost_root_api_scope)),
        ]),
      ])
      assert_admin_permitted(factory, admin)
    end

    def assert_overlapping_scopes_as_google_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
        ]),
      ])
      if(options[:root_required])
        assert_admin_forbidden(factory, admin)
      else
        assert_admin_permitted(factory, admin)
      end
    end

    def assert_overlapping_scopes_as_yahoo_full_admin(factory, options)
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
        ]),
      ])
      assert_admin_forbidden(factory, admin)
    end
  end
end
