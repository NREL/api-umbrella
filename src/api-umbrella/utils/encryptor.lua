local resty_sha256 = require "resty.sha256"
local aes = require "resty.nettle.aes"
local random_token = require "api-umbrella.utils.random_token"

local encode_base64 = ngx.encode_base64
local decode_base64 = ngx.decode_base64

local auth_tag_length = 16

local secret_key = config["web"]["rails_secret_token"]
local sha256 = resty_sha256:new()
sha256:update(secret_key)
local secret_key_sha256 = sha256:final()

local _M = {}

function _M.encrypt(value, auth_data)
  local iv = random_token(12)
  local encryptor = assert(aes.new(secret_key_sha256, "gcm", iv, auth_data))
  local cipher_text, auth_tag = encryptor:encrypt(value)
  local encoded = encode_base64(cipher_text .. auth_tag)

  return encoded, iv
end

function _M.decrypt(encrypted_value, iv, auth_data)
  local binary = decode_base64(encrypted_value)
  local encrypted_cipher_text = string.sub(binary, 1, -1 - auth_tag_length)
  local encrypted_auth_tag = string.sub(binary, 0 - auth_tag_length, -1)
  local encryptor = assert(aes.new(secret_key_sha256, "gcm", iv, auth_data))
  local plain_text, auth_tag = encryptor:decrypt(encrypted_cipher_text)
  if auth_tag ~= encrypted_auth_tag then
    return
  end

  return plain_text
end

return _M
