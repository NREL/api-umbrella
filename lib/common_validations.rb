module CommonValidations
  BASE_HOST_FORMAT = %r{[a-zA-Z0-9:][a-zA-Z0-9\-\.:]*}
  HOST_FORMAT = %r{^#{BASE_HOST_FORMAT.source}$}
  FRONTEND_HOST_FORMAT = %r{^(\*|\*?#{BASE_HOST_FORMAT.source}|\*\.#{BASE_HOST_FORMAT.source})$}
  URL_PREFIX_FORMAT = %r{^/}
end
