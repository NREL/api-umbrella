import { helper } from '@ember/component/helper';
import { htmlSafe } from '@ember/string';

export function htmlSafeHelper(params) {
  let value = params[0];
  return new htmlSafe(value);
}

export default helper(htmlSafeHelper);
