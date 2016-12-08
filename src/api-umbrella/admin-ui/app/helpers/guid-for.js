import Ember from 'ember';

export function guidFor(params) {
  let object = params[0];

  return Ember.guidFor(object);
}

export default Ember.Helper.helper(guidFor);
