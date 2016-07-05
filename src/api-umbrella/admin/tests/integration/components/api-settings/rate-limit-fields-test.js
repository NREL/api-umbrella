import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('api-settings/rate-limit-fields', 'Integration | Component | api settings/rate limit fields', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{api-settings/rate-limit-fields}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#api-settings/rate-limit-fields}}
      template block text
    {{/api-settings/rate-limit-fields}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
