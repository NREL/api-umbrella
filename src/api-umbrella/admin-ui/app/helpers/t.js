import Ember from 'ember';

export function t(params, options) {
  let key = params[0];
  return I18n.t(key, options);
}

export default Ember.Helper.helper(t);
