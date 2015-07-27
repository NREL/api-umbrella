module ActionDispatch
  class RemoteIp
    # Override the default list of trusted_proxies to only include 127.0.0.1.
    #
    # Without this, Rails methods like request.remote_ip and request.local? get
    # things wrong with the combination of X-Forwarded-For headers (coming from
    # HAProxy) and our internal network IP addresses. The problem is that our
    # internal IP addresses start with 10.*. By default, Rails considers IPs in
    # this range to be local requests. However, we don't actaully want these
    # IPs considered local when we're on our staging or production servers,
    # even if the requests are coming from internal NREL computers. Otherwise,
    # Rails will return debug error messages to AppScan and Cyber Security, as
    # well as remote_ip being wrong.
    #
    # Ideally this could be configured using only the
    # `config.action_dispatch.trusted_proxies` app config, but currently that
    # configuration parameter is only additive (it can't get rid of the default
    # 10.* addresses): https://github.com/rails/rails/pull/2632
    def initialize(app, check_ip_spoofing = true, trusted_proxies = nil)
      @app = app
      @check_ip_spoofing = check_ip_spoofing
      regex = '(^127\.0\.0\.1$)'
      regex << "|(#{trusted_proxies})" if trusted_proxies
      @trusted_proxies = Regexp.new(regex, "i")
    end
  end
end
