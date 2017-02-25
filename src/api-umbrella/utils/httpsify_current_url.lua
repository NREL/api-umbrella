return function()
  local https_url = "https://" .. ngx.ctx.host_normalized
  if config["override_public_https_port"] then
    if config["override_public_https_port"] ~= 443 then
      https_url = https_url .. ":" .. config["override_public_https_port"]
    end
  elseif config["https_port"] and config["https_port"] ~= 443 then
    https_url = https_url .. ":" .. config["https_port"]
  end
  https_url = https_url .. ngx.ctx.original_request_uri

  return https_url
end
