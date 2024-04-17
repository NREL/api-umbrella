# vi: set ft=ruby :

class Test < Thor
  desc "test", "Run tests"
  def test
    tests = ["test"]
    if ENV["TESTS"]
      tests = ENV.fetch("TESTS").split(" ")
    end

    args = []
    if ENV["CI"] == "true"
      args += ["--ci-dir", "/test/tmp/artifacts/reports"]
    end

    exec "bundle", "exec", "minitest", *(args + tests)
  end
end
