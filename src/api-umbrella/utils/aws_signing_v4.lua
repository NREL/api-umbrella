local nettle_hmac = require "resty.nettle.hmac"
local resty_sha256 = require "resty.sha256"
local to_hex = require("resty.string").to_hex

local escape_uri = ngx.escape_uri
local gsub = ngx.re.gsub
local ngx_var = ngx.var
local now = ngx.now
local req_get_body_data = ngx.req.get_body_data
local req_get_headers = ngx.req.get_headers
local req_get_uri_args = ngx.req.get_uri_args
local req_read_body = ngx.req.read_body
local req_set_header = ngx.req.set_header

local AWS_SERVICE = "es"
local UNSIGNED_HEADERS = {
  authorization = 1,
  expect = 1,
}

local _M = {}

local function hmac(secret_key, value)
  assert(secret_key)
  assert(value)

  local hmac_sha256 = nettle_hmac.sha256.new(secret_key)
  hmac_sha256:update(value)
  local binary = hmac_sha256:digest()

  return binary
end

local function sha256_hexdigest(value)
  local sha256 = resty_sha256:new()
  sha256:update(value or "")
  return to_hex(sha256:final())
end

local function canonical_header_name(name)
  return string.lower(name)
end

local function canonical_header_value(value)
  return gsub(value, [[\s+]], " ", "jo")
end

local function escape_uri_component(value)
  if(value == true) then
    return ""
  else
    return escape_uri(value or "")
  end
end

local function get_headers()
  local headers = {}

  local raw_headers = req_get_headers()
  for name, value in pairs(raw_headers) do
    if type(value) == "table" then
      for multi_name, multi_value in pairs(value) do
        table.insert(headers, {
          name = canonical_header_name(multi_name),
          value = canonical_header_value(multi_value),
        })
      end
    else
      table.insert(headers, {
        name = canonical_header_name(name),
        value = canonical_header_value(value),
      })
    end
  end

  return headers
end

local function get_canonical_headers(headers)
  local canonical = {}
  for _, header in ipairs(headers) do
    if not UNSIGNED_HEADERS[header.name] then
      table.insert(canonical, header.name .. ":" .. header.value)
    end
  end

  table.sort(canonical)
  return table.concat(canonical, "\n")
end

local function get_signed_headers(headers)
  local signed = {}
  for _, header in ipairs(headers) do
    if not UNSIGNED_HEADERS[header.name] then
      table.insert(signed, header.name)
    end
  end

  table.sort(signed)
  return table.concat(signed, ";")
end

local function get_canonical_query_string()
  local canonical = {}
  local args = req_get_uri_args()
  for name, value in pairs(args) do
    if type(value) == "table" then
      for multi_name, multi_value in pairs(value) do
        table.insert(canonical, escape_uri_component(multi_name) .. "=" .. escape_uri_component(multi_value))
      end
    else
      table.insert(canonical, escape_uri_component(name) .. "=" .. escape_uri_component(value))
    end
  end

  table.sort(canonical)
  return table.concat(canonical, "&")
end

local function get_canonical_request(headers, signed_headers, content_sha256)
  return table.concat({
    ngx_var.request_method,
    gsub(escape_uri(ngx_var.uri), [[%2F]], "/", "ijo"),
    get_canonical_query_string(),
    get_canonical_headers(headers) .. "\n",
    signed_headers,
    content_sha256,
  }, "\n")
end

local function get_credential_scope(aws_region, date)
  return table.concat({
    date,
    aws_region,
    AWS_SERVICE,
    "aws4_request",
  }, "/")
end

local function get_string_to_sign(datetime, credential_scope, canonical_request)
  return table.concat({
    "AWS4-HMAC-SHA256",
    datetime,
    credential_scope,
    sha256_hexdigest(canonical_request),
  }, "\n")
end

local function get_signature(aws_region, aws_secret_access_key, date, string_to_sign)
  local k_date = hmac("AWS4" .. aws_secret_access_key, date)
  local k_region = hmac(k_date, aws_region)
  local k_service = hmac(k_region, AWS_SERVICE)
  local k_credentials = hmac(k_service, "aws4_request")
  return to_hex(hmac(k_credentials, string_to_sign))
end

local function get_authorization(aws_access_key_id, credential_scope, signed_headers, signature)
  return table.concat({
    "AWS4-HMAC-SHA256 Credential=" .. aws_access_key_id .. "/" .. credential_scope,
    "SignedHeaders=" .. signed_headers,
    "Signature=" .. signature,
  }, ", ")
end

function _M.sign_request(aws_region, aws_access_key_id, aws_secret_access_key)
  local datetime = os.date("!%Y%m%dT%H%M%SZ", now())
  local date = string.sub(datetime, 1, 8)
  req_set_header("X-Amz-Date", os.date("!%Y%m%dT%H%M%SZ", now()))

  req_read_body()
  local body = req_get_body_data()
  local content_sha256 = sha256_hexdigest(body)
  req_set_header("X-Amz-Content-Sha256", content_sha256)

  local headers = get_headers()
  local signed_headers = get_signed_headers(headers)
  local credential_scope = get_credential_scope(aws_region, date)

  local canonical_request = get_canonical_request(headers, signed_headers, content_sha256)
  local string_to_sign = get_string_to_sign(datetime, credential_scope, canonical_request)
  local signature = get_signature(aws_region, aws_secret_access_key, date, string_to_sign)
  local authorization = get_authorization(aws_access_key_id, credential_scope, signed_headers, signature)
  req_set_header("Authorization", authorization)
end

return _M
