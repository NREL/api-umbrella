import I18n from 'npm:i18n-js';
import { helper } from '@ember/component/helper';

export function t(params, options) {
  let key = params[0];
  return I18n.t(key, options);
}

export default helper(t);
