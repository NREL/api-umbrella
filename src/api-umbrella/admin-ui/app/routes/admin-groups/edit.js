import Form from './form';

export default Form.extend({
  model(params) {
    this.clearStoreCache();
    return this.fetchModels(this.store.findRecord('admin-group', params.admin_group_id, { reload: true }));
  },
});
