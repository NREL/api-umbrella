class ContactsController < ApplicationController
  add_crumb "Contact Us", ""

  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(params[:contact])

    if @contact.deliver
      redirect_to root_path, :notice => "Thanks for sending your message. We'll be in touch."
    else
      render :new
    end
  end
end
