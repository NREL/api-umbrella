module ApiDocServicesHelper
  PYGMENTS_LANGUAGE_MAP = {
    "jscript" => "javascript",
    "plain" => "text",
  }

  def render_service_body(service)
    html = render("service_body")

    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.xpath(".//h2 | .//h3").each do |header|
      header["id"] ||= header.content.to_slug.normalize.to_s
    end

    doc.xpath(".//pre").each do |pre|
      if(pre["class"] =~ /brush:(\w+)/)
        language = $1
        if(PYGMENTS_LANGUAGE_MAP.key?(language))
          language = PYGMENTS_LANGUAGE_MAP[language]
        end

        highlighted = Albino.new(pre.content, language).colorize(:O => "linenos=True")
        pre.replace(highlighted)
      end
    end

    doc.css(".docs-parameter-required").each do |required|
      if(required.content.strip ==  "No")
        required["class"] = "#{required["class"]} docs-parameter-unemphasized"
      end
    end

    doc.css(".docs-parameter-value-field").each do |field|
      if(field.content.strip ==  "Default: None")
        field["class"] = "#{field["class"]} docs-parameter-unemphasized"
      end
    end

    doc.to_html.html_safe
  end
end
