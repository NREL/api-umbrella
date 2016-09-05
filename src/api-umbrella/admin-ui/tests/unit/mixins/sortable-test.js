import Ember from 'ember';
import SortableMixin from 'api-umbrella-admin-ui/mixins/sortable';
import { module, test } from 'qunit';

module('Unit | Mixin | sortable');

// Replace this with your real tests.
test('it works', function(assert) {
  let SortableObject = Ember.Object.extend(SortableMixin);
  let subject = SortableObject.create();
  assert.ok(subject);
});
