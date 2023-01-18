local json_encode_sorted_keys = require "api-umbrella.utils.json_encode_sorted_keys"
local json_decode = require("cjson.safe").decode

-- Replace lua-resty-session's default JSON serializer with one that serializes
-- in a stable, sorted manner.
--
-- The default serializer otherwise may return the same table in a different
-- order each time it is serialized, which can cause issues with the encryption
-- signatures or tagging. Without sorting the output by the keys, the same
-- underlying table may be output in different ways on each serialization call,
-- which can cause invalid signature errors when the session is updated but not
-- actually changed (eg, when the inactive time is touched).
return {
  serialize = json_encode_sorted_keys,
  deserialize = json_decode,
}
