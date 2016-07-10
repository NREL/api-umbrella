import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('form-fields/ace-field', 'Integration | Component | form fields/ace field', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{form-fields/ace-field}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#form-fields/ace-field}}
      template block text
    {{/form-fields/ace-field}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
