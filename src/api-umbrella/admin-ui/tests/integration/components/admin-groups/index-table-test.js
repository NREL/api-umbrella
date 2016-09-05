import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('admin-groups/index-table', 'Integration | Component | admin groups/index table', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{admin-groups/index-table}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#admin-groups/index-table}}
      template block text
    {{/admin-groups/index-table}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
