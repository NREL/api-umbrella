class Api::V1::AdminsController < Api::V1::BaseController
  respond_to :json

  skip_after_action :verify_authorized, :only => [:index]
  after_action :verify_policy_scoped, :only => [:index]

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
        { :name => /#{Regexp.escape(params["search"]["value"])}/i },
        { :email => /#{Regexp.escape(params["search"]["value"])}/i },
        { :username => /#{Regexp.escape(params["search"]["value"])}/i },
        { :_id => params[:search][:value].downcase },
      ])
    end

    @admins_count = @admins.count
    @admins = @admins.to_a.select { |admin| Pundit.policy!(pundit_user, admin).show? }
    self.respond_to_datatables(@admins, "admins #{Time.now.utc.strftime("%b %-e %Y")}")
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
        if(send_invite_email)
          @admin.send_invite_instructions
        end

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
        if(!@admin.current_sign_in_at && send_invite_email)
          @admin.send_invite_instructions
        end

        # If a user is updating themselves, make sure they remain signed in.
        # This eliminates the current user getting logged out if they change
        # their password.
        if(@admin.id == current_admin.id)
          bypass_sign_in(@admin, :scope => :admin)
        end

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
    if(@admin.id && @admin.id == current_admin.id)
      @admin.assign_with_password(admin_params)
    else
      @admin.assign_without_password(admin_params)
    end
    authorize(@admin)
  end

  def admin_params
    params.require(:admin).permit([
      :username,
      :password,
      :password_confirmation,
      :current_password,
      :email,
      :name,
      :notes,
      :superuser,
      :group_ids,
      { :group_ids => [] },
    ])
  rescue => e
    logger.error("Parameters error: #{e}")
    ActionController::Parameters.new({}).permit!
  end

  def send_invite_email
    send_invite_email = (params[:options] && params[:options][:send_invite_email].to_s == "true")

    # For the admin tool, it's easier to have this attribute on the user
    # model, rather than options.
    if(!send_invite_email && params[:admin] && params[:admin][:send_invite_email].to_s == "true")
      send_invite_email = true
    end

    send_invite_email
  end
end
