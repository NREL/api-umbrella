module CommonValidations
  HOST_FORMAT = %r{^[a-zA-Z0-9:][a-zA-Z0-9\-\.:]*$}
  FRONTEND_HOST_FORMAT = %r{(#{HOST_FORMAT.source}|^\*$)}
  URL_PREFIX_FORMAT = %r{^/}
end
