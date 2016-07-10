import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('api-users/index-table', 'Integration | Component | api users/index table', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{api-users/index-table}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#api-users/index-table}}
      template block text
    {{/api-users/index-table}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
