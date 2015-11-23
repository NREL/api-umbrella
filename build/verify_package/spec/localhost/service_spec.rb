require "spec_helper"

require "multi_json"
require "rest-client"
require "yaml"

MultiJson.use(:ok_json)

describe "api-umbrella" do
  it "installs the package" do
    expect(package("api-umbrella")).to be_installed
  end

  it "runs the service" do
    expect(service("api-umbrella")).to be_running.under(:init)
  end

  it "enables the service" do
    expect(service("api-umbrella")).to be_enabled
  end

  it "reports green from the health api endpoint" do
    response = RestClient::Request.execute(:method => :get, :url => "https://localhost/api-umbrella/v1/health.json", :verify_ssl => false)
    data = MultiJson.load(response.body)
    expect(data["status"]).to eql("green")
  end

  it "reported bin version matches package build version" do
    bin_version = command("api-umbrella version").stdout.strip
    package_version = package("api-umbrella").version

    expect(bin_version).to match(/^[0-9]+\.[0-9]+\.[0-9]+(-\w+)?$/)
    expect(bin_version.gsub(/-.+$/, "")).to eql(package_version.version.gsub(/-.+$/, ""))
  end

  it "reports the correct status regardless of HOME environment variable" do
    # This accounts for HOME being different under Ubuntu's boot than when
    # running "sudo /etc/init.d/api-umbrella *"
    # See: https://github.com/NREL/api-umbrella/issues/89
    expect(command("env HOME=/ /etc/init.d/api-umbrella status").stdout).to include("is running")
    expect(command("env HOME=/foo /etc/init.d/api-umbrella status").stdout).to include("is running")
    expect(command("env HOME=/root /etc/init.d/api-umbrella status").stdout).to include("is running")
  end

  it "listens on port 80" do
    expect(port(80)).to be_listening.on("0.0.0.0").with("tcp")
  end

  it "listens on port 443" do
    expect(port(443)).to be_listening.on("0.0.0.0").with("tcp")
  end

  it "signup page loads" do
    response = RestClient::Request.execute(:method => :get, :url => "https://localhost/signup/", :verify_ssl => false)
    expect(response).to include("API Key Signup")
  end

  it "admin login page loads" do
    response = RestClient::Request.execute(:method => :get, :url => "https://localhost/admin/login", :verify_ssl => false)
    expect(response).to include("Login with Persona")
  end

  it "gatekeeper blocks key-less requests" do
    expect do
      RestClient::Request.execute(:method => :get, :url => "https://localhost/api-umbrella/v1/test.json", :verify_ssl => false)
    end.to raise_error do |error|
      expect(error).to be_a(RestClient::Forbidden)
      expect(error.response).to include("API_KEY_MISSING")
    end
  end

  it "gatekeeper blocks invalid key requests" do
    expect do
      response = RestClient::Request.execute(:method => :get, :url => "https://localhost/api-umbrella/v1/test.json?api_key=INVALID_KEY", :verify_ssl => false)
    end.to raise_error do |error|
      expect(error).to be_a(RestClient::Forbidden)
      expect(error.response).to include("API_KEY_INVALID")
    end
  end

  it "fails immediately when startup script is called as an unauthorized user" do
    expect(command("sudo -u api-umbrella-deploy /etc/init.d/api-umbrella start").stdout).to include("Must be started with super-user privileges")
    expect($?.to_i).not_to eql(0)
  end

  it "allows the deploy user to execute api-umbrella commands as root" do
    expect(command("sudo -u api-umbrella-deploy sudo -n api-umbrella status").stdout).to include("is running")
    expect(command("sudo -u api-umbrella-deploy sudo -n /etc/init.d/api-umbrella status").stdout).to include("is running")
  end

  it "can be stopped and started again" do
    # Stop
    command_result = command("/etc/init.d/api-umbrella stop")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stderr).to eql("")

    # Check status
    expect(service("api-umbrella")).to_not be_running.under(:init)
    expect(command("/etc/init.d/api-umbrella status").stdout).to include("is stopped")

    # Start again
    command_result = command("/etc/init.d/api-umbrella start")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stderr).to eql("")
    expect(service("api-umbrella")).to be_running.under(:init)

    # Wait for API Umbrella to become fully started and health again, to ensure
    # subsequent tests don't fail.
    expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)
  end

  it "includes a success message in the init script output" do
    # We want to check to make sure the standard init.d success message is
    # being printed, but the exact message varies depending on the distro (it
    # should either be "OK" or "done"). We must pass this through socat to
    # capture pty output to account for Debian's default init helpers
    # repositioning the output to print at the beginning of the line.
    command_result = command(%(socat -u 'exec:"/etc/init.d/api-umbrella stop",pty' -))
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stdout).to match(/\b(OK|done)\b/i)

    command_result = command(%(socat -u 'exec:"/etc/init.d/api-umbrella start",pty' -))
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stdout).to match(/\b(OK|done)\b/i)

    expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)
  end

  it "symlinks the main api-umbrella binary" do
    subject = file("/usr/bin/api-umbrella")
    expect(subject).to be_symlink
    expect(subject).to be_owned_by("root")
    expect(subject).to be_grouped_into("root")
    expect(subject).to be_linked_to("../../opt/api-umbrella/bin/api-umbrella")
  end

  it "installs a init.d file" do
    subject = file("/etc/init.d/api-umbrella")
    expect(subject).to be_file
    expect(subject).to be_mode(755)
    expect(subject).to be_owned_by("root")
    expect(subject).to be_grouped_into("root")
  end

  it "installs a logrotate.d file" do
    subject = file("/etc/logrotate.d/api-umbrella")
    expect(subject).to be_file
    expect(subject).to be_mode(644)
    expect(subject).to be_owned_by("root")
    expect(subject).to be_grouped_into("root")
  end

  it "installs a sudoers.d file" do
    subject = file("/etc/sudoers.d/api-umbrella")
    expect(subject).to be_file
    expect(subject).to be_mode(440)
    expect(subject).to be_owned_by("root")
    expect(subject).to be_grouped_into("root")
  end

  it "installs a api-umbrella.yml file" do
    subject = file("/etc/api-umbrella/api-umbrella.yml")
    expect(subject).to be_file
    expect(subject).to be_mode(644)
    expect(subject).to be_owned_by("root")
    expect(subject).to be_grouped_into("root")
  end

  it "sets up the api-umbrella user" do
    subject = user("api-umbrella")
    expect(subject).to exist
    expect(subject).to belong_to_group("api-umbrella")
    expect(subject).to have_home_directory("/opt/api-umbrella")
    expect(subject).to have_login_shell("/sbin/nologin")
  end

  it "sets up the api-umbrella-deploy user's home directory and empty ssh keys file" do
    subject = user("api-umbrella-deploy")
    expect(subject).to exist
    expect(subject).to belong_to_group("api-umbrella-deploy")
    expect(subject).to have_home_directory("/home/api-umbrella-deploy")
    expect(subject).to have_login_shell("/bin/bash")

    subject = file("/home/api-umbrella-deploy")
    expect(subject).to be_directory
    expect(subject).to be_mode(700)
    expect(subject).to be_owned_by("api-umbrella-deploy")
    expect(subject).to be_grouped_into("api-umbrella-deploy")

    subject = file("/home/api-umbrella-deploy/.ssh")
    expect(subject).to be_directory
    expect(subject).to be_mode(700)
    expect(subject).to be_owned_by("api-umbrella-deploy")
    expect(subject).to be_grouped_into("api-umbrella-deploy")

    subject = file("/home/api-umbrella-deploy/.ssh/authorized_keys")
    expect(subject).to be_file
    expect(subject).to be_mode(600)
    expect(subject).to be_owned_by("api-umbrella-deploy")
    expect(subject).to be_grouped_into("api-umbrella-deploy")
    expect(subject.content).to eql("")
  end

  it "symlinks the log directory" do
    subject = file("/var/log/api-umbrella")
    expect(subject).to be_symlink
    expect(subject).to be_owned_by("root")
    expect(subject).to be_grouped_into("root")
    expect(subject).to be_linked_to("../../opt/api-umbrella/var/log")
  end
end
