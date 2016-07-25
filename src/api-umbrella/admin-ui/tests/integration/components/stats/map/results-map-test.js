import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('stats/map/results-map', 'Integration | Component | stats/map/results map', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{stats/map/results-map}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#stats/map/results-map}}
      template block text
    {{/stats/map/results-map}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
