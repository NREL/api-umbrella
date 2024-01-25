require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_default_permissions_admin_view_single_scope
    factory = :google_admin
    assert_default_admin_permissions(factory, :required_permissions => ["admin_view"])
  end

  def test_default_permissions_admin_manage_single_scope
    factory = :google_admin
    assert_default_admin_permissions(factory, :required_permissions => ["admin_view", "admin_manage"])
  end

  def test_multi_group_multi_scope_permitted_as_superuser
    factory = :google_and_yahoo_multi_group_admin
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_multi_group_multi_scope_permitted_as_multi_scope_admin
    factory = :google_and_yahoo_multi_group_admin
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_permitted(factory, admin)
  end

  def test_multi_group_multi_scope_permitted_read_forbidden_modify_as_single_scope_admin
    factory = :google_and_yahoo_multi_group_admin

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
      ]),
    ])
    assert_admin_permitted_read_forbidden_modify(factory, admin)

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_permitted_read_forbidden_modify(factory, admin)
  end

  def test_single_group_multi_scope_permitted_as_superuser
    factory = :google_and_yahoo_single_group_admin
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_single_group_multi_scope_permitted_as_multi_scope_admin
    factory = :google_and_yahoo_single_group_admin
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_permitted(factory, admin)
  end

  def test_single_group_multi_scope_permitted_read_forbidden_modify_as_single_scope_admin
    factory = :google_and_yahoo_single_group_admin

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
      ]),
    ])
    assert_admin_permitted_read_forbidden_modify(factory, admin)

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_permitted_read_forbidden_modify(factory, admin)
  end

  def test_superuser_as_superuser
    factory = :admin
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_superuser_as_full_host_admin
    factory = :admin
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:localhost_root_admin_group),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_superuser_as_prefix_admin
    factory = :admin
    admin = FactoryBot.create(:google_admin)
    assert_admin_forbidden(factory, admin)
  end

  def test_forbids_updating_permitted_admins_with_unpermitted_values
    google_admin_group = FactoryBot.create(:google_admin_group)
    yahoo_admin_group = FactoryBot.create(:yahoo_admin_group)
    record = FactoryBot.create(:limited_admin, :groups => [google_admin_group])
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(200, response)

    attributes["group_ids"] = [yahoo_admin_group.id]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Admin.find(record.id)
    assert_equal([google_admin_group.id], record.group_ids)
  end

  def test_forbids_updating_unpermitted_admins_with_permitted_values
    google_admin_group = FactoryBot.create(:google_admin_group)
    yahoo_admin_group = FactoryBot.create(:yahoo_admin_group)
    record = FactoryBot.create(:limited_admin, :groups => [yahoo_admin_group])
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)

    attributes["group_ids"] = [google_admin_group.id]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Admin.find(record.id)
    assert_equal([yahoo_admin_group.id], record.group_ids)
  end

  def test_forbids_limited_admin_adding_superuser_to_existing_admin
    record = FactoryBot.create(:limited_admin)
    admin = FactoryBot.create(:limited_admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "1"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    record = Admin.find(record.id)
    assert_equal(false, record.superuser)
  end

  def test_forbids_limited_admin_adding_superuser_to_own_account
    record = FactoryBot.create(:limited_admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "1"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(record)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    record = Admin.find(record.id)
    assert_equal(false, record.superuser)
  end

  def test_forbids_limited_admin_removing_superuser_from_existing_admin
    record = FactoryBot.create(:limited_admin, :superuser => true)
    admin = FactoryBot.create(:limited_admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "0"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    record = Admin.find(record.id)
    assert_equal(true, record.superuser)
  end

  def test_permits_superuser_adding_superuser_to_existing_admin
    record = FactoryBot.create(:limited_admin)
    admin = FactoryBot.create(:admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "1"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(200, response)
    record = Admin.find(record.id)
    assert_equal(true, record.superuser)
  end

  def test_permits_superuser_removing_superuser_from_existing_admin
    record = FactoryBot.create(:limited_admin, :superuser => true)
    admin = FactoryBot.create(:admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "0"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(200, response)
    record = Admin.find(record.id)
    assert_equal(false, record.superuser)
  end

  def test_permits_any_admin_to_view_but_not_edit_own_record
    # An admin without the "admin_manage" role.
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :analytics_permission),
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["admin"], data.keys)

    attributes = admin.serializable_hash
    attributes["username"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def test_notes_only_visible_to_admin_managers_and_superusers
    record = FactoryBot.create(:google_admin, :notes => "Private notes")

    superuser_admin = FactoryBot.create(:admin)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(superuser_admin)))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("Private notes", data.fetch("admin").fetch("notes"))

    manager_admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :admin_view_and_manage_permission),
    ])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(manager_admin)))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("Private notes", data.fetch("admin").fetch("notes"))

    viewer_admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :admin_view_permission),
    ])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(viewer_admin)))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute_includes(data.fetch("admin").keys, "notes")
    refute_includes("Private notes", response.body)
  end

  def test_only_returns_permitted_groups_even_if_other_groups_exist
    superuser_admin = FactoryBot.create(:admin)
    superuser_google_admin = FactoryBot.create(:google_admin, :superuser => true)
    google_and_yahoo_multi_group_admin = FactoryBot.create(:google_and_yahoo_multi_group_admin)
    google_and_yahoo_single_group_admin = FactoryBot.create(:google_and_yahoo_single_group_admin)
    google_admin = FactoryBot.create(:google_admin)
    yahoo_admin = FactoryBot.create(:yahoo_admin)
    admins = [
      superuser_admin,
      superuser_google_admin,
      google_and_yahoo_multi_group_admin,
      google_and_yahoo_single_group_admin,
      google_admin,
      yahoo_admin,
    ]

    admins.each do |calling_admin|
      # Make the request to fetch all of the admins as each different admin to
      # see how the responses differ.
      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(calling_admin)))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)

      # Verify the expected admins in the response depending on what admin is
      # making the request.
      admin_ids = data.fetch("data").map { |r| r["id"] }
      case calling_admin
      # Superusers should return all admins and all groups they belong to.
      when superuser_admin
        assert_equal([
          superuser_admin.id,
          superuser_google_admin.id,
          google_and_yahoo_multi_group_admin.id,
          google_and_yahoo_single_group_admin.id,
          google_admin.id,
          yahoo_admin.id,
        ].sort, admin_ids.sort)

      # Admins authorized to both scopes should return all admins in either
      # scope.
      when google_and_yahoo_multi_group_admin, google_and_yahoo_single_group_admin
        assert_equal([
          superuser_google_admin.id,
          google_and_yahoo_multi_group_admin.id,
          google_and_yahoo_single_group_admin.id,
          google_admin.id,
          yahoo_admin.id,
        ].sort, admin_ids.sort)

      # Admins only authorized to a single scope should return any admins with
      # intersecting permissions, even if they won't have edit privileges on
      # some admins that belong to groups they are not fully authorized to (like
      # google_and_yahoo_multi_group_admin and
      # google_and_yahoo_single_group_admin).
      when google_admin
        assert_equal([
          superuser_google_admin.id,
          google_and_yahoo_multi_group_admin.id,
          google_and_yahoo_single_group_admin.id,
          google_admin.id,
        ].sort, admin_ids.sort)
      when yahoo_admin
        assert_equal([
          google_and_yahoo_multi_group_admin.id,
          google_and_yahoo_single_group_admin.id,
          yahoo_admin.id,
        ].sort, admin_ids.sort)
      end

      # Verify the data on each admin that's part of the API response.
      data.fetch("data").each do |admin_data|
        case admin_data.fetch("id")
        when superuser_admin.id
          groups = superuser_admin.groups
          assert_equal(0, groups.length)
          assert_equal([], admin_data.fetch("groups"))
          assert_equal([], admin_data.fetch("group_ids"))
          assert_equal(["Superuser"], admin_data.fetch("group_names"))

        when superuser_google_admin.id
          groups = superuser_google_admin.groups
          assert_equal(1, groups.length)
          assert_equal([{ "id" => groups.first.id, "name" => groups.first.name }], admin_data.fetch("groups"))
          assert_equal([groups.first.id], admin_data.fetch("group_ids"))
          assert_equal([groups.first.name, "Superuser"], admin_data.fetch("group_names"))

        when google_and_yahoo_multi_group_admin.id
          groups = google_and_yahoo_multi_group_admin.groups
          assert_equal(2, groups.length)

          # There are 2 groups, but for our more limited admins, it should only
          # return the 1 that the calling admin is authorized to.
          case calling_admin
          when google_admin
            assert_equal([{ "id" => groups.first.id, "name" => groups.first.name }], admin_data.fetch("groups"))
            assert_match(/Google Admin Group/, admin_data.fetch("groups").first.fetch("name"))
            assert_equal([groups.first.id], admin_data.fetch("group_ids"))
            assert_equal([groups.first.name], admin_data.fetch("group_names"))
            assert_match(/Google Admin Group/, admin_data.fetch("group_names").first)
          when yahoo_admin
            assert_equal([{ "id" => groups.last.id, "name" => groups.last.name }], admin_data.fetch("groups"))
            assert_match(/Yahoo Admin Group/, admin_data.fetch("groups").first.fetch("name"))
            assert_equal([groups.last.id], admin_data.fetch("group_ids"))
            assert_equal([groups.last.name], admin_data.fetch("group_names"))
            assert_match(/Yahoo Admin Group/, admin_data.fetch("group_names").first)
          else
            assert_equal(groups.map { |group| { "id" => group.id, "name" => group.name } }.sort_by { |g| g.fetch("id") }, admin_data.fetch("groups").sort_by { |g| g.fetch("id") })
            assert_equal(groups.map { |group| group.id }.sort, admin_data.fetch("group_ids").sort)
            assert_equal(groups.map { |group| group.name }.sort, admin_data.fetch("group_names").sort)
          end

        when google_and_yahoo_single_group_admin.id
          groups = google_and_yahoo_single_group_admin.groups
          assert_equal(1, groups.length)

          # For single-scope admins, the admin can view this other admin (since
          # its groups intersect), but it won't be able to update it or view its
          # groups it belongs to (since this is not a group that the
          # single-scope admin is fully authorized to).
          case calling_admin
          when google_admin, yahoo_admin
            assert_equal([], admin_data.fetch("groups"))
            assert_equal([], admin_data.fetch("group_ids"))
            assert_equal([], admin_data.fetch("group_names"))
          else
            assert_equal([{ "id" => groups.first.id, "name" => groups.first.name }], admin_data.fetch("groups"))
            assert_equal([groups.first.id], admin_data.fetch("group_ids"))
            assert_equal([groups.first.name], admin_data.fetch("group_names"))
          end
        when google_admin.id
          groups = google_admin.groups
          assert_equal(1, groups.length)
          assert_equal([{ "id" => groups.first.id, "name" => groups.first.name }], admin_data.fetch("groups"))
          assert_equal([groups.first.id], admin_data.fetch("group_ids"))
          assert_equal([groups.first.name], admin_data.fetch("group_names"))
        when yahoo_admin.id
          groups = yahoo_admin.groups
          assert_equal(1, groups.length)
          assert_equal([{ "id" => groups.first.id, "name" => groups.first.name }], admin_data.fetch("groups"))
          assert_equal([groups.first.id], admin_data.fetch("group_ids"))
          assert_equal([groups.first.name], admin_data.fetch("group_names"))
        else
          raise "Unknown admin id"
        end

        # Verify that the "show" API returns the same nested group data.
        response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin_data.fetch("id")}.json", http_options.deep_merge(admin_token(calling_admin)))
        assert_response_code(200, response)
        show_data = MultiJson.load(response.body)
        assert_equal(admin_data, show_data.fetch("admin"))
      end
    end
  end

  private

  def assert_admin_permitted(factory, admin)
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    permission_ids = admin.groups.map { |group| group.permission_ids }.flatten.uniq
    if admin.superuser? || permission_ids.include?("admin_manage")
      assert_admin_permitted_create(factory, admin)
      assert_admin_permitted_update(factory, admin)
      assert_admin_permitted_destroy(factory, admin)
    else
      assert_admin_forbidden_create(factory, admin)
      assert_admin_forbidden_update(factory, admin)
      assert_admin_forbidden_destroy(factory, admin)
    end
  end

  def assert_admin_forbidden(factory, admin)
    assert_admin_forbidden_index(factory, admin)
    assert_admin_forbidden_show(factory, admin)
    assert_admin_forbidden_create(factory, admin)
    assert_admin_forbidden_update(factory, admin)
    assert_admin_forbidden_destroy(factory, admin)
  end

  def assert_admin_permitted_read_forbidden_modify(factory, admin)
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    assert_admin_forbidden_create(factory, admin)
    assert_admin_forbidden_update(factory, admin)
    assert_admin_forbidden_destroy(factory, admin)
  end

  def assert_admin_permitted_index(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["admin"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin)
    attributes = FactoryBot.build(factory).serializable_hash
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    refute_nil(data["admin"]["username"])
    assert_equal(attributes["username"], data["admin"]["username"])
    assert_equal(1, active_count - initial_count)
  end

  def assert_admin_forbidden_create(factory, admin)
    attributes = FactoryBot.build(factory).serializable_hash
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin)
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["username"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute_nil(data["admin"]["username"])
    assert_equal(attributes["username"], data["admin"]["username"])

    record = Admin.find(record.id)
    refute_nil(record.username)
    assert_equal(attributes["username"], record.username)
  end

  def assert_admin_forbidden_update(factory, admin)
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["username"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Admin.find(record.id)
    refute_nil(record.username)
    refute_equal(attributes["username"], record.username)
  end

  def assert_admin_permitted_destroy(factory, admin)
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(204, response)
    assert_equal(-1, active_count - initial_count)
  end

  def assert_admin_forbidden_destroy(factory, admin)
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    Admin.count
  end
end
