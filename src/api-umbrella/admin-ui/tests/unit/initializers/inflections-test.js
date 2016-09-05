import Ember from 'ember';
import InflectionsInitializer from 'api-umbrella-admin-ui/initializers/inflections';
import { module, test } from 'qunit';

let application;

module('Unit | Initializer | inflections', {
  beforeEach() {
    Ember.run(function() {
      application = Ember.Application.create();
      application.deferReadiness();
    });
  }
});

// Replace this with your real tests.
test('it works', function(assert) {
  InflectionsInitializer.initialize(application);

  // you would normally confirm the results of the initializer here
  assert.ok(true);
});
