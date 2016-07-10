import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('apis/sub-settings-table', 'Integration | Component | apis/sub settings table', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{apis/sub-settings-table}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#apis/sub-settings-table}}
      template block text
    {{/apis/sub-settings-table}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
