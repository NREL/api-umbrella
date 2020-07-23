import { guidFor } from '@ember/object/internals';
import { helper } from '@ember/component/helper';

export function guidForHelper(params) {
  let object = params[0];

  return guidFor(object);
}

export default helper(guidForHelper);
