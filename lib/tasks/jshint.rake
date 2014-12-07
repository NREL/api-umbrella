begin
  require "jshintrb/jshinttask"
  Jshintrb::JshintTask.new :jshint do |t|
    t.pattern = 'app/assets/javascripts/**/*.js'
    t.exclude_pattern = [
      'app/assets/javascripts/vendor/**/*.js',
      'app/assets/javascripts/polyfills/**/*.js',
    ]
    t.options = {
      :browser => true,
      :esnext => true,
      :bitwise => true,
      :camelcase => false,
      :curly => true,
      :eqeqeq => true,
      :immed => true,
      :indent => 2,
      :latedef => true,
      :newcap => true,
      :noarg => true,
      :quotmark => "single",
      :regexp => true,
      :sub => true,
      :undef => true,
      :unused => true,
      :strict => false,
      :trailing => true,
      :smarttabs => true,
    }
    t.globals = [
      "_",
      "$",
      "ace",
      "Admin",
      "bootbox",
      "currentAdmin",
      "Ember",
      "google",
      "ic",
      "inflection",
      "JsDiff",
      "jstz",
      "jQuery",
      "moment",
      "numeral",
      "PNotify",
      "polyglot",
      "Spinner",
      "webAdminAjaxApiKey",
    ]
  end
rescue LoadError
  desc "You need the `jshintrb` gem to run jshint"
  task :jshint
end
