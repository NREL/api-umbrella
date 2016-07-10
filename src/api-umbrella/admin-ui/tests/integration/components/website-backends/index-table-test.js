import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('website-backends/index-table', 'Integration | Component | website backends/index table', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{website-backends/index-table}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#website-backends/index-table}}
      template block text
    {{/website-backends/index-table}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
