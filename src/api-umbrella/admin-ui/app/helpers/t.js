import Ember from 'ember';
import I18n from 'npm:i18n-js';

export function t(params, options) {
  let key = params[0];
  return I18n.t(key, options);
}

export default Ember.Helper.helper(t);
