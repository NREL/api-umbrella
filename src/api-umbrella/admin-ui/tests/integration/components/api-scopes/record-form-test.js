import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('api-scopes/record-form', 'Integration | Component | api scopes/record form', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{api-scopes/record-form}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#api-scopes/record-form}}
      template block text
    {{/api-scopes/record-form}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
