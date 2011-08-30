class PagesController < ApplicationController
  def home
    @collections = ApiDocCollection.roots
  end

  def community
  end
end
