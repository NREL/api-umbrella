import Ember from 'ember';

export default Ember.Component.extend({
  inputId: Ember.computed('elementId', 'fieldName', function() {
    return this.get('elementId') + '-' + this.get('fieldName');
  }),
}).reopenClass({
  positionalParams: ['fieldName'],
});
