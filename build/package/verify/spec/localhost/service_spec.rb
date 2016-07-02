require "spec_helper"

require "multi_json"
require "rest-client"
require "yaml"

MultiJson.use(:ok_json)

RSpec.shared_examples("installed") do
  it "installs the package" do
    expect(package("api-umbrella")).to be_installed
  end

  it "enables the service" do
    expect(service("api-umbrella")).to be_enabled
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

  it "symlinks the log directory" do
    subject = file("/var/log/api-umbrella")
    expect(subject).to be_symlink
    expect(subject).to be_owned_by("root")
    expect(subject).to be_grouped_into("root")
    expect(subject).to be_linked_to("../../opt/api-umbrella/var/log")
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
end

RSpec.shared_examples("package upgrade") do |package_version|
  # Skip testing upgrades if we don't have binary packages for certain distro
  # and version combinations.
  case(ENV["DIST"])
  when "debian-8"
    # No Debian 8 packages until v0.9
    if(Gem::Version.new(package_version) < Gem::Version.new("0.9.0-1"))
      next
    end
  when "ubuntu-16.04"
    # No Ubuntu 16.04 packages until v0.12
    if(Gem::Version.new(package_version) < Gem::Version.new("0.12.0-1"))
      next
    end
  end

  def ensure_uninstalled
    command_result = command("/etc/init.d/api-umbrella stop")
    command_result.exit_status

    case(os[:family])
    when "redhat"
      command_result = command("yum -y remove api-umbrella")
    when "ubuntu", "debian"
      command_result = command("dpkg --purge api-umbrella")
    end
    command_result.exit_status

    expect(package("api-umbrella")).to_not be_installed
    FileUtils.rm_rf("/opt/api-umbrella")
    FileUtils.rm_rf("/etc/api-umbrella")
  end

  def install_package(version)
    if(version == :current)
      package_path = "#{ENV["SOURCE_DIR"]}/build/work/package/current/#{ENV["DIST"]}/core/*"
    else
      package_path = "#{ENV["SOURCE_DIR"]}/build/work/package/archives/#{version}/#{ENV["DIST"]}/core/*"
    end

    case(os[:family])
    when "redhat"
      command_result = command("yum -y install #{package_path}")
    when "ubuntu", "debian"
      command_result = command("dpkg -i #{package_path} || apt-get install -y -f")
    end
    expect(command_result.exit_status).to eql(0)

    # We may get some warnings during upgrades (due to non-empty directories),
    # but make sure we don't have any other unexpected STDERR output.
    stderr = command_result.stderr
    stderr.gsub!(/^dpkg: warning:.*/, "")
    stderr.strip!
    expect(stderr).to eql("")

    expect(package("api-umbrella")).to be_installed
  end

  describe "from v#{package_version}" do
    describe "service stopped before upgrade" do
      before(:all) do
        ensure_uninstalled
        install_package(package_version)
      end

      after(:all) do
        ensure_uninstalled
      end

      it "is not running before upgrade" do
        expect(service("api-umbrella")).to_not be_running.under(:init)
      end

      it "upgrades the package" do
        expect(package("api-umbrella").version.version).to start_with(package_version)
        install_package(:current)
        expect(package("api-umbrella").version.version).to_not start_with(package_version)
      end

      it "is not running after upgrade" do
        expect(service("api-umbrella")).to_not be_running.under(:init)
      end

      it "can start the service" do
        command_result = command("/etc/init.d/api-umbrella start")
        expect(command_result.exit_status).to eql(0)
        expect(command_result.stderr).to eql("")

        expect(service("api-umbrella")).to be_running.under(:init)
        expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)
      end

      it_behaves_like "installed"
    end

    describe "service running before upgrade" do
      before(:all) do
        ensure_uninstalled
        install_package(package_version)
      end

      after(:all) do
        ensure_uninstalled
      end

      it "starts the service before the upgrade" do
        # The Docker image of centos 7 we use for testing seems to be missing
        # the /run/lock directory (which /var/lock symlinks to). The API
        # Umbrella v0.8.0 init.d script relies on touching
        # /var/lock/api-umbrella, so make sure this directory exists prior to
        # running the legacy start script.
        if(ENV["DIST"] == "centos-7" && package_version == "0.8.0")
          FileUtils.mkdir_p("/run/lock")
        end

        command_result = command("/etc/init.d/api-umbrella start")
        expect(command_result.exit_status).to eql(0)
        expect(command_result.stderr).to eql("")
        expect(service("api-umbrella")).to be_running.under(:init)
        if(package_version >= "0.9.0")
          expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)
        end

        command_result = command("/etc/init.d/api-umbrella status")
        expect(command_result.stdout).to match(/pid \d+/)
        @pre_upgrade_pid = command_result.stdout.match(/pid (\d+)/)[1]
      end

      it "upgrades the package" do
        expect(package("api-umbrella").version.version).to start_with(package_version)
        install_package(:current)
        expect(package("api-umbrella").version.version).to_not start_with(package_version)
      end

      # Due to a bug in the prerm script in v0.8.0, API Umbrella will always be
      # stopped during upgrades from v0.8 on Ubuntu & Debian. There's not a
      # very clean solution, so we'll just ensure this doesn't happen for
      # future upgrades.
      if(["ubuntu", "debian"].include?(os[:family]) && package_version == "0.8.0")
        it "is not running after upgrade (due to v0.8.0 prerm script bug)" do
          expect(service("api-umbrella")).to_not be_running.under(:init)
        end

        it "can start the service" do
          command_result = command("/etc/init.d/api-umbrella start")
          expect(command_result.exit_status).to eql(0)
          expect(command_result.stderr).to eql("")

          expect(service("api-umbrella")).to be_running.under(:init)
          expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)
        end
      else
        it "restarts the service during the upgrade" do
          expect(service("api-umbrella")).to be_running.under(:init)
          expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)

          command_result = command("/etc/init.d/api-umbrella status")
          expect(command_result.stdout).to match(/pid \d+/)
          post_upgrade_pid = command_result.stdout.match(/pid (\d+)/)[1]

          expect(post_upgrade_pid).to_not eql(@pre_upgrade_pid)
        end
      end

      it_behaves_like "installed"
    end
  end
