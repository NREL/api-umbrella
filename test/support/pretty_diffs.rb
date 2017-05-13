class Minitest::Test
  # Override the method minitest uses for generating diffs to use
  # awesome_inspect. This provides easier to read diffs, particularly when
  # dealing with nested, complex hashes.
  def mu_pp(obj)
    obj.awesome_inspect({
      :indent => -2,
      :index => false,
      :sort_keys => true,
      :sort_vars => true,
    })
  end
end
