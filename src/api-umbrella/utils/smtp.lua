local ngx_socket_tcp = ngx.socket.tcp
local encode_base64 = ngx.encode_base64

local _M = {}
local mt = { __index = _M }

local function send_cmd(self, cmd)
  if #cmd > 2000 then
    return nil, "may not exceed 2kB"
  end

  if ngx.re.match(cmd, "[\r\n]", "jo") then
    return nil, "may not contain CR or LF line breaks"
  end

  local bytes, err = self.sock:send(cmd .. "\r\n")
  if not bytes then
    return bytes, err
  end

  local line, err = self.sock:receive()
  if not line then
    return nil, err
  end
end

function _M.new(options)
  local sock, err = ngx_socket_tcp()
  if not sock then
    return nil, err
  end
  assert(options["host"])
  assert(options["port"])
  return setmetatable({ sock = sock, options = options }, mt)
end

local seqno = 0
function _M.send(self, data)
  seqno = seqno + 1
  boundary = string.format("--==_mimepart_" .. ngx.now() * 1000 .. "_%05d_%05u", math.random(0, 99999), seqno)
  ngx.log(ngx.ERR, "BOUNDARY: " .. inspect(boundary))

  self.sock:connect(self.options["host"], self.options["port"])
  send_cmd(self, "EHLO " .. self.options["host"])
  send_cmd(self, "MAIL FROM:<" .. data["from"] .. ">")
  send_cmd(self, "RCPT TO:<" .. data["to"] .. ">")
  self.sock:send({
    "DATA\r\n",
    "From: ", data["from"], "\r\n",
    "To: ", data["to"], "\r\n",
    "Subject: ", data["subject"], "\r\n",
    "Content-Type: multipart/alternative; charset=utf-8; boundary=\"", boundary, "\"\r\n",
    "Content-Transfer-Encoding: base64\r\n",
    "MIME-Version: 1.0\r\n",
    "\r\n",
    "--", boundary, "\r\n",
    "Content-Type: text/plain; charset=utf-8\r\n",
    "Content-Transfer-Encoding: base64\r\n",
    "\r\n",
    encode_base64(data["text"]), "\n",
    "--", boundary, "\r\n",
    "Content-Type: text/html; charset=utf-8\r\n",
    "Content-Transfer-Encoding: base64\r\n",
    "\r\n",
    encode_base64(data["html"]), "\n",
    "--", boundary, "--",
    "\r\n.\r\n",
  })
  send_cmd(self, "QUIT")
end

return _M
