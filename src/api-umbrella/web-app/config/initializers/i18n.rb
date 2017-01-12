Rails.application.config.after_initialize do
  # Copy the locale data from devise-i18n's built in data for activerecord user
  # attributes to the mongoid attributes for the admin user. This is so the
  # default fields like "Password" can use the data built into devise-i18n when
  # using the Mongoid Admin model.
  I18n.available_locales.each do |locale|
    admin_data = {}
    if(I18n.backend.exists?(locale, "activerecord.attributes.user"))
      admin_data.deep_merge!(I18n.backend.translate(locale, "activerecord.attributes.user"))
    end
    if(I18n.backend.exists?(locale, "mongoid.attributes.admin"))
      admin_data.deep_merge!(I18n.backend.translate(locale, "mongoid.attributes.admin"))
    end

    I18n.backend.store_translations(locale, { :mongoid => { :attributes => { :admin => admin_data } } })
  end
end
