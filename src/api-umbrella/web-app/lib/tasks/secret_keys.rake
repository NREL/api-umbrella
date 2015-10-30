namespace :secret_keys do
  desc ""
  task :generate do
    puts <<-eos

Here are new, random keys you can use for running your application in
production:

  RAILS_SECRET_TOKEN=#{SecureRandom.hex(64)}
  DEVISE_SECRET_KEY=#{SecureRandom.hex(64)}

It's recommended that you store these as environment variables on your servers.
A local .env file inside this project may be used for this purpose. See the
dotenv gem for more details: https://github.com/bkeepers/dotenv

    eos
  end
end
