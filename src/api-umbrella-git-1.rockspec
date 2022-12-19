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
  "lapis ~> 1.9.0",
  "libcidr-ffi ~> 1.0.0",
  "lua-resty-auto-ssl ~> 0.13.1",
  "lua-resty-http ~> 0.16.1",
  "lua-resty-mail ~> 1.0.2",
  "lua-resty-mlcache ~> 2.6.0",
  "lua-resty-nettle ~> 2.1",
  "lua-resty-openidc ~> 1.7.5",
  "lua-resty-session ~> 3.10",
  "lua-resty-txid ~> 1.0.0",
  "lua-resty-uuid ~> 1.1",
  "lua-resty-validation ~> 2.7",
  "luajit-zstd ~> 0.2.3",
  "lualdap ~> 1.3.0",
  "luaposix ~> 35.1",
  "luautf8 ~> 0.1.5",
  "lustache ~> 1.3.1",
  "lyaml ~> 6.2.8",
  "penlight ~> 1.13.1",
  -- Some of our custom postgres encoding logic isn't compatible with >=1.15
  -- yet. 1.15 I think should actually make it easier in some ways, but we'll
  -- need to revisit.
  "pgmoon ~> 1.14.0",
  "psl ~> 0.3",
  "shell-games ~> 1.1.0",
}

build = {
  type = "builtin",
  modules = {},
}
