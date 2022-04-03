-- Pre-load modules.
require "api-umbrella.proxy.hooks.init_preload_modules"

local worker_group_init = require("api-umbrella.utils.worker_group").init
worker_group_init()
