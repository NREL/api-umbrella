import Ember from 'ember';

export function htmlSafe(params) {
  let value = params[0];
  return new Ember.String.htmlSafe(value);
}

export default Ember.Helper.helper(htmlSafe);
