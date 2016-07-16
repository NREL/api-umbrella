module ApiUmbrellaTests
  module Setup
    @@semaphore = Mutex.new
    @@setup_complete = false

    def setup_server
      @@semaphore.synchronize do
        unless @@setup_complete
          ApiUmbrellaTests::ConfigVersion.delete_all
          ApiUmbrellaTests::ConfigVersion.insert_default

          ApiUmbrellaTests::User.delete_all
          user = ApiUmbrellaTests::User.insert

          @@http_options = {
            :headers => {
              "X-Api-Key" => user["api_key"],
            },
          }

          @@setup_complete = true
        end
      end
    end

    def prepend_api_backends(apis)
      apis.each_with_index do |apis, index|
        apis["_id"] = "#{self.location}-#{index}"
      end

      @@semaphore.synchronize do
        config_version = ApiUmbrellaTests::ConfigVersion.get
        config_version["config"]["apis"] = apis + config_version["config"]["apis"]
        ApiUmbrellaTests::ConfigVersion.insert(config_version)
      end

      yield
    ensure
      @@semaphore.synchronize do
        api_ids = apis.map { |api| api["_id"] }
        config_version = ApiUmbrellaTests::ConfigVersion.get
        config_version["config"]["apis"].reject! { |api| api_ids.include?(api["_id"]) }
        ApiUmbrellaTests::ConfigVersion.insert(config_version)
      end
    end

    def unique_url_prefix
      @unique_url_prefix ||= "#{self.location.gsub(/[^\w]/, "-")}"
    end
  end
end
