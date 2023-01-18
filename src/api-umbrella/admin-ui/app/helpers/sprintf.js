import { helper } from '@ember/component/helper';
import { sprintf } from 'api-umbrella-admin-ui/utils/i18n';

export function sprintfHelper(params) {
  return sprintf(...params);
}

export default helper(sprintfHelper);
