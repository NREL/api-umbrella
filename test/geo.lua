request = function()
  wrk.headers["X-Real-IP"] = math.random(1, 255) .. "." .. math.random(1, 255) .. "." .. math.random(1, 255) .. "." .. math.random(1, 255)
  return wrk.format(nil, "/")
end
