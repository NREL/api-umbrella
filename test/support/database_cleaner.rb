# Clean the database using truncation (we can't use transactions, since we rely
# on the data we insert in the tests being available to the remote test server,
# which won't share the transaction).
DatabaseCleaner.strategy = :truncation, {
  :except => [
    "lapis_migrations",
  ]
}

# Clean the database after each test.
class Minitest::Test
  def setup
    DatabaseCleaner.start
    super
  end

  def teardown
    super
    DatabaseCleaner.clean
  end
end
