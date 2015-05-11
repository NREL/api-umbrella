object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @admins_count }
node(:recordsFiltered) { @admins_count }
node(:data) { @admins }
