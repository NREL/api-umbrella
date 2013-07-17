# Set the servers for this stage.
role :app, "ec2-23-23-57-185.compute-1.amazonaws.com", "ec2-107-20-100-29.compute-1.amazonaws.com"
role :web, "ec2-23-23-57-185.compute-1.amazonaws.com", "ec2-107-20-100-29.compute-1.amazonaws.com"

# Set the base path for deployment.
set :deploy_to_base, "/srv"

# Set the accessible web domain for this site.
set :base_domain, "api.data.gov"

# Production-ready deployments should exclude git data.
set :copy_exclude, [".git"]

# Set the Rails environment.
set :rails_env, "production"

set :user, "root"
ssh_options[:keys] = ["/vagrant/workspace/aws_nmuerdter.pem"]

set :ssl_cert_pem, "/etc/ssl/certs/vagrant.pem"
