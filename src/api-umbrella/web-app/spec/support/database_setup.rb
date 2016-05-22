RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :truncation
    DatabaseCleaner.clean
    SeedFu.seed

    # For future cleaner calls, remove everything except the permissions we've
    # seeded.
    DatabaseCleaner[:mongoid].strategy = :truncation, {
      :except => ["admin_permissions"],
    }
  end
end
