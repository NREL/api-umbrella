import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('help-tooltip', 'Integration | Component | help tooltip', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{help-tooltip}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#help-tooltip}}
      template block text
    {{/help-tooltip}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
