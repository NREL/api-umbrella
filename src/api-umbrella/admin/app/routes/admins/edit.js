import Base from './base';

export default Base.extend({
  model(params) {
    // Clear the record cache, so this is always fetched from the server (to
    // account for two users simultaneously editing the same record).
    //Admin.Admin.clearCache();

    return this.get('store').findRecord('admin', params.adminId);
  },
});
