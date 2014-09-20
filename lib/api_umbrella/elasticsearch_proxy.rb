module ApiUmbrella
  class ElasticsearchProxy < Rack::Proxy
    PREFIX = "/admin/elasticsearch"

    def initialize(options = {})
      super(options.merge({
        :backend => ApiUmbrellaConfig[:elasticsearch][:hosts].first,
      }))
    end

    def rewrite_env(env)
      # Rewrite /admin/elasticsearch to /
      %w(SCRIPT_NAME REQUEST_PATH REQUEST_URI).each do |key|
        if(env[key].present?)
          env[key].gsub!(/^#{PREFIX}/, "")
        end
      end

      # PATH_INFO is always missing trailing slashes. Add it back.
      # https://github.com/rails/rails/issues/3215
      if(env["ORIGINAL_FULLPATH"].end_with?("/") && !env["PATH_INFO"].end_with?("/"))
        env["PATH_INFO"] = "#{env["PATH_INFO"]}/"
      end

      env
    end

    def rewrite_response(triplet)
      status, headers, body = triplet

      # Fix <meta> tag redirects returned by elasticsearch to add our URL
      # custom prefix.
      if(status >= 300 && status < 400)
        new_body = body.to_s
        new_body.gsub!(/(url=['"]?)([^'">]+)/i) do
          tag = Regexp.last_match[1]
          url = Regexp.last_match[2]
          if(url.start_with?("/") && !url.start_with?(PREFIX))
            url = File.join(PREFIX, url)
          end

          "#{tag}#{url}"
        end

        # Fix the content length if the <meta> tag redirect was modified.
        headers["content-length"] = new_body.bytesize.to_s

        body = [new_body]
      end

      [status, headers, body]
    end
  end
end
