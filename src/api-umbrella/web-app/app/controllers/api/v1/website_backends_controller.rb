class Api::V1::WebsiteBackendsController < Api::V1::BaseController
  respond_to :json

  skip_after_action :verify_authorized, :only => [:index]
  after_action :verify_policy_scoped, :only => [:index]

  def index
    @website_backends = policy_scope(WebsiteBackend).order_by(datatables_sort_array)

    if(params[:order].blank?)
      @website_backends = @website_backends.order_by(:name.asc)
    end

    if(params[:start].present?)
      @website_backends = @website_backends.skip(params[:start].to_i)
    end

    if(params[:length].present?)
      @website_backends = @website_backends.limit(params[:length].to_i)
    end

    if(params[:search] && params[:search][:value].present?)
      @website_backends = @website_backends.or([
        { :frontend_host => /#{Regexp.escape(params[:search][:value])}/i },
        { :server_host => /#{Regexp.escape(params[:search][:value])}/i },
        { :_id => params[:search][:value].downcase },
      ])
    end
  end

  def show
    @website_backend = WebsiteBackend.find(params[:id])
    authorize(@website_backend)
  end

  def create
    @website_backend = WebsiteBackend.new
    save!
    respond_with(:api_v1, @website_backend, :root => "website_backend")
  end

  def update
    @website_backend = WebsiteBackend.find(params[:id])
    save!
    respond_with(:api_v1, @website_backend, :root => "website_backend")
  end

  def destroy
    @website_backend = WebsiteBackend.find(params[:id])
    authorize(@website_backend)
    @website_backend.destroy
    respond_with(:api_v1, @website_backend, :root => "website_backend")
  end

  private

  def save!
    authorize(@website_backend) unless(@website_backend.new_record?)
    @website_backend.assign_attributes(website_backend_params)
    authorize(@website_backend)
    @website_backend.save
  end

  def website_backend_params
    params.require(:website_backend).permit([
      :frontend_host,
      :backend_protocol,
      :server_host,
      :server_port,
    ])
  rescue => e
    logger.error("Parameters error: #{e}")
    ActionController::Parameters.new({}).permit!
  end
end
