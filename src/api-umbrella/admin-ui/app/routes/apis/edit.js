import Form from './form';

export default Form.extend({
  model(params) {
    this.clearStoreCache();
    return this.fetchModels(this.get('store').findRecord('api', params.apiId, { reload: true }));
  },
});
