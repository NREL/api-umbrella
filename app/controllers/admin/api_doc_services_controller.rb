class Admin::ApiDocServicesController < Admin::BaseController
  set_tab :documentation
  cache_sweeper :api_doc_service_sweeper, :only => [:create, :update, :destroy]

  def index
    @services = ApiDocService.asc(:url_path).page(params[:page])

    add_crumb "Web Services"
  end

  def new
    @service = ApiDocService.new

    add_crumb "Web Services", admin_api_doc_services_path
    add_crumb "Add New Service"
  end

  def edit
    @service = ApiDocService.find(params[:id])

    add_crumb "Web Services", admin_api_doc_services_path
    add_crumb "Edit Service"
  end

  def create
    @service = ApiDocService.new(params[:api_doc_service])
    @service.save!
    redirect_to(admin_api_doc_services_path)
  rescue Mongoid::Errors::Validations
    render(:action => "new")
  end

  def update
    @service = ApiDocService.find(params[:id])
    @service.update_attributes!(params[:api_doc_service])
    redirect_to(admin_api_doc_services_path)
  rescue Mongoid::Errors::Validations
    render(:action => "edit")
  end

  def destroy
    @service = ApiDocService.find(params[:id])
    @service.destroy
    redirect_to(admin_api_doc_services_path)
  end

end
