import Ember from 'ember';
import i18n from 'api-umbrella-admin-ui/utils/i18n';

export function t(params, options) {
  let key = params[0];
  return i18n.t(key, options);
}

export default Ember.Helper.helper(t);
