RSpec.configure do |config|
  config.before(:suite) do
    Rails.application.load_seed
  end
end
