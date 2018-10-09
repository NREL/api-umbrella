local http = require "resty.http"
local cjson = require "cjson"
local _M = {}

-- Function to connect with an IdP service (Google, Facebook, Fiware, Github) for checking
-- if a token is valid and retrieve the user properties. The function takes
-- the token provided by the user and the IdP provider registered in the api-backend
-- for checking if the token is valid making a validation request to the corresponding IdP.
-- If the token is valid, the user information stored in the IdP is retrieved.

function _M.first(dict)
    local idp_back_name = dict["idp"]["backend_name"]
    local token = dict["key_value"]
    local idp_host, result, res, err, rpath,resource, method
    local app_id = dict["app_id"]
    local mode = dict["mode"]
    local ssl=false
    local httpc = http.new()
    httpc:set_timeout(45000)

    if config["nginx"]["lua_ssl_trusted_certificate"] then
        ssl=true
    end
    local rquery =  "access_token="..token
    if idp_back_name == "google-oauth2" then
        rpath = "/oauth2/v3/userinfo"
        idp_host="https://www.googleapis.com"
    elseif idp_back_name == "fiware-oauth2" and mode == "authorization" then
        rpath = "/user"
        idp_host = dict["idp"]["host"]
        resource = ngx.ctx.uri
        method = ngx.ctx.request_method
        rquery = "access_token="..token.."&app_id="..app_id.."&resource="..resource.."&action="..method
    elseif idp_back_name == "fiware-oauth2" and mode == "authentication" then
        rpath = "/user"
        idp_host = dict["idp"]["host"]
        rquery = "access_token="..token.."&app_id="..app_id
    elseif idp_back_name == "facebook-oauth2" then
        rpath = "/me"
        idp_host="https://graph.facebook.com"
        rquery = "fields=id,name,email&access_token="..token
    elseif idp_back_name == "github-oauth2" then
        rpath = "/user"
        idp_host="https://api.github.com"
    end

    res, err =  httpc:request_uri(idp_host..rpath,{
        method = "GET",
        query = rquery,
        ssl_verify = ssl,
    })

    if res and (res.status == 200 or res.status == 201) then
        local body= res.body
        if not body then
            return nil
        end
        result = cjson.decode(body)

    end

    return result, err
end

return _M