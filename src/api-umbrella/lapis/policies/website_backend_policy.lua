local _M = {}

function _M.authorized_query_scope(current_admin, permission_id)
  assert(current_admin)

  if current_admin.superuser then
    return nil
  end

  if not permission_id then
    permission_id = "backend_manage"
  end

  return nil
end

function _M.authorize_show(current_admin, data, permission_id)
  assert(current_admin)
  assert(data)

  if current_admin.superuser then
    return true
  end

  if not permission_id then
    permission_id = "backend_manage"
  end

  return true
end

_M.authorize_modify = _M.authorize_show

return _M