end

describe "api-umbrella" do
  it_behaves_like "installed"

  it "runs the service" do
    expect(service("api-umbrella")).to be_running.under(:init)
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

  it "listens on port 14014 with rsyslog" do
    expect(port(14014)).to be_listening.on("127.0.0.1").with("tcp")
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

  it "exits immediately if start is called when already started" do
    command_result = command("/etc/init.d/api-umbrella start")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stdout).to include("api-umbrella is already running")
    expect(command_result.stderr).to eql("")
  end

  it "accepts a reload command" do
    command_result = command("/etc/init.d/api-umbrella reload")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stderr).to eql("")

    # Wait for API Umbrella to become fully started and health again, to ensure
    # subsequent tests don't fail.
    expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)
  end

  it "can be stopped and started again" do
    # Stop
    command_result = command("/etc/init.d/api-umbrella stop")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stderr).to eql("")

    # Check status
    expect(service("api-umbrella")).to_not be_running.under(:init)
    command_result = command("/etc/init.d/api-umbrella status")
    expect(command_result.exit_status).to eql(3)
    expect(command_result.stdout).to include("api-umbrella is stopped")
    expect(command_result.stderr).to eql("")

    # Run some extra tests while we have API Umbrella in the stopped state:
    #
    # Verify behavior of stop command after already stopped.
    command_result = command("/etc/init.d/api-umbrella stop")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stdout).to include("api-umbrella is already stopped")
    expect(command_result.stderr).to eql("")

    # Verify behavior of reload command when stopped.
    command_result = command("/etc/init.d/api-umbrella reload")
    expect(command_result.exit_status).to eql(7)
    expect(command_result.stdout).to include("api-umbrella is stopped")
    expect(command_result.stderr).to eql("")

    # Verify behavior of condrestart command when stopped.
    command_result = command("/etc/init.d/api-umbrella condrestart")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stdout).to eql("")
    expect(command_result.stderr).to eql("")

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

  describe "uninstall" do
    before(:all) do
      expect(package("api-umbrella")).to be_installed

      # For RPMs modify the config file (append a new line), so we can make
      # sure modified files get preserved on uninstall.
      if(os[:family] == "redhat")
        File.open("/etc/api-umbrella/api-umbrella.yml", "a") do |f|
          f.puts "\n"
        end
      end

      case(os[:family])
      when "redhat"
        command_result = command("yum -y remove api-umbrella")
      when "ubuntu", "debian"
        command_result = command("dpkg -r api-umbrella")
      end
      expect(command_result.exit_status).to eql(0)
      expect(command_result.stderr).to eql("")
    end

    it "uninstalls the package" do
      expect(package("api-umbrella")).to_not be_installed
    end

    it "stops the service" do
      expect(service("api-umbrella")).to_not be_running.under(:init)
    end

    it "disables the service" do
      expect(service("api-umbrella")).to_not be_enabled
    end

    [
      "/etc/init.d/api-umbrella",
      "/etc/logrotate.d/api-umbrella",
      "/etc/sudoers.d/api-umbrella",
      "/opt/api-umbrella/embedded",
      "/usr/bin/api-umbrella",
      "/var/log/api-umbrella",
    ].each do |path|
      it "removes #{path}" do
        subject = file(path)
        expect(subject).to_not exist
      end

      if(os[:family] == "redhat")
        it "removes #{path}.rpmsave" do
          subject = file("#{path}.rpmsave")
          expect(subject).to_not exist
        end
      end
    end

    [
      "/etc/api-umbrella/api-umbrella.yml",
    ].each do |path|
      if(os[:family] == "redhat")
        it "removes #{path}" do
          subject = file(path)
          expect(subject).to_not exist
        end

        it "keeps #{path}.rpmsave" do
          subject = file("#{path}.rpmsave")
          expect(subject).to exist
        end
      else
        it "keeps #{path}" do
          subject = file(path)
          expect(subject).to exist
        end
      end
    end

    [
      "/opt/api-umbrella/var/log",
      "/opt/api-umbrella/var/db",
    ].each do |path|
      it "keeps #{path}" do
        subject = file(path)
        expect(subject).to exist
      end
    end

    if(["ubuntu", "debian"].include?(os[:family]))
      describe "purge" do
        before(:all) do
          expect(package("api-umbrella")).to_not be_installed

          command_result = command("dpkg --purge api-umbrella")
          expect(command_result.exit_status).to eql(0)
          expect(command_result.stderr).to eql("")
        end

        [
          "/etc/api-umbrella",
          "/opt/api-umbrella",
        ].each do |path|
          it "removes #{path}" do
            subject = file(path)
            expect(subject).to_not exist
          end
        end
      end
    end
  end

  it_behaves_like "package upgrade", "0.8.0-1"
  it_behaves_like "package upgrade", "0.9.0-1"
  it_behaves_like "package upgrade", "0.10.0-1"
  it_behaves_like "package upgrade", "0.11.0-1"
  it_behaves_like "package upgrade", "0.11.1-1"
end
