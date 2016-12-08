import Ember from 'ember';

export function inflect(params) {
  let word = params[0];
  let number = params[1];
  return inflection.inflect(word, number);
}

export default Ember.Helper.helper(inflect);
