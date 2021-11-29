module ApiUmbrellaTestHelpers
  module StripStandardRequestHeaders
    private

    def strip_standard_request_headers(headers)
      headers.except(
        "accept",
        "connection",
        "host",
        "user-agent",
        "via",
        "x-api-key",
        "x-api-umbrella-backend-host",
        "x-api-umbrella-real-ip",
        "x-api-umbrella-request-id",
        "x-api-user-id",
        "x-forwarded-for",
        "x-forwarded-port",
        "x-forwarded-proto",
      )
    end
  end
end
