shared_examples "admin permissions" do |options|
  options ||= {}

  let(:except_required_permissions) do
    AdminPermission.pluck(:id) - options[:required_permissions]
  end

  describe "superuser" do
    before(:each) do
      @admin = FactoryGirl.create(:admin)
    end
    it_behaves_like "admin permitted"
  end

  describe "localhost/* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:localhost_root_admin_group),
      ])
    end
    it_behaves_like "admin permitted"
  end

  describe "localhost/* admin with only #{options[:required_permissions].join(", ")} permissions" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:localhost_root_admin_group, :permission_ids => options[:required_permissions]),
      ])
    end
    it_behaves_like "admin permitted"
  end

  describe "localhost/* admin with all permissions except #{options[:required_permissions].join(", ")}" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:localhost_root_admin_group, :permission_ids => except_required_permissions),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "localhost/z* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:localhost_root_api_scope, :path_prefix => "/z")),
        ]),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "localhost/google* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:google_admin_group),
      ])
    end
    if(options[:root_required])
      it_behaves_like "admin forbidden"
    else
      it_behaves_like "admin permitted"
    end
  end

  describe "localhost/google* admin with only #{options[:required_permissions].join(", ")} permissions" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:google_admin_group, :permission_ids => options[:required_permissions]),
      ])
    end
    if(options[:root_required])
      it_behaves_like "admin forbidden"
    else
      it_behaves_like "admin permitted"
    end
  end

  describe "localhost/google* admin with all permissions except #{options[:required_permissions].join(", ")}" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:google_admin_group, :permission_ids => except_required_permissions),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "localhost/googl* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope, :path_prefix => "/googl")),
        ]),
      ])
    end
    if(options[:root_required])
      it_behaves_like "admin forbidden"
    else
      it_behaves_like "admin permitted"
    end
  end

  describe "localhost/googlez* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope, :path_prefix => "/googlez")),
        ]),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "localhos/* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:localhost_root_admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:localhost_root_api_scope, :host => "localhos")),
        ]),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "localhostz/* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:localhost_root_admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:localhost_root_api_scope, :host => "localhostz")),
        ]),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "localhos/google* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope, :host => "localhos")),
        ]),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "localhostz/google* full admin" do
    before(:each) do
      @admin = FactoryGirl.create(:limited_admin, :groups => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope, :host => "localhostz")),
        ]),
      ])
    end
    it_behaves_like "admin forbidden"
  end

  describe "multi-scope groups with overlapping scopes exist" do
    before(:each) do
      @localhost_root_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:localhost_root_api_scope))
      @google_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))
      @yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))
      @multi_root_scope_group = FactoryGirl.create(:admin_group, :api_scopes => [
        @localhost_root_api_scope,
        @google_api_scope,
      ])
      @multi_sub_scope_group = FactoryGirl.create(:admin_group, :api_scopes => [
        @google_api_scope,
        @yahoo_api_scope,
      ])
    end

    describe "localhost/* and localhost/google* full admin" do
      before(:each) do
        @admin = FactoryGirl.create(:limited_admin, :groups => [
          @multi_root_scope_group,
        ])
      end
      it_behaves_like "admin permitted"
    end

    describe "localhost/google* and localhost/yahoo* full admin" do
      before(:each) do
        @admin = FactoryGirl.create(:limited_admin, :groups => [
          @multi_sub_scope_group,
        ])
      end
      if(options[:root_required])
        it_behaves_like "admin forbidden"
      else
        it_behaves_like "admin permitted"
      end
    end

    describe "localhost/* full admin" do
      before(:each) do
        @admin = FactoryGirl.create(:limited_admin, :groups => [
          FactoryGirl.create(:admin_group, :api_scopes => [
            @localhost_root_api_scope,
          ]),
        ])
      end
      it_behaves_like "admin permitted"
    end

    describe "localhost/google* full admin" do
      before(:each) do
        @admin = FactoryGirl.create(:limited_admin, :groups => [
          FactoryGirl.create(:admin_group, :api_scopes => [
            @google_api_scope,
          ]),
        ])
      end
      if(options[:root_required])
        it_behaves_like "admin forbidden"
      else
        it_behaves_like "admin permitted"
      end
    end

    describe "localhost/yahoo* full admin" do
      before(:each) do
        @admin = FactoryGirl.create(:limited_admin, :groups => [
          FactoryGirl.create(:admin_group, :api_scopes => [
            @yahoo_api_scope,
          ]),
        ])
      end
      it_behaves_like "admin forbidden"
    end
  end
end
