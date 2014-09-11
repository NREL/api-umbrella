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
    let(:current_admin) do
      FactoryGirl.create(:admin)
    end

    before(:each) do
      Warden.test_mode!
      login_as(current_admin, :scope => :admin)
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
