import Ember from 'ember';
import SaveMixin from 'api-umbrella-admin/mixins/save';
import { module, test } from 'qunit';

module('Unit | Mixin | save');

// Replace this with your real tests.
test('it works', function(assert) {
  let SaveObject = Ember.Object.extend(SaveMixin);
  let subject = SaveObject.create();
  assert.ok(subject);
});
