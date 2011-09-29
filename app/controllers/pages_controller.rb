class PagesController < ApplicationController
  def home
    @collections = ApiDocCollection.roots

    set_tab :home
  end

  def community
    set_tab :community
    add_crumb "Community"
  end

  def api_key
    set_tab :documentation
    add_crumb "Documentation", doc_path
    add_crumb "API Key Usage"
  end

  def errors
    set_tab :documentation
    add_crumb "Documentation", doc_path
    add_crumb "General Web Service Errors"
  end

  def rate_limits
    set_tab :documentation
    add_crumb "Documentation", doc_path
    add_crumb "Web Service Rate Limits"
  end
end
