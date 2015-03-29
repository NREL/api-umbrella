module JsLocaleHelper
  def self.output_locale(locale)
    translations = YAML.load(File.open("#{Rails.root}/config/locales/#{locale}.yml"))
    markdown!(translations)

    options = {
      "locale" => locale.to_s,
      "phrases" => translations[locale.to_s],
    }

    result = <<-EOS
      var polyglot = new Polyglot(#{options.to_json});
    EOS

    result
  end

  private

  def self.markdown!(data)
    if(data.kind_of?(Hash))
      data.each do |key, value|
        if(value.kind_of?(String))
          # Parse as github-flavored markdown.
          markdown = Kramdown::Document.new(value, :input => 'GFM').to_html

          # For simple one-liner values, strip the default paragraph tags
          # converting to Markdown adds.
          if(markdown.lines.length == 1)
            markdown.gsub!(%r{<p>(.*)</p>}, "\\1")
          end

          data[key] = markdown
        else
          data[key] = markdown!(value)
        end
      end
    elsif(data.kind_of?(Array))
      data.map! do |item|
        markdown!(item)
      end
    end
  end
end
