import { htmlSafe } from 'api-umbrella-admin/helpers/html-safe';
import { module, test } from 'qunit';

module('Unit | Helper | html safe');

// Replace this with your real tests.
test('it works', function(assert) {
  let result = htmlSafe([42]);
  assert.ok(result);
});
