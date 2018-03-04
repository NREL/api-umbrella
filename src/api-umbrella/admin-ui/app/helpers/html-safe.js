import { helper } from '@ember/component/helper';

export function htmlSafe(params) {
  let value = params[0];
  return new htmlSafe(value);
}

export default helper(htmlSafe);
