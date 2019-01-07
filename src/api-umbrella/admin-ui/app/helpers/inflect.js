import { helper } from '@ember/component/helper';
import inflection from 'inflection';

export function inflect(params) {
  let word = params[0];
  let number = params[1];
  return inflection.inflect(word, number);
}

export default helper(inflect);
