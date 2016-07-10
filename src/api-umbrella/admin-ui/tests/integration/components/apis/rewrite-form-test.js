import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('apis/rewrite-form', 'Integration | Component | apis/rewrite form', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{apis/rewrite-form}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#apis/rewrite-form}}
      template block text
    {{/apis/rewrite-form}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
