package = "api-umbrella"

version = "git-1"
source = {
  url = "git+https://github.com/NREL/api-umbrella.git"
}

dependencies = {
  "argparse ~> 0.7.1",
  "bcrypt ~> 2.3",
  "dkjson ~> 2.6",
  "inspect ~> 3.1.3",
  "lapis ~> 1.16.0",
  "libcidr-ffi ~> 1.0.0",
  "lua-resty-http ~> 0.17.1",
  "lua-resty-mail ~> 1.1.0",
  "lua-resty-mlcache ~> 2.6.1",
  "lua-resty-nettle ~> 2.1",
  "lua-resty-openidc ~> 1.7.6",
  "lua-resty-session ~> 3.10",
  "lua-resty-txid ~> 1.0.0",
  "lua-resty-uuid ~> 1.1",
  "lua-resty-validation ~> 2.7",
  "luajit-zstd ~> 0.2.3",
  "lualdap ~> 1.4.0",
  "luaposix ~> 36.2.1",
  "luautf8 ~> 0.1.5",
  "lustache ~> 1.3.1",
  "lyaml ~> 6.2.8",
  "penlight ~> 1.13.1",
  "psl ~> 0.3",
  "shell-games ~> 1.1.0",
}

build = {
  type = "builtin",
  modules = {},
}
