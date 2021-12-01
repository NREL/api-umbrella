import { helper } from '@ember/component/helper';
import { htmlSafe } from '@ember/template';

export function htmlSafeHelper(params) {
  let value = params[0];
  return htmlSafe(value);
}

export default helper(htmlSafeHelper);
