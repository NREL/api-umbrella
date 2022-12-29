return function()
  local string = ngx.var.cookie_test_mock_userinfo
  return ngx.decode_base64(ngx.unescape_uri(string))
end
