module ApiUmbrellaTests
  class User
    @@api_key_sequence = 0

    def self.client
      @client ||= Mongo::Client.new($config["mongodb"]["url"])
    end

    def self.delete_all
      self.client[:api_users].delete_many
    end

    def self.insert
      @@api_key_sequence += 1
      user = {
        "api_key" => "TESTING_KEY_#{@@api_key_sequence.to_s.rjust(5, "0")}",
        "settings" => {
          "rate_limit_mode" => "unlimited",
        },
      }

      client[:api_users].update_one({
        :_id => SecureRandom.uuid,
      }, {
        "$set" => user,
        "$currentDate" => {
          "ts" => { "$type" => "timestamp" },
        },
      }, {
        :upsert => true,
      })

      user
    end
  end
end
