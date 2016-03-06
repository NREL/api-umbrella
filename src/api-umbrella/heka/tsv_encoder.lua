-- luacheck: globals read_message add_to_payload inject_payload process_message

require "string"
require "table"

function process_message()
  local tsv = {
    read_message("Fields[id]") or "",
    read_message("Fields[request_at]") or "",
    read_message("Fields[request_at_hour]") or "",
    read_message("Fields[request_at_minute]") or "",
    read_message("Fields[user_id]") or "",
    read_message("Fields[denied_reason]") or "",
    read_message("Fields[request_method]") or "",
    read_message("Fields[request_url_scheme]") or "",
    read_message("Fields[request_url_host]") or "",
    read_message("Fields[request_url_port]") or "",
    read_message("Fields[request_url_path]") or "",
    read_message("Fields[request_url_path_level1]") or "",
    read_message("Fields[request_url_path_level2]") or "",
    read_message("Fields[request_url_path_level3]") or "",
    read_message("Fields[request_url_path_level4]") or "",
    read_message("Fields[request_url_path_level5]") or "",
    read_message("Fields[request_url_path_level6]") or "",
    read_message("Fields[request_url_query]") or "",
    read_message("Fields[request_ip]") or "",
    read_message("Fields[request_ip_country]") or "",
    read_message("Fields[request_ip_region]") or "",
    read_message("Fields[request_ip_city]") or "",
    read_message("Fields[request_ip_lat]") or "",
    read_message("Fields[request_ip_lon]") or "",
    read_message("Fields[request_user_agent]") or "",
    read_message("Fields[request_user_agent_type]") or "",
    read_message("Fields[request_user_agent_family]") or "",
    read_message("Fields[request_size]") or "",
    read_message("Fields[request_accept]") or "",
    read_message("Fields[request_accept_encoding]") or "",
    read_message("Fields[request_content_type]") or "",
    read_message("Fields[request_connection]") or "",
    read_message("Fields[request_origin]") or "",
    read_message("Fields[request_referer]") or "",
    read_message("Fields[request_basic_auth_username]") or "",
    read_message("Fields[response_status]") or "",
    read_message("Fields[response_content_type]") or "",
    read_message("Fields[response_content_length]") or "",
    read_message("Fields[response_content_encoding]") or "",
    read_message("Fields[response_transfer_encoding]") or "",
    read_message("Fields[response_server]") or "",
    read_message("Fields[response_cache]") or "",
    read_message("Fields[response_age]") or "",
    read_message("Fields[response_size]") or "",
    read_message("Fields[timer_response]") or "",
    read_message("Fields[timer_backend_response]") or "",
    read_message("Fields[timer_internal]") or "",
    read_message("Fields[timer_proxy_overhead]") or "",
    read_message("Fields[log_imported]") or "",
  }

  add_to_payload(table.concat(tsv, "\t"), "\n")
  inject_payload()
  return 0
end
