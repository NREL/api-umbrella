require "vcr"

VCR.configure do |c|
  c.cassette_library_dir = "#{::Rails.root}/spec/cassettes"
  c.hook_into :webmock
  c.default_cassette_options = {
    :record => :new_episodes,

    # Store gzip responses as plaintext in the YAML.
    :decode_compressed_response => true,

    # Allow the same response to be used multiple times in a single test.
    :allow_playback_repeats => true,
  }

  # Allow localhost connections for ElasticSearch.
  c.ignore_localhost = true

  c.configure_rspec_metadata!
end
