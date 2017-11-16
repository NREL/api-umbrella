local json_null = require("cjson").null

local gsub = ngx.re.gsub
local null = ngx.null

local _M = {}

function _M.set_response_headers(self, filename)
  self.res.headers["Content-Type"] = "text/csv"
  self.res.headers["Content-Disposition"] = 'attachment; filename="' .. filename .. '"'
end

function _M.row_to_csv(row)
  local output = {}
  for i, value in ipairs(row) do
    if value == nil or value == null or value == json_null or value == "" then
      output[i] = ""
    else
      output[i] = '"' .. gsub(value, '"', '""', "jo") .. '"'
    end
  end

  return table.concat(output, ",")
end

return _M
