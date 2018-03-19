import Inflector from 'ember-inflector';

export function initialize() {
  // So the Api model doesn't try to singularize the subSettings hasMany
  // relationship (which leads to it trying to find the non-existent
  // "api/sub-setting" model).
  Inflector.inflector.irregular('sub-settings', 'sub-settings');
}

export default {
  name: 'inflections',
  initialize,
};
