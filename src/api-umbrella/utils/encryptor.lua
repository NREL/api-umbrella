-- Encrypt and decrypt values using AES-256-GCM.
--
-- We're preferring GCM here to provide authenticated encryption, eliminate
-- need for manual padding, and guard against oracle padding attacks.
--
-- The "secret_key" config value defined in api-umbrella.yml is used as the
-- encryption key. When this key changes, previously encrypted data will need
-- to be re-encrypted.

local resty_sha256 = require "resty.sha256"
local aes = require "resty.nettle.aes"
local random_token = require "api-umbrella.utils.random_token"

local auth_tag_length = 16
local decode_base64 = ngx.decode_base64
local encode_base64 = ngx.encode_base64

-- The encryption key always needs to be 256 bits long, so for the actual
-- encryption key, use a sha256 result of the secret defined in the config (so
-- the secret can be of other lengths).
local secret_key = assert(config["secret_key"])
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

  -- Separate out the auth tag from the cipher text from the end of the value.
  local encrypted_cipher_text = string.sub(binary, 1, -1 - auth_tag_length)
  local encrypted_auth_tag = string.sub(binary, 0 - auth_tag_length, -1)

  local encryptor = assert(aes.new(secret_key_sha256, "gcm", iv, auth_data))
  local plain_text, auth_tag = encryptor:decrypt(encrypted_cipher_text)

  -- Validate the auth tag.
  if auth_tag ~= encrypted_auth_tag then
    ngx.log(ngx.ERR, "Failed to decrypt value. Is the current encryption_key the same as the one used to originally encrypt the value?")
    return nil, "decrypt failed"
  end

  return plain_text
end

return _M
