require "static_site_deploy_job"

class Api::HooksController < ApplicationController
  def publish_static_site
    roles = request.headers["X-Api-Roles"].to_s.split(",")
    unless(roles.include?("api_umbrella_static_site_deploy"))
      logger.warn("API user did not have the 'api_umbrella_static_site_deploy' role")
      head :forbidden
      return false
    end

    @payload = MultiJson.load(params[:payload])

    job = ApiUmbrella::StaticSiteDeployJob.new(@payload)
    Delayed::Job.enqueue(job, :queue => "api_umbrella_static_site_deployer")

    head :ok
  end
end
