module JsLocaleHelper
  def self.output_locale(locale)
    translations = YAML.load(File.open("#{Rails.root}/config/locales/#{locale}.yml"))

    options = {
      "locale" => locale.to_s,
      "phrases" => translations[locale.to_s],
    }

    result = <<-EOS
      var polyglot = new Polyglot(#{options.to_json});
    EOS

    result
  end
end
