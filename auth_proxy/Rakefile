require "rake"

require "yard"
YARD::Rake::YardocTask.new do |t|
  t.files = ["lib/**/*.rb"]
  t.options = [
    "--protected",
    "--private",
    "--output-dir", "/srv/developer/cttsdev-svc/docs_server/current/public/developer-auth_proxy",
    "--debug",
  ]
end
