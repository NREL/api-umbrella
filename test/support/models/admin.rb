class Admin < ApplicationRecord
  has_and_belongs_to_many :groups, -> { order(:name) }, :class_name => "AdminGroup"

  def id=(id)
    prev_id = self[:id]
    self[:id] = id

    # Re-encrypt if the ID (used for the auth data) changes.
    if prev_id && prev_id != id && @unencrypted_authentication_token
      self.authentication_token = @unencrypted_authentication_token
    end
  end

  def authentication_token=(value)
    @unencrypted_authentication_token = value

    # Ensure the record ID is set (it may not be on initial create), since we
    # need the ID for the auth data.
    self.id ||= SecureRandom.uuid

    self.authentication_token_hash = OpenSSL::HMAC.hexdigest("sha256", $config["secret_key"], value)
    self.authentication_token_encrypted_iv = SecureRandom.hex(6)
    self.authentication_token_encrypted = Base64.strict_encode64(Encryptor.encrypt({
      :value => value,
      :iv => self.authentication_token_encrypted_iv,
      :key => Digest::SHA256.digest($config["secret_key"]),
      :auth_data => self.id,
    }))
  end

  def authentication_token
    Encryptor.decrypt({
      :value => Base64.strict_decode64(self.authentication_token_encrypted),
      :iv => self.authentication_token_encrypted_iv,
      :key => Digest::SHA256.digest($config["secret_key"]),
      :auth_data => self.id,
    })
  end

  def serializable_hash(options = nil)
    options ||= {}
    options.merge!({
      :methods => [
        :group_ids,
      ],
    })
    super(options)
  end
end
