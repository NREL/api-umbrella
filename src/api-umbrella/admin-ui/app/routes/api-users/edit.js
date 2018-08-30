import Form from './form';

export default Form.extend({
  model(params) {
    this.clearStoreCache();
    return this.fetchModels(this.store.findRecord('api-user', params.api_user_id, { reload: true }));
  },
});
