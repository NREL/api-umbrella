class BootstrapNavbarTabBuilder < TabsOnRails::Tabs::TabsBuilder
  def tab_for(tab, name, options, item_options = {})
    item_options[:class] = item_options[:class].to_s.split(" ").push("active").join(" ") if current_tab?(tab)
    super
  end
end
