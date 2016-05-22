class Api::V1::AdminsController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:index]

  def index
    @admins = policy_scope(Admin).order_by(datatables_sort_array)

    if(params[:start].present?)
      @admins = @admins.skip(params["start"].to_i)
    end

    if(params[:length].present?)
      @admins = @admins.limit(params["length"].to_i)
    end

    if(params["search"] && params["search"]["value"].present?)
      @admins = @admins.or([
        { :first_name => /#{Regexp.escape(params["search"]["value"])}/i },
        { :last_name => /#{Regexp.escape(params["search"]["value"])}/i },
        { :email => /#{Regexp.escape(params["search"]["value"])}/i },
        { :username => /#{Regexp.escape(params["search"]["value"])}/i },
        { :authentication_token => /#{Regexp.escape(params["search"]["value"])}/i },
        { :_id => /#{Regexp.escape(params["search"]["value"])}/i },
      ])
    end

    @admins_count = @admins.count
    @admins = @admins.to_a.select { |admin| Pundit.policy!(pundit_user, admin).show? }
    self.respond_to_datatables(@admins, "admins #{Time.now.strftime("%b %-e %Y")}")
  end

  def show
    @admin = Admin.find(params[:id])
    authorize(@admin)
  end

  def create
    @admin = Admin.new
    save!

    respond_to do |format|
      if(@admin.save)
        format.json { render("show", :status => :created, :location => api_v1_admin_url(@admin)) }
      else
        format.json { render(:json => errors_response(@admin), :status => :unprocessable_entity) }
      end
    end
  end

  def update
    @admin = Admin.find(params[:id])
    save!

    respond_to do |format|
      if(@admin.save)
        format.json { render("show", :status => :ok, :location => api_v1_admin_url(@admin)) }
      else
        format.json { render(:json => errors_response(@admin), :status => :unprocessable_entity) }
      end
    end
  end

  def destroy
    @admin = Admin.find(params[:id])
    authorize(@admin)
    @admin.destroy
    respond_with(:api_v1, @admin, :root => "admin")
  end

  private

  def save!
    authorize(@admin) unless(@admin.new_record?)
    @admin.assign_attributes(params[:admin], :as => :admin)
    authorize(@admin)
    @admin.save
  end
end
