class ApiDocServicesController < ApplicationController
  set_tab :documentation
  add_crumb "Documentation", :doc_path

  def show
    @service = ApiDocService.where(:url_path => request.path).first
    raise Mongoid::Errors::DocumentNotFound.new(ApiDocService, request.path) unless(@service)

    @service.api_doc_collection.sorted_ancestors_and_self.each do |ancestor|
      add_crumb ancestor.title, ancestor.url_path
    end

    add_crumb @service.title
  end
end
