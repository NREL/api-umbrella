class TabsOnRails::Tabs::TabsBuilder
  def tab_for(tab, name, url_options, item_options = {})
    item_options[:class] = item_options[:class].to_s.split(" ").push("current").join(" ") if current_tab?(tab)
    link_html_options = item_options.delete(:link_html)
    content = @context.link_to(name, url_options, link_html_options)
    @context.content_tag(:li, content, item_options)
  end
end
