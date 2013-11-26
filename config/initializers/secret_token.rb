# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
development_secret_token = "27f8bb481eebc6a51a88b10582798a5a8ce187ebd4a1e6882493ee3590fe53e01367133d8e2f8806dc8cee6436180460c54862cf3bc72f43eca515c885d29777"
ApiUmbrella::Application.config.secret_token = ENV["RAILS_SECRET_TOKEN"] || development_secret_token
if(!%w(development test).include?(Rails.env))
  if(ApiUmbrella::Application.config.secret_token == development_secret_token)
    raise "An insecure secret token is being used. Please set the RAILS_SECRET_TOKEN environment variable with your own private key. Run 'rake secret_keys:generate' for more details."
  end
end
