require "config/environment"

# Define a ProxyMachine proxy server with our logic stored in the
# {#AuthProxy::Proxy} class.
require "auth_proxy/proxy"
proxy(&AuthProxy::Proxy.proxymachine_router)
