import { helper } from '@ember/component/helper';

export function inflect(params) {
  let word = params[0];
  let number = params[1];
  return inflection.inflect(word, number);
}

export default helper(inflect);
