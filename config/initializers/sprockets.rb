# Fix relative CSS urls to absolute ones during precompile.
if(!Rails.application.config.serve_static_assets && Rails.groups.include?("assets"))
  Rails.application.assets.register_preprocessor 'text/css', Sprockets::UrlRewriter
end
