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

RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
  config.include DeviseControllerHelpers, :type => :controller
  config.extend DeviseControllerMacros, :type => :controller
end
