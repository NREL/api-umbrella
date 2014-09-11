object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @total }
node(:recordsFiltered) { @total }
node(:data) { @user_data }
