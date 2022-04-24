require "spec_helper"

require "multi_json"
require "net/https"
require "uri"
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
end

RSpec.shared_examples("package upgrade") do |package_version|
  # Skip testing upgrades if we don't have binary packages for certain distro
  # and version combinations.
  case(ENV.fetch("DIST"))
  when "debian-9"
    # No Debian 9 packages until v0.15
    if(Gem::Version.new(package_version) < Gem::Version.new("0.15.0-1"))
      next
    end
  when "ubuntu-16.04"
    # No Ubuntu 16.04 packages until v0.12
    if(Gem::Version.new(package_version) < Gem::Version.new("0.12.0-1"))
      next
    end
  when "ubuntu-18.04"
    # No Ubuntu 16.04 packages until v0.15
    if(Gem::Version.new(package_version) < Gem::Version.new("0.15.0-1"))
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
      package_path = "#{ENV.fetch("SOURCE_DIR")}/build/package/work/current/#{ENV.fetch("DIST")}/core/*"
    else
      package_path = "#{ENV.fetch("SOURCE_DIR")}/build/package/work/archives/#{version}/#{ENV.fetch("DIST")}/core/*"
    end

    case(os[:family])
    when "redhat"
      command_result = command("yum -y install #{package_path}")
    when "ubuntu", "debian"
      command_result = command("dpkg -i #{package_path} || DEBIAN_FRONTEND=noninteractive apt-get install -y -f")
    end
    expect(command_result.exit_status).to eql(0)

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
        command_result = command("/etc/init.d/api-umbrella start")
        expect(command_result.exit_status).to eql(0)
        expect(command_result.stderr).to eql("")
        expect(service("api-umbrella")).to be_running.under(:init)
        expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)

        command_result = command("api-umbrella status")
        expect(command_result.stdout).to match(/pid \d+/)
        @pre_upgrade_pid = command_result.stdout.match(/pid (\d+)/)[1]
      end

      it "upgrades the package" do
        expect(package("api-umbrella").version.version).to start_with(package_version)
        install_package(:current)
        expect(package("api-umbrella").version.version).to_not start_with(package_version)
      end

      it "restarts the service during the upgrade" do
        expect(service("api-umbrella")).to be_running.under(:init)
        expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)

        command_result = command("api-umbrella status")
        expect(command_result.stdout).to match(/pid \d+/)
        post_upgrade_pid = command_result.stdout.match(/pid (\d+)/)[1]

        expect(post_upgrade_pid).to_not eql(@pre_upgrade_pid)
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

  it "all processes are running" do
    command_result = command("api-umbrella processes")
    expect(command_result.exit_status).to eql(0)
    output = command_result.stdout
    [
      "elasticsearch",
      "geoip-auto-updater",
      "mongod",
      "mora",
      "nginx",
      "rsyslog",
      "trafficserver",
      "web-delayed-job",
      "web-puma",
    ].each do |service|
      # Make sure all the expected processes are reported as running and aren't
      # flapping up and down.
      expect(output).to match(%r{^\[\+ \+\+\+ \+\+\+\] +#{service} +uptime: \d+s/\d+s +pids: \d+/\d+$})
    end
  end

  it "does not contain unexpected errors in logs" do
    logs = Dir.glob("/opt/api-umbrella/var/log/*/current").sort
    expect(logs).to eql([
      "/opt/api-umbrella/var/log/elasticsearch/current",
      "/opt/api-umbrella/var/log/geoip-auto-updater/current",
      "/opt/api-umbrella/var/log/mongod/current",
      "/opt/api-umbrella/var/log/mora/current",
      "/opt/api-umbrella/var/log/nginx/current",
      "/opt/api-umbrella/var/log/perpd/current",
      "/opt/api-umbrella/var/log/rsyslog/current",
      "/opt/api-umbrella/var/log/trafficserver/current",
      "/opt/api-umbrella/var/log/web-delayed-job/current",
      "/opt/api-umbrella/var/log/web-puma/current",
    ].sort)
    logs.each do |log|
      content = File.read(log)
      # Check the log output to ensure there's no unexpected errors. This batch
      # of tests is based on discovering rsylogd was missing a libcurl
      # dependency, but the error messages seem generic enough to test in all
      # the log files for. Based on these errors:
      #
      # rsyslogd: could not load module '/opt/api-umbrella/embedded/lib/rsyslog/omelasticsearch.so', dlopen: libcurl.so.4: cannot open shared object file: No such file or directory  [v8.24.0 try http://www.rsyslog.com/e/2066 ]
      # rsyslogd: module name 'omelasticsearch' is unknown [v8.24.0 try http://www.rsyslog.com/e/2209 ]
      expect(content).to_not include("dlopen")
      expect(content).to_not include("could not load module")
      expect(content).to_not include("cannot open shared object file")
      unless log.include?("trafficserver")
        expect(content).to_not include("No such file or directory")
      end
      expect(content).to_not match(/module name .+ is unknown/)
    end
  end

  it "reports green from the health api endpoint" do
    uri = URI.parse("https://localhost/api-umbrella/v1/health.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    expect(response.code).to eql("200")
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
    ["/", "/foo", "/root"].each do |home|
      command_result = command("env HOME=#{home} /etc/init.d/api-umbrella status")
      expect(command_result.exit_status).to eql(0)
      case(ENV.fetch("DIST"))
      when "centos-6", "centos-7"
        expect(command_result.stdout).to include("is running")
      else
        expect(command_result.stdout).to include("Active: active (running)")
      end
    end
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
    uri = URI.parse("https://localhost/signup/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    expect(response.code).to eql("200")
    expect(response.body).to include("API Key Signup")
  end

  it "admin first-time signup page loads" do
    uri = URI.parse("https://localhost/admins/signup")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    expect(response.code).to eql("200")
    expect(response.body).to include("Password Confirmation")
  end

  it "gatekeeper blocks key-less requests" do
    uri = URI.parse("https://localhost/api-umbrella/v1/test.json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    expect(response.code).to eql("403")
    expect(response.body).to include("API_KEY_MISSING")
  end

  it "gatekeeper blocks invalid key requests" do
    uri = URI.parse("https://localhost/api-umbrella/v1/test.json?api_key=INVALID_KEY")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    expect(response.code).to eql("403")
    expect(response.body).to include("API_KEY_INVALID")
  end

  it "fails immediately when startup script is called as an unauthorized user" do
    command_result = command("sudo -u api-umbrella-deploy /etc/init.d/api-umbrella start")
    expect(command_result.exit_status).to_not eql(0)
    case(ENV.fetch("DIST"))
    when "centos-6"
      expect(command_result.stdout).to include("Must be started with super-user privileges")
    when "centos-7"
      expect(command_result.stdout).to include("Starting api-umbrella (via systemctl)")
      expect(command_result.stdout).to include("FAILED")
    else
      expect(command_result.stdout).to include("Starting api-umbrella (via systemctl)")
      expect(command_result.stdout).to include("failed")
    end
  end

  it "allows the deploy user to execute api-umbrella commands as root" do
    expect(command("sudo -u api-umbrella-deploy sudo -n api-umbrella status").stdout).to include("is running")
    command_result = command("sudo -u api-umbrella-deploy sudo -n /etc/init.d/api-umbrella status")
    case(ENV.fetch("DIST"))
    when "centos-6", "centos-7"
      expect(command_result.stdout).to include("is running")
    else
      expect(command_result.stdout).to include("Active: active (running)")
    end
  end

  it "exits immediately if start is called when already started" do
    command_result = command("/etc/init.d/api-umbrella start")
    expect(command_result.exit_status).to eql(0)
    case(ENV.fetch("DIST"))
    when "centos-6"
      expect(command_result.stdout).to include("api-umbrella is already running")
    when "centos-7"
      expect(command_result.stdout).to include("Starting api-umbrella (via systemctl)")
      expect(command_result.stdout).to include("OK")
    else
      expect(command_result.stdout).to include("Starting api-umbrella (via systemctl)")
      expect(command_result.stdout).to_not include("failed")
    end
    expect(command_result.stderr).to eql("")
  end

  it "accepts a reload command" do
    command_result = command("/etc/init.d/api-umbrella reload")
    expect(command_result.exit_status).to eql(0)
    expect(command_result.stderr).to eql("")

    # Wait for API Umbrella to become fully started and health again, to ensure
    # subsequent tests don't fail.
    expect(command("api-umbrella health --wait-for-status green").exit_status).to eql(0)

    # After reloading, do some sanity checks on the Rails log files for some
    # issues we've seen crop up.
    ["web-puma", "web-delayed-job"].each do |type|
      log = file("/var/log/api-umbrella/#{type}/current")

      # Ensure we've properly cleared the bundler environment so API Umbrella's
      # Puma process doesn't pay attention to the bundler environment from these
      # serverspec tests when we send the reload command.
      expect(log.content).to_not include("You have already activated bundler")
      expect(log.content).to_not include("failed to load command")
      expect(log.content).to_not include("bundle exec")

      # Ensure bundler isn't warning about home directory issues:
      # https://github.com/bundler/bundler/blob/v1.14.4/lib/bundler.rb#L146-L166
      expect(log.content).to_not include("Your home directory")
      expect(log.content).to_not include("is not a directory")
      expect(log.content).to_not include("is not writable")
      expect(log.content).to_not include("home directory temporarily")

      # Ensure rails_stdout_logging is kicking in early enough and we aren't
      # attempting to write to the production.log file:
      # https://github.com/heroku/rails_stdout_logging/pull/28
      expect(log.content).to_not include("Unable to access log file")
      expect(log.content).to_not include("production.log")
    end
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
    case(ENV.fetch("DIST"))
    when "centos-6", "centos-7"
      expect(command_result.stdout).to include("api-umbrella is stopped")
    else
      expect(command_result.stdout).to include("Active: inactive (dead)")
    end
    expect(command_result.stderr).to eql("")

    # Run some extra tests while we have API Umbrella in the stopped state:
    #
    # Verify behavior of stop command after already stopped.
    command_result = command("/etc/init.d/api-umbrella stop")
    expect(command_result.exit_status).to eql(0)
    case(ENV.fetch("DIST"))
    when "centos-6"
      expect(command_result.stdout).to include("api-umbrella is already stopped")
    when "centos-7"
      expect(command_result.stdout).to include("Stopping api-umbrella (via systemctl)")
      expect(command_result.stdout).to include("OK")
    else
      expect(command_result.stdout).to include("Stopping api-umbrella (via systemctl)")
      expect(command_result.stdout).to_not include("failed")
    end
    expect(command_result.stderr).to eql("")

    # Verify behavior of reload command when stopped.
    command_result = command("/etc/init.d/api-umbrella reload")
    case(ENV.fetch("DIST"))
    when "centos-6"
      expect(command_result.exit_status).to eql(7)
      expect(command_result.stdout).to include("api-umbrella is stopped")
      expect(command_result.stderr).to eql("")
    when "centos-7"
      expect(command_result.exit_status).to eql(1)
      expect(command_result.stdout).to include("Reloading api-umbrella configuration (via systemctl)")
      expect(command_result.stdout).to include("FAILED")
    else
      expect(command_result.exit_status).to eql(1)
      expect(command_result.stdout).to include("Reloading api-umbrella configuration (via systemctl)")
      expect(command_result.stdout).to include("failed")
    end

    # Verify behavior of condrestart command when stopped.
    expect(service("api-umbrella")).to_not be_running.under(:init)
    command_result = command("/etc/init.d/api-umbrella condrestart")
    expect(command_result.exit_status).to eql(0)
    case(ENV.fetch("DIST"))
    when "centos-7"
      expect(command_result.stdout).to include("Restarting api-umbrella (via systemctl)")
      expect(command_result.stdout).to include("OK")
    else
      expect(command_result.stdout).to eql("")
    end
    expect(command_result.stderr).to eql("")
    expect(service("api-umbrella")).to_not be_running.under(:init)

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

  it_behaves_like "package upgrade", "0.11.1-1"
  it_behaves_like "package upgrade", "0.12.0-1"
  it_behaves_like "package upgrade", "0.13.0-1"
  it_behaves_like "package upgrade", "0.14.0-1"
  it_behaves_like "package upgrade", "0.14.1-1"
  it_behaves_like "package upgrade", "0.14.2-1"
  it_behaves_like "package upgrade", "0.14.3-1"
  it_behaves_like "package upgrade", "0.14.4-1"
end
