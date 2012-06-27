class ApiDocServicesController < ApplicationController
  set_tab :documentation
  add_crumb "Documentation", :doc_path

  caches_action :show

  def show
    @service = ApiDocService.where(:url_path => request.path.gsub(/^#{ActionController::Base.config.relative_url_root}\/?/, "/")).first
    raise Mongoid::Errors::DocumentNotFound.new(ApiDocService, request.path) unless(@service)

    if @service.api_doc_collection
      @service.api_doc_collection.sorted_ancestors_and_self.each do |ancestor|
        add_crumb ancestor.title, ancestor.url_path
      end
    end

    add_crumb @service.title
  end
end
