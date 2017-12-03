import Ember from 'ember';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

export function tHelper([message, ...rest]) {
  message = message.replace(/\\n/g, "\n");
  return t(message, ...rest);
}

export default Ember.Helper.helper(tHelper);
