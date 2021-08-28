return if ENV["RAILS_ASSETS_PRECOMPILE"]

Rails.application.config.after_initialize do
  I18n.backend.available_locales
  translations = I18n.backend.send(:translations)
  translations.each do |locale, locale_data|
    overrides = {}

    # Copy the locale data from devise-i18n's built in data for activerecord
    # "user" attributes to the mongoid attributes for the "admin" model. This
    # is so the default fields like "Password" can use the data built into
    # devise-i18n when using the Mongoid Admin model.
    admin_data = {}
    if(locale_data[:activerecord] && locale_data[:activerecord][:attributes] && locale_data[:activerecord][:attributes][:user])
      admin_data.deep_merge!(locale_data[:activerecord][:attributes][:user])
    end
    if(locale_data[:mongoid] && locale_data[:mongoid][:attributes] && locale_data[:mongoid][:attributes][:admin])
      admin_data.deep_merge!(locale_data[:mongoid][:attributes][:admin])
    end

    # If we're treating all usernames as e-mail addresses, then change the
    # "Username" label to "Email" so our forms make more sense.
    if(ApiUmbrellaConfig[:web][:admin][:username_is_email])
      admin_data[:username] = admin_data[:email]
    end

    overrides.deep_merge!({
      :mongoid => { :attributes => { :admin => admin_data } },
    })

    if(ApiUmbrellaConfig[:web][:admin][:auth_strategies][:ldap] && ApiUmbrellaConfig[:web][:admin][:auth_strategies][:ldap][:options] && ApiUmbrellaConfig[:web][:admin][:auth_strategies][:ldap][:options][:title].presence)
      overrides.deep_merge!({
        :omniauth_providers => {
          :ldap => ApiUmbrellaConfig[:web][:admin][:auth_strategies][:ldap][:options][:title],
        },
      })
    end

    I18n.backend.store_translations(locale, overrides)
  end
end
