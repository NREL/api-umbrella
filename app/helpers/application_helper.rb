module ApplicationHelper
  def html_title
    title = "NREL: Developer Network"
    
    if crumbs.any?
      title << " - #{crumbs.last.first}"
    end

    title
  end
end
