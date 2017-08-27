class ApiUser < ApplicationRecord
  has_one :settings, :class_name => "ApiUserSettings"#, :foreign_key => "api_user_settings_id"

  def api_key=(value)
    self.api_key_hash = OpenSSL::HMAC.hexdigest("sha256", $config["secret_key"], value)
    self.api_key_encrypted_iv = SecureRandom.hex(6)
    self.api_key_encrypted = Base64.strict_encode64(Encryptor.encrypt(:value => value, :iv => self.api_key_encrypted_iv, :key => Digest::SHA256.digest($config["secret_key"])))
    self.api_key_prefix = value[1, 10]
  end

  def api_key
    Encryptor.decrypt(:value => Base64.strict_decode64(self.api_key_encrypted), :iv => self.api_key_encrypted_iv, :key => Digest::SHA256.digest($config["secret_key"]))
  end

  def api_key_preview
    "#{self.api_key_prefix[1, 6]}..."
  end
end
