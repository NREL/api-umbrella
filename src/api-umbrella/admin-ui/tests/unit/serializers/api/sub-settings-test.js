import { moduleForModel, test } from 'ember-qunit';

moduleForModel('api/sub-settings', 'Unit | Serializer | api/sub settings', {
  // Specify the other units that are required for this test.
  needs: ['serializer:api/sub-settings']
});

// Replace this with your real tests.
test('it serializes records', function(assert) {
  let record = this.subject();

  let serializedRecord = record.serialize();

  assert.ok(serializedRecord);
});
