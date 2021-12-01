import { helper } from '@ember/component/helper';
import { guidFor } from '@ember/object/internals';

export function guidForHelper(params) {
  let object = params[0];

  return guidFor(object);
}

export default helper(guidForHelper);
