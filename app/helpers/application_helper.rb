module ApplicationHelper
  def html_title
    title = "NREL: Developer Network"
    
    if crumbs.any?
      title << " - #{crumbs.last.first}"
    end

    title
  end

  def highlight_code(language, code)
    cache("highlight_code_#{Digest::SHA1.hexdigest(code)}") do
      safe_concat(Albino.new(code, language).colorize(:O => "linenos=True"))
    end
  end
end
