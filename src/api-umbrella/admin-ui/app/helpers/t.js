import { helper } from '@ember/component/helper';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

export function tHelper([message, ...rest]) {
  message = message.replace(/\\n/g, "\n");
  return t(message, ...rest);
}

export default helper(tHelper);
