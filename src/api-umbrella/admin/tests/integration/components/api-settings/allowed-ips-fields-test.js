import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('api-settings/allowed-ips-fields', 'Integration | Component | api settings/allowed ips fields', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{api-settings/allowed-ips-fields}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#api-settings/allowed-ips-fields}}
      template block text
    {{/api-settings/allowed-ips-fields}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
