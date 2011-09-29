module ApplicationHelper
  def html_title
    title = "NREL: Developer Network"
    
    if crumbs.any?
      title << " - #{crumbs.last.first}"
    end

    title
  end

  def highlight_code(language, code)
    highlighted = Albino.new(code, language).colorize(:O => "linenos=True")

    %(<div class="highlight-code">#{highlighted}</div>).html_safe
  end

  def cached_highlight_code(language, code)
    cache("highlight_code_#{Digest::SHA1.hexdigest(code)}") do
      safe_concat(highlight_code(language, code))
    end
  end
end
