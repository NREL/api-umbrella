class ContactsController < ApplicationController
  add_crumb "Contact Us", ""

  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(params[:contact])

    if @contact.deliver
      flash[:info] = "Thanks for sending your message. We'll be in touch."
      redirect_to root_path
    else
      render :new
    end
  end
end
