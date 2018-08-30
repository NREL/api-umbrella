import Form from './form';

export default Form.extend({
  model() {
    this.clearStoreCache();
    return this.store.createRecord('api-scope');
  },
});
