import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('config/publish-form', 'Integration | Component | config/publish form', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{config/publish-form}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#config/publish-form}}
      template block text
    {{/config/publish-form}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
