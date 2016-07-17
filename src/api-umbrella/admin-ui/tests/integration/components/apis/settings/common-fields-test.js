import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('apis/settings/common-fields', 'Integration | Component | apis/settings/common fields', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{apis/settings/common-fields}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#apis/settings/common-fields}}
      template block text
    {{/apis/settings/common-fields}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
