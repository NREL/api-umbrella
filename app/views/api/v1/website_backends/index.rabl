object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @website_backends.count }
node(:recordsFiltered) { @website_backends.count }
node :data do
  @website_backends.map do |website_backend|
    website_backend.serializable_hash
  end
end
