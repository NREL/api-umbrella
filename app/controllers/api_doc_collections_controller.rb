class ApiDocCollectionsController < ApplicationController
  set_tab :documentation
  add_crumb "Documentation", :doc_path

  def index
    @collections = ApiDocCollection.roots
  end

  def show
    @collection = ApiDocCollection.where(:url_path => request.path.gsub(/^#{ActionController::Base.config.relative_url_root.to_s}\/?/, "/")).first
    @child_collections = @collection.children
    @child_services = @collection.api_doc_services.asc(:http_method, :path)
    raise Mongoid::Errors::DocumentNotFound.new(ApiDocCollection, request.path) unless(@collection)

    @collection.sorted_ancestors.each do |ancestor|
      add_crumb ancestor.title, ancestor.url_path
    end

    add_crumb @collection.title
  end
end
