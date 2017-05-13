# Don't include milliseconds on timestamps to maintain our older response
# formats.
ActiveSupport::JSON::Encoding.time_precision = 0

Oj.optimize_rails
