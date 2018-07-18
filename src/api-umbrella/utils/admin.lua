local http = require "resty.http"
local cjson = require "cjson"
local mongo = require "api-umbrella.utils.mongo"

local _M = {}

-- Function for creating a new user in the system using the admin APIs
-- in order to ensure that all intermediate objects and validations
-- are performed

function _M.create_user(ext_user)
    local admin_user
    local admin_obj
    local db_err
    local api_key
    local auth_token

    local options = {
        method = "POST",
        path = "/api-umbrella/v1/users",
        ssl_verify = false
    }

    -- Get API-Key and Auth-Token
    admin_user, db_err = mongo.first("api_users", {
        query = {
          email = "web.admin.ajax@internal.apiumbrella"
        },
    })
    
    if not admin_user then
        return nil, "Default admin user not found, please review umbrella configuration"
    end

    api_key = admin_user["api_key"]

    admin_obj, db_err = mongo.first("admins", {
        query = {
            superuser = true
        },
    })

    if not admin_obj then
        return nil, "There isn't any admin registered"
    end

    auth_token = admin_obj["authentication_token"]

    -- Build user object from external user
    local user_obj = {
        email = ext_user["email"],
        first_name = "-",
        last_name = "-",
        email_verified = true,
        terms_and_conditions = true
    }

    -- Make request
    options["headers"] = {
        ["Content-Type"] = "application/json",
        ["X-API-Key"] = api_key,
        ["X-Auth-Token"] = auth_token
    }
    options["body"] = cjson.encode(user_obj)

    local httpc = http.new()
    httpc:set_timeout(45000)

    -- Get internal host and port of the web server from config 
    local host = "127.0.0.1"
    local port = config["https_port"]

    httpc:connect(host, port)
    httpc:ssl_handshake()

    local res, err = httpc:request(options)

    if err or (res and res.status ~= 200) then
        return nil, "It has not been possible to create internal user structures"
    end

    -- FIXME: The first request with a new user always fails with a 406 error
    return mongo.first("api_users", {
        query = {
          email = ext_user["email"]
        },
    })
end

return _M