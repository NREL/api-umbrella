require "support/api_umbrella_test_helpers/process"

module ApiUmbrellaTestHelpers
  module Downloads
    DOWNLOADS_ROOT = File.join(ApiUmbrellaTestHelpers::Process::TEST_RUN_ROOT, "capybara-downloads")

    def setup
      super

      if(self.class.test_order == :parallel)
        raise "`ApiUmbrellaTestHelpers::Downloads` cannot be called with `parallelize_me!` in the same class. Since downloads are tracked globally, it cannot be used with parallel tests."
      end

      clear_downloads
    end

    def teardown
      clear_downloads
      super
    end

    def download_paths
      Dir[File.join(DOWNLOADS_ROOT, "*")]
    end

    def download_path
      wait_for_download
      download_paths.first
    end

    def download_file
      File.open(download_path)
    end

    def wait_for_download
      Timeout.timeout(10) do
        sleep 0.1 until downloaded?
      end
    end

    def downloaded?
      !downloading? && download_paths.any?
    end

    def downloading?
      download_paths.grep(/\.(part|crdownload)$/).any?
    end

    def clear_downloads
      FileUtils.rm_rf(DOWNLOADS_ROOT)
      FileUtils.mkdir_p(DOWNLOADS_ROOT)
    end
  end
end
