local _M = {}

function _M.loader(self)
  self.res.headers["Content-Type"] = "text/javascript; charset=utf-8"
  self.res.headers["Cache-Control"] = "max-age=0, private, no-cache, no-store, must-revalidate"
  self.res.content = [[
    window.localeData = {
      '': {
        "domain" : "messages",
        "lang"   : "en",
      },
      'Hello, World': ['Oui'],
    };
    window.CommonValidations = {
    };
  ]]
  return { layout = false }
end

return function(app)
  app:get("/admin/server_side_loader.js", _M.loader)
end
