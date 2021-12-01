return if ENV["RAILS_ASSETS_PRECOMPILE"]

API_UMBRELLA_VERSION = File.read(File.expand_path("../../../version.txt", __dir__)).strip
