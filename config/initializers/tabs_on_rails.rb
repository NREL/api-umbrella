class TabsOnRails::Tabs::TabsBuilder
  def tab_for(tab, name, options, item_options = {})
    item_options[:class] = item_options[:class].to_s.split(" ").push("current").join(" ") if current_tab?(tab)
    content = @context.link_to(name, options)
    @context.content_tag(:li, content, item_options)
  end
end
