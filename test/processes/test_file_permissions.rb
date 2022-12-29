require_relative "../test_helper"

class Test::Processes::TestFilePermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    once_per_class_setup do
      @@user_uid = nil
      @@group_gid = nil
      @@process_uid = ::Process.euid
      @@process_gid = ::Process.egid

      if($config["user"])
        @@user_uid = Etc.getpwnam($config["user"]).uid
      end

      if($config["group"])
        @@group_gid = Etc.getgrnam($config["group"]).gid
      end
    end
  end

  def test_db_dir
    stat = File.stat($config["db_dir"])
    assert_equal("40750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_dir
    stat = File.stat($config["etc_dir"])
    assert_equal("40750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_perp_dir
    stat = File.stat(File.join($config["etc_dir"], "perp"))
    assert_equal("40750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_perp_uninstalled_service_dir
    assert_equal(true, Dir.exist?(File.join(API_UMBRELLA_SRC_ROOT, "templates", "etc", "perp", "dev-env-ember-server")))
    assert_equal(false, Dir.exist?(File.join($config["etc_dir"], "perp", "dev-env-ember-server")))
  end

  def test_etc_perp_disabled_service_dir
    stat = File.stat(File.join($config["etc_dir"], "perp", "elasticsearch-aws-signing-proxy"))
    assert_equal("40750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_perp_nginx_dir
    stat = File.stat(File.join($config["etc_dir"], "perp", "nginx"))
    assert_equal("41750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_perp_nginx_rc_env_file
    stat = File.stat(File.join($config["etc_dir"], "perp", "nginx", "rc.env"))
    assert_equal("100640", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_perp_nginx_rc_log_file
    stat = File.stat(File.join($config["etc_dir"], "perp", "nginx", "rc.log"))
    assert_equal("100750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_perp_nginx_rc_main_file
    stat = File.stat(File.join($config["etc_dir"], "perp", "nginx", "rc.main"))
    assert_equal("100750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_etc_trafficserver_dir
    stat = File.stat(File.join($config["etc_dir"], "trafficserver"))
    assert_equal("40750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_log_dir
    stat = File.stat($config["log_dir"])
    assert_equal("40750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_log_nginx_dir
    stat = File.stat(File.join($config["log_dir"], "nginx"))
    assert_equal("40750", stat.mode.to_s(8))
    assert_owner(stat)
    assert_group(stat)
  end

  def test_run_dir
    stat = File.stat($config["run_dir"])
    assert_equal("40750", stat.mode.to_s(8))
    assert_owner(stat)
    assert_group(stat)
  end

  def test_run_runtime_config_file
    stat = File.stat(File.join($config["run_dir"], "runtime_config.json"))
    assert_equal("100640", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_run_cached_random_config_file
    stat = File.stat(File.join($config["run_dir"], "cached_random_config_values.json"))
    assert_equal("100640", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_tmp_dir
    stat = File.stat($config["tmp_dir"])
    assert_equal("41777", stat.mode.to_s(8))
    assert_owner(stat)
    assert_group(stat)
  end

  def test_var_dir
    stat = File.stat($config["var_dir"])
    assert_equal("40750", stat.mode.to_s(8))
    assert_process_owner(stat)
    assert_group(stat)
  end

  def test_var_trafficserver_dir
    stat = File.stat(File.join($config["var_dir"], "trafficserver"))
    assert_equal("40750", stat.mode.to_s(8))
    assert_owner(stat)
    assert_group(stat)
  end

  private

  def assert_process_owner(stat)
    assert_equal(@@process_uid, stat.uid)
  end

  def assert_owner(stat)
    if(@@user_uid)
      assert_equal(@@user_uid, stat.uid)
    else
      assert_equal(@@process_uid, stat.uid)
    end
  end

  def assert_group(stat)
    if(@@group_gid)
      assert_equal(@@group_gid, stat.gid)
    else
      assert_equal(@@process_gid, stat.gid)
    end
  end
end
