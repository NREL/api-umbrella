class PagesController < ApplicationController
  def home
    @collections = ApiDocCollection.roots

    set_tab :home
  end

  def community
    set_tab :community
    add_crumb "Community"
  end
end
