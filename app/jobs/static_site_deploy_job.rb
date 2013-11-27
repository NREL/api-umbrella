module ApiUmbrella
  class StaticSiteDeployJob
    def initialize(payload)
      @payload = payload

      @git_url = "#{@payload["repository"]["url"]}.git"
      @branch = @payload["ref"].split("/").last

      @checkout_dir = File.join(Rails.root, "tmp/static_site_checkout")
    end

    def perform
      # Wipe out the Bundler environment for the Rails app so it doesn't step
      # on the bundle for the static site.
      Bundler.with_clean_env do
        script_path = File.join(Rails.root, "script/static_site_deploy")
        Delayed::Worker.logger.info("Running deploy script: #{script_path}")

        ChildProcess.posix_spawn = true
        process = ChildProcess.build(script_path)

        @out = Tempfile.new("static_site_deploy")
        @out.sync = true
        process.io.stdout = process.io.stderr = @out

        process.environment["GIT_URL"] = @git_url
        process.environment["BRANCH"] = @branch
        process.environment["CHECKOUT_DIR"] = @checkout_dir
        process.environment["DEPLOY_ENV"] = ConfigSettings.deploy_env || Rails.env

        #process.environment["BUNDLE_GEMFILE"] = nil

        process.start

        begin
          process.poll_for_exit(5.minutes)
        rescue ChildProcess::TimeoutError
          process.stop
        end

        if(@out)
          @out.rewind
          Delayed::Worker.logger.error("\n#{@out.read}\n")
        end

        if(process.exit_code != 0)
          raise "Deployment process failed. Script exit code: #{process.exit_code}"
        end
      end
    end

    def error(job, exception)
      Delayed::Worker.logger.error("Static site deploy failed: #{job.id}\n\n#{exception}\n")

      if(@out)
        @out.rewind
        Delayed::Worker.logger.error("\n#{@out.read}\n")
      end
    end
  end
end
