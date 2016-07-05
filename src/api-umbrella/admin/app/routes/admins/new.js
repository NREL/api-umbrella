import Base from './base';

export default Base.extend({
  model() {
    return this.get('store').createRecord('admin');
  },
});
