import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('apis/settings/allowed-ips-fields', 'Integration | Component | apis/settings/allowed ips fields', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{apis/settings/allowed-ips-fields}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#apis/settings/allowed-ips-fields}}
      template block text
    {{/apis/settings/allowed-ips-fields}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
