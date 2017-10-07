return function(self, obj)
  self.res.headers["Content-Type"] = "text/csv"
  self.res.content = obj
  return { layout = false }
end
