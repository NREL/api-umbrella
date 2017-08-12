local base_host_format = [[[a-zA-Z0-9:][a-zA-Z0-9\-\.:]*]]

return {
  base_host_format = base_host_format,
  host_format = "^" .. base_host_format .. "$",
  host_format_with_wildcard = [[^(\*|(\*\.|\.)]] .. base_host_format .. "|" .. base_host_format .. ")$",
  url_prefix_format = "^/",
}
