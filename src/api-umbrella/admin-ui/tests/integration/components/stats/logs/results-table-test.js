import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('stats/logs/results-table', 'Integration | Component | stats/logs/results table', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{stats/logs/results-table}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#stats/logs/results-table}}
      template block text
    {{/stats/logs/results-table}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
