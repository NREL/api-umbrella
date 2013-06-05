class Admin::ApiDocCollectionsController < Admin::BaseController
  set_tab :documentation
  add_crumb("API Documentation") { }

  def index
    @collections = ApiDocCollection.roots

    add_crumb "Collections"
  end

  def new
    @collection = ApiDocCollection.new

    add_crumb "Collections", admin_api_doc_collections_path
    add_crumb "Add New Collection"
  end

  def edit
    @collection = ApiDocCollection.find(params[:id])

    add_crumb "Collections", admin_api_doc_collections_path
    add_crumb "Edit Collection"
  end

  def create
    @collection = ApiDocCollection.new(params[:api_doc_collection])
    @collection.save!
    redirect_to(admin_api_doc_collections_path)
  rescue Mongoid::Errors::Validations
    render(:action => "new")
  end

  def update
    @collection = ApiDocCollection.find(params[:id])
    @collection.update_attributes!(params[:api_doc_collection])
    redirect_to(admin_api_doc_collections_path)
  rescue Mongoid::Errors::Validations
    render(:action => "edit")
  end

  def destroy
    @collection = ApiDocCollection.find(params[:id])
    @collection.destroy
    redirect_to(admin_api_doc_collections_path)
  end
end
