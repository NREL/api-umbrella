local json_decode = require("cjson").decode

return function()
  local string = ngx.var.cookie_test_mock_userinfo
  return json_decode(ngx.decode_base64(ngx.unescape_uri(string)))
end
