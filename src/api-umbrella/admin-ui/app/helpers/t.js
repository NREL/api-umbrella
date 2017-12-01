import Ember from 'ember';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

export function tHelper(params) {
  return t(...params);
}

export default Ember.Helper.helper(tHelper);
