package = "api-umbrella-test"

version = "git-1"
source = {
  url = "git+https://github.com/NREL/api-umbrella.git"
}

dependencies = {
  "luacheck ~> 1.1.1",
  "luaposix ~> 36.2.1",
  "penlight ~> 1.13.1",
  "shell-games ~> 1.1.0",
}

build = {
  type = "builtin",
  modules = {},
}
