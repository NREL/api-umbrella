class BootstrapNavbarTabBuilder < TabsOnRails::Tabs::TabsBuilder
  def tab_for(tab, name, url_options, item_options = {}, &block)
    item_options[:class] = item_options[:class].to_s.split(" ").push("active").join(" ") if current_tab?(tab)

    link_html_options = item_options.delete(:link_html)
    content = @context.link_to(name, url_options, link_html_options)
    if block
      content << @context.capture(&block)
    end

    @context.content_tag(:li, content, item_options)
  end
end
