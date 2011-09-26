class PagesController < ApplicationController
  def home
    @collections = ApiDocCollection.roots

    set_tab :home
  end

  def community
  end
end
