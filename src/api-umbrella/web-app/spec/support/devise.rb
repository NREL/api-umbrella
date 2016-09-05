module DeviseControllerMacros
  def login_admin
    before(:each) do
      @current_admin = if(defined?(current_admin)) then current_admin else FactoryGirl.create(:admin) end
      admin_login_auth(@current_admin)
    end
  end
end

module DeviseControllerHelpers
  def admin_token_auth(admin)
    request.env["HTTP_X_ADMIN_AUTH_TOKEN"] = admin.authentication_token
  end

  def admin_login_auth(admin)
    @request.env["devise.mapping"] = Devise.mappings[:admin]
    sign_in admin
  end
end

module DeviseFeatureMacros
  def login_admin
    before(:each) do
      @current_admin = if(defined?(current_admin)) then current_admin else FactoryGirl.create(:admin) end

      Warden.test_mode!
      login_as(@current_admin, :scope => :admin)

      # FIXME: When running standalone feature tests, sometimes the first test
      # inexplicably fails. The pages appear to load, but interacting with the
      # forms and trying to save fail (it's almost like the javascript hasn't
      # fully loaded if things aren't warmed up). However, this issue goes away
      # on subsequent tests, so the super hacky workaround is to load the index
      # page once before any tests and that seems to fix the issue. We should
      # revisit sometime to try to figure out if this is a Capybara/poltergeist
      # issue or something with our app.
      #
      # rubocop:disable Style/GlobalVars
      unless($admin_loaded_once)
        visit "/admin/"
        page.should have_content("API Umbrella")
        $admin_loaded_once = true
      end
      # rubocop:enable Style/GlobalVars
    end

    after(:each) do
      Warden.test_reset!
    end
  end
end

RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, :type => :controller
  config.include DeviseControllerHelpers, :type => :controller
  config.extend DeviseControllerMacros, :type => :controller

  config.include Warden::Test::Helpers, :type => :feature
  config.extend DeviseFeatureMacros, :type => :feature
end
