import Form from './form';

export default Form.extend({
  model(params) {
    this.clearStoreCache();
    return this.get('store').findRecord('api-scope', params.api_scope_id, { reload: true });
  },
});
