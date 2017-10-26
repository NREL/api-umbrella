local http = require "resty.http"
local cjson = require "cjson"
local _M = {}
-- Function to connect with the Pep Proxy service for checking if the token is valid and retrieve
-- the user properties. The function takes the PEP Proxy host and port as parameters
-- and sends a request with the header X-Auth-Token with the value of the token provided
-- by the user. If the token is valid, PEP proxy sends a response with the user information
-- asociated to the token, otherwise, it sends a message indicating the result of the
-- validation process with his status, 404 , 402, etc.
function _M.first(host, port, token)
    local result
    local httpc = http.new()
    httpc:set_timeout(45000)
    httpc:connect(host,port)
    local res, err = httpc:request({headers = {["X-Auth-Token"] = token}})
    if res and res.status == 200 then
        local body, body_err = res:read_body()
        if not body then
            return nil, body_err
        end
        result = cjson.decode(body)
    end

    return result, err
end

return _M