import Ember from 'ember';

export function t(params) {
  let key = params[0];
  return I18n.t(key);
}

export default Ember.Helper.helper(t);
