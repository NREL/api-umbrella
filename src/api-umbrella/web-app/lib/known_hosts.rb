class KnownHosts
  def initialize
    file_config = ApiUmbrellaConfig.deep_stringify_keys

    api_backends = (file_config["internal_apis"] || []) +
      (file_config["apis"] || []) +
      (ConfigVersion.active_config["apis"] || [])
    website_backends = (file_config["internal_website_backends"] || []) +
      (file_config["website_backends"] || []) +
      (ConfigVersion.active_config["website_backends"] || [])

    # Compile a list of all the known API frontend hosts based on the file or
    # database configuration.
    @known_api_hosts = Set.new
    @known_api_hosts << ApiUmbrellaConfig[:web][:default_host]
    @known_api_hosts << ApiUmbrellaConfig[:router][:web_app_host]
    if file_config["hosts"]
      file_config["hosts"].each do |host|
        @known_api_hosts << host["hostname"]
      end
    end
    api_backends.each do |api|
      @known_api_hosts << api["frontend_host"]
    end

    # Compile a list of all the known "root" hosts for all API and website
    # backend hosts. These root hosts account for public suffixes, so the root
    # domain for "api.example.com" would be "example.com", while
    # "api.cloudfront.net" would still be "api.cloudfront.net" (since other
    # subdomains under a public suffix list may not be owned by you).
    @known_root_hosts = @known_api_hosts.dup
    website_backends.each do |website_backend|
      @known_root_hosts << website_backend["frontend_host"]
    end
    @known_root_hosts.map! { |domain| PublicSuffix.domain(domain) }
  end

  def sanitized_url(url)
    host = url_host(url)
    if allowed_host?(host)
      url
    else
      Rails.logger.warn("Rejecting unknown url host: #{url}")
      nil
    end
  end

  def sanitized_api_url(url)
    host = url_host(url)
    allowed_api_host?(host) ? url : nil
  end

  def sanitized_email(email)
    host = email_host(email)
    if allowed_host?(host)
      email
    else
      Rails.logger.warn("Rejecting unknown email host: #{email}")
      nil
    end
  end

  def allowed_host?(host)
    root_host = PublicSuffix.domain(host)
    @known_root_hosts.include?(root_host)
  end

  def allowed_api_host?(host)
    @known_api_hosts.include?(host)
  end

  private

  def url_host(url)
    return nil if url.blank?

    begin
      Addressable::URI.parse(url).host
    rescue Addressable::URI::InvalidURIError
      nil
    end
  end

  def email_host(email)
    return nil if email.blank?

    begin
      Mail::Address.new(email).domain
    rescue Mail::Field::IncompleteParseError
      nil
    end
  end
end
