class Admin < ApplicationRecord
  has_and_belongs_to_many :groups, :class_name => "AdminGroup"

  def authentication_token=(value)
    self.authentication_token_hash = OpenSSL::HMAC.hexdigest("sha256", $config["secret_key"], value)
    self.authentication_token_encrypted_iv = SecureRandom.hex(6)
    self.authentication_token_encrypted = Base64.strict_encode64(Encryptor.encrypt(:value => value, :iv => self.authentication_token_encrypted_iv, :key => Digest::SHA256.digest($config["secret_key"])))
  end

  def authentication_token
    Encryptor.decrypt(:value => Base64.strict_decode64(self.authentication_token_encrypted), :iv => self.authentication_token_encrypted_iv, :key => Digest::SHA256.digest($config["secret_key"]))
  end
end
