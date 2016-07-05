import Base from './base';

export default Base.extend({
  model(params) {
    return this.get('store').findRecord('admin', params.adminId);
  },
});
