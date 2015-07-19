return function()
  local https_url = "https://" .. ngx.ctx.host_no_port
  if config["https_port"] and config["https_port"] ~= 443 then
    https_url = https_url .. ":" .. config["https_port"]
  end
  https_url = https_url .. ngx.ctx.original_request_uri

  return https_url
end
