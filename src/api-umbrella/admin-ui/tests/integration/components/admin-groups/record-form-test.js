import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('admin-groups/record-form', 'Integration | Component | admin groups/record form', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{admin-groups/record-form}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#admin-groups/record-form}}
      template block text
    {{/admin-groups/record-form}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
