package = "api-umbrella-test"

version = "git-1"
source = {
  url = "git+https://github.com/NREL/api-umbrella.git"
}

dependencies = {
  "luacheck ~> 0.26.1",
  "luaposix ~> 35.1",
  "penlight ~> 1.12.0",
  "shell-games ~> 1.1.0",
}

build = {
  type = "builtin",
  modules = {},
}
