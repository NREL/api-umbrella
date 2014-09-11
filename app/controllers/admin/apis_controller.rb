class Admin::ApisController < Admin::BaseController
  respond_to :json

  def move_to
    @api = Api.find(params[:id])
    @api.move_to(params[:move_to].to_i)
    @api.save
    respond_with(:admin, @api, :root => "api")
  end
end
