module JsLocaleHelper
  def self.markdown!(data)
    if(data.kind_of?(Hash))
      data.each do |key, value|
        if(value.kind_of?(String))
          if(key =~ /_markdown$/)
            # Parse as github-flavored markdown.
            data[key] = Kramdown::Document.new(value, :input => 'GFM').to_html
          end
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
