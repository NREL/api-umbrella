module DeviseControllerMacros
  def login_admin
    let(:current_admin) do
      FactoryGirl.create(:admin)
    end

    before(:each) do
      @request.env["devise.mapping"] = Devise.mappings[:admin]
      sign_in current_admin
    end
  end
end

module DeviseControllerHelpers
  def admin_token_auth(admin)
    request.env["HTTP_X_ADMIN_AUTH_TOKEN"] = admin.authentication_token
  end
end

module DeviseFeatureMacros
  def login_admin
    before(:each) do
      admin = if(defined?(current_admin)) then current_admin else FactoryGirl.create(:admin) end

      Warden.test_mode!
      login_as(admin, :scope => :admin)
    end

    after(:each) do
      Warden.test_reset!
    end
  end
end

RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
  config.include DeviseControllerHelpers, :type => :controller
  config.extend DeviseControllerMacros, :type => :controller

  config.include Warden::Test::Helpers, :type => :feature
  config.extend DeviseFeatureMacros, :type => :feature
end
