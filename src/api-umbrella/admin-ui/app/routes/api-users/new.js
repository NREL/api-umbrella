import Form from './form';

export default Form.extend({
  model() {
    this.clearStoreCache();
    return this.fetchModels(this.store.createRecord('api-user'));
  },
});
