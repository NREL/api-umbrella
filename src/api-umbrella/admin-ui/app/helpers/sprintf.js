import Ember from 'ember';
import { sprintf } from 'api-umbrella-admin-ui/utils/i18n';

export function sprintfHelper(params) {
  return sprintf(...params);
}

export default Ember.Helper.helper(sprintfHelper);
