import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('form-fields/field-wrapper', 'Integration | Component | form fields/field wrapper', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{form-fields/field-wrapper}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#form-fields/field-wrapper}}
      template block text
    {{/form-fields/field-wrapper}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
