import Form from './form';

export default Form.extend({
  model(params) {
    return this.get('store').findRecord('website-backend', params.websiteBackendId);
  },
});
