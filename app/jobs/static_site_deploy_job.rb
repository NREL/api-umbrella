module ApiUmbrella
  class StaticSiteDeployJob
    def initialize(payload)
      @payload = payload

      @git_url = "#{@payload["repository"]["url"]}.git"
      @git_commit = @payload["after"]
      @branch = @payload["ref"].split("/").last

      @checkout_dir = File.join(Rails.root, "tmp/static_site_checkout")
    end

    def perform
      # Only auto-deploy master.
      if(@branch != "master")
        Delayed::Worker.logger.info("Skipping deployment (branch not master - #{@branch}")
        return
      end

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
        process.environment["GIT_COMMIT"] = @git_commit
        process.environment["CHECKOUT_DIR"] = @checkout_dir
        process.environment["DEPLOY_ENV"] = ConfigSettings.deploy_env || Rails.env

        process.start

        begin
          process.poll_for_exit(10.minutes)
        rescue ChildProcess::TimeoutError => error
          process.stop
          raise error
        end

        if(process.exit_code != 0)
          if(@out)
            @out.rewind
            Delayed::Worker.logger.error("\n#{@out.read}\n")
          end

          raise "Deployment process failed. Script exit code: #{process.exit_code}"
        end
      end
    end

    def error(job, exception)
      Delayed::Worker.logger.error("Static site deploy failed: #{job.id}: #{exception}")

      notify = []
      if(@payload["pusher"] && @payload["pusher"]["email"].present?)
        notify << @payload["pusher"]["email"]
      end

      if(@payload["head_commit"] && @payload["head_commit"]["author"] && @payload["head_commit"]["author"]["email"].present?)
        notify << @payload["head_commit"]["author"]["email"]
      end

      notify.compact!
    end
  end
end
