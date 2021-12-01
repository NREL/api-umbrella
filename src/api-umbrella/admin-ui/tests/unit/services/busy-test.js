import { setupTest } from 'ember-qunit';
import { module, test } from 'qunit';

module('Unit | Service | busy', function(hooks) {
  setupTest(hooks);

  // Replace this with your real tests.
  test('it exists', function(assert) {
    let service = this.owner.lookup('service:busy');
    assert.ok(service);
  });
});
