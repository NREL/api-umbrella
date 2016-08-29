# Don't include milliseconds on timestamps to maintain our older response
# formats.
ActiveSupport::JSON::Encoding.time_precision = 0

Oj.default_options = {
  # Integrate Oj with the to_json methods Rails adds to objects.
  :use_to_json => true,
}
