--
-- Created by: anmunoz
-- Date: 3/16/18
-- Time: 2:03 PM
--
local _output_value = {}
function _output_value.trusted_app_validation(app_id_scope,trusted_app_list)
    for _, trusted_app_id in ipairs(trusted_app_list) do
        if app_id_scope == trusted_app_id.id then
            _output_value="trusted"
            return _output_value
        end
    end
    _output_value="not_trusted"
    return _output_value
end
return _output_value