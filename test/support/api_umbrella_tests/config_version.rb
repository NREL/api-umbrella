module ApiUmbrellaTests
  class ConfigVersion
    def self.client
      @client ||= Mongo::Client.new($config["mongodb"]["url"])
    end

    def self.delete_all
      self.client[:config_versions].delete_many
    end

    def self.get
      self.client[:config_versions].find.sort(:version => -1).limit(1).first
    end

    def self.insert(config_version)
      config_version = config_version.dup
      config_version.delete("_id")
      config_version["version"] = Time.now
      self.client[:config_versions].insert_one(config_version)
      self.wait_until_live(config_version)
    end

    def self.insert_default
      self.insert({
        "config" => {
          "apis" => [
            {
              "_id" => "example",
              "frontend_host" => "127.0.0.1",
              "backend_host" => "127.0.0.1",
              "servers" => [
                { "host" => "127.0.0.1", "port" => 9444 },
              ],
              "url_matches" => [
                { "frontend_prefix" => "/api/", "backend_prefix" => "/" },
              ],
            },
          ],
        },
      })
    end

    def self.wait_until_live(config_version)
      version = (config_version["version"].to_f * 1000).to_i
      ApiUmbrellaTests::Process.wait_for_config_version("db_config_version", version)
    end
  end
end
