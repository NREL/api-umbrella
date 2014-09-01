class Api::V1::ConfigController < Api::V1::BaseController
  skip_after_filter :verify_authorized, :only => [:pending]

  def pending
    @changes = ConfigVersion.pending_changes(pundit_user)
  end

  def publish
  end
end
