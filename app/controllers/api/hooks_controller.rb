require "static_site_deploy_job"

class Api::HooksController < ApplicationController
  def publish_static_site
    @payload = MultiJson.load(params[:payload])

    job = ApiUmbrella::StaticSiteDeployJob.new(@payload)
    Delayed::Job.enqueue(job, :queue => "api_umbrella_static_site_deployer")

    head :ok
  end
end
