-- Monkey patch Lapis' DB class to deal with custom escape handle (eg, for 64
-- bit integers).
--
-- This must be required before any files require the normal lapis DB files.

local int64 = require "api-umbrella.utils.int64"

-- Due to the way Lapis creates the db classes, we need to intercept the
-- "build_helpers" call, and override the "escape_literal" functions inside
-- there. This is because the escape_literal function gets passed around as an
-- argument, so we need to override the version of the method that's passed to
-- the build_helpers call on startup.
local db_base = require "lapis.db.base"
local orig_build_helpers = db_base.build_helpers
db_base.build_helpers = function(orig_escape_literal, escape_identifier)
  local escape_literal = function(val)
    if int64.is_64bit(val) then
      return orig_escape_literal(int64.to_string(val))
    else
      return orig_escape_literal(val)
    end
  end

  return orig_build_helpers(escape_literal, escape_identifier)
end

-- Also override the more direct "escape_literal" definition if this function
-- is called directly.
local db = require "lapis.db"
local orig_escape_literal = db.escape_literal
db.escape_literal = function(val)
  if int64.is_64bit(val) then
    return orig_escape_literal(int64.to_string(val))
  else
    return orig_escape_literal(val)
  end
end
