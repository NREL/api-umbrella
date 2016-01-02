import Base from './base';

export default Base.extend({
  model: function(params) {
    // Clear the record cache, so this is always fetched from the server (to
    // account for two users simultaneously editing the same record).
    Admin.AdminGroup.clearCache();

    return Admin.AdminGroup.find(params.adminGroupId);
  },
});
