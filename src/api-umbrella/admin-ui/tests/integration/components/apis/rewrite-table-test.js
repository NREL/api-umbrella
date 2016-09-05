import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('apis/rewrite-table', 'Integration | Component | apis/rewrite table', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{apis/rewrite-table}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#apis/rewrite-table}}
      template block text
    {{/apis/rewrite-table}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
