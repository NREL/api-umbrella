class Api::V1::ApisController < Api::V1::BaseController
  respond_to :json

  skip_after_action :verify_authorized, :only => [:index]
  after_action :verify_policy_scoped, :only => [:index]

  def index
    @apis = policy_scope(Api).order_by(datatables_sort_array)

    if(params[:start].present?)
      @apis = @apis.skip(params["start"].to_i)
    end

    if(params[:length].present?)
      @apis = @apis.limit(params["length"].to_i)
    end

    if(params["search"] && params["search"]["value"].present?)
      @apis = @apis.or([
        { :name => /#{Regexp.escape(params["search"]["value"])}/i },
        { :frontend_host => /#{Regexp.escape(params["search"]["value"])}/i },
        { :backend_host => /#{Regexp.escape(params["search"]["value"])}/i },
        { :"url_matches.backend_prefix" => /#{Regexp.escape(params["search"]["value"])}/i },
        { :"url_matches.frontend_prefix" => /#{Regexp.escape(params["search"]["value"])}/i },
        { :"servers.host" => /#{Regexp.escape(params["search"]["value"])}/i },
        { :_id => /#{Regexp.escape(params["search"]["value"])}/i },
      ])
    end

    @apis_count = @apis.count
    @apis = @apis.to_a.select { |api| Pundit.policy!(pundit_user, api).show? }
  end

  def show
    @api = Api.find(params[:id])
    authorize(@api)
    respond_with(:api_v1, @api, :root => "api")
  end

  def create
    @api = Api.new
    save!
    respond_with(:api_v1, @api, :root => "api")
  end

  def update
    @api = Api.find(params[:id])
    save!
    respond_with(:api_v1, @api, :root => "api")
  end

  def destroy
    @api = Api.find(params[:id])
    authorize(@api)
    @api.destroy
    respond_with(:api_v1, @api, :root => "api")
  end

  def move_after
    @api = Api.find(params[:id])
    authorize(@api)

    if(params[:move_after_id].present?)
      after_api = Api.find(params[:move_after_id])
      if(after_api)
        authorize(after_api)
        @api.move_after(after_api)
      end
    else
      @api.move_to_beginning
    end

    @api.save
    respond_with(:api_v1, @api, :root => "api")
  end

  private

  def save!
    authorize(@api) unless(@api.new_record?)
    @api.assign_nested_attributes(api_params)
    authorize(@api)

    @api.save
  end

  def api_params
    settings_permitted = [
      :id,
      :append_query_string,
      :http_basic_auth,
      :require_https,
      :require_https_transition_start_at,
      :disable_api_key,
      :api_key_verification_level,
      :api_key_verification_transition_start_at,
      :rate_limit_mode,
      :anonymous_rate_limit_behavior,
      :authenticated_rate_limit_behavior,
      :pass_api_key_header,
      :pass_api_key_query_param,
      :rate_limits,
      :required_roles,
      :required_roles_override,
      :headers,
      :headers_string,
      :default_response_headers,
      :default_response_headers_string,
      :override_response_headers,
      :override_response_headers_string,
      {
        :required_roles => [],
        :error_templates => [
          :json,
          :xml,
          :csv,
        ],
        :default_response_headers => [
          :id,
          :key,
          :value,
        ],
        :override_response_headers => [
          :id,
          :key,
          :value,
        ],
        :headers => [
          :id,
          :key,
          :value,
        ],
        :error_data_yaml_strings => [
          :common,
          :api_key_missing,
          :api_key_invalid,
          :api_key_disabled,
          :api_key_unauthorized,
          :over_rate_limit,
          :https_required,
        ],
        :rate_limits => [
          :id,
          :duration,
          :limit_by,
          :limit,
          :response_headers,
        ],
      },
    ]

    params.require(:api).permit([
      :name,
      :sort_order,
      :backend_protocol,
      :frontend_host,
      :backend_host,
      :balance_algorithm,
      :servers,
      :url_matches,
      :sub_settings,
      :rewrites,
      {
        :settings => settings_permitted,
        :servers => [
          :id,
          :host,
          :port,
        ],
        :url_matches => [
          :id,
          :frontend_prefix,
          :backend_prefix,
        ],
        :sub_settings => [
          :id,
          :http_method,
          :regex,
          {
            :settings => settings_permitted,
          },
        ],
        :rewrites => [
          :id,
          :matcher_type,
          :http_method,
          :frontend_matcher,
          :backend_replacement,
        ],
      },
    ])
  rescue => e
    logger.error("Parameters error: #{e}")
    ActionController::Parameters.new({}).permit!
  end
end
