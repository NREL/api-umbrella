# Clean the database using truncation (we can't use transactions, since we rely
# on the data we insert in the tests being available to the remote test server,
# which won't share the transaction).
DatabaseCleaner.strategy = :truncation, {
  :except => [
    # Don't truncate the Lapis migrations table.
    "lapis_migrations",

    # Don't truncate the API users table (or the associated relationships),
    # since we want to keep seeded users between tests. We'll manually clear
    # non-seeded records.
    "api_users",
    "api_user_settings",
    "rate_limits",
  ]
}
# ActiveRecord::Base.logger = Logger.new(STDOUT)
# DatabaseCleaner.logger = ActiveRecord::Base.logger

# Clean the database after each test.
class Minitest::Test
  def setup
    # If tests are being run in parallel, disable database cleaner between test
    # runs, since parallel tests should not reset their state between runs
    # (doing so might interfere with the other parallel tests running).
    if(self.class.test_order != :parallel)
      DatabaseCleaner.start
    end

    super
  end

  def teardown
    super

    if(self.class.test_order != :parallel)
      DatabaseCleaner.clean

      # Manually delete all the non-seeded users.
      ApiUser.where(:registration_source.ne => "seed").delete_all
    end
  end
end
