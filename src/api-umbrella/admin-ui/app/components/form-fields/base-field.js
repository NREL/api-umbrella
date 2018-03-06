import Component from '@ember/component';
import { computed } from '@ember/object';

export default Component.extend({
  inputId: computed('elementId', 'fieldName', function() {
    return this.get('elementId') + '-' + this.get('fieldName');
  }),
}).reopenClass({
  positionalParams: ['fieldName'],
});
